#!/usr/bin/env node
/**
 * Proton Mail Daemon
 *
 * Background process that uses IMAP IDLE to monitor the inbox
 * and automatically sort incoming emails:
 *   - Marketing -> attempt unsubscribe, then trash
 *   - Notifications -> move to "Notifications" folder
 *   - Everything else -> leave in inbox
 *
 * Usage:
 *   node dist/proton-daemon.js
 *   node dist/proton-daemon.js --dry-run    (classify only, no actions)
 */

import { config as dotenvConfig } from 'dotenv';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { ProtonClient, loadProtonConfig } from './proton-client.js';
import { ProtonScanner } from './proton-scanner.js';

const __dirname = dirname(fileURLToPath(import.meta.url));
dotenvConfig({ path: resolve(__dirname, '../config/.env.proton') });

const DRY_RUN = process.argv.includes('--dry-run');
const SCAN_LIMIT = 20; // Per-batch limit during idle wakeups

function timestamp(): string {
  return new Date().toISOString();
}

function log(msg: string): void {
  console.log(`[${timestamp()}] ${msg}`);
}

async function main(): Promise<void> {
  log('Proton Mail Daemon starting...');
  if (DRY_RUN) log('DRY RUN mode: will classify but not act');

  let config;
  try {
    config = loadProtonConfig();
  } catch (err) {
    console.error(String(err));
    process.exit(1);
  }

  const client = new ProtonClient(config);
  const scanner = new ProtonScanner(client);

  await client.connect();
  log('Connected to Proton Bridge');

  // Initial scan on startup
  await processBatch(scanner);

  // Enter IDLE loop
  log('Entering IDLE loop -- waiting for new mail...');
  const stopIdle = await client.startIdle('INBOX', async () => {
    log('New mail detected');
    await processBatch(scanner);
  });

  // SIGHUP: reload MEMORY.md without restarting
  process.on('SIGHUP', () => {
    log('Received SIGHUP, reloading MEMORY.md...');
    scanner.reloadMemory();
    log('MEMORY.md reloaded');
  });

  // Graceful shutdown
  const shutdown = async (signal: string) => {
    log(`Received ${signal}, shutting down...`);
    stopIdle();
    await client.disconnect();
    log('Disconnected. Goodbye.');
    process.exit(0);
  };

  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

async function processBatch(scanner: ProtonScanner): Promise<void> {
  try {
    if (DRY_RUN) {
      const summary = await scanner.scan(SCAN_LIMIT);
      log(`Scan: ${summary.total} emails (${summary.marketing} marketing, ${summary.notification} notification, ${summary.kept} keep)`);
      for (const r of summary.results) {
        log(`  [${r.classification}] ${r.email.from} - ${r.email.subject}`);
      }
    } else {
      const summary = await scanner.scanAndAct(SCAN_LIMIT, { archiveKept: true });
      log(`Processed: ${summary.total} emails`);
      log(`  Unsubscribed: ${summary.unsubscribed}, Moved: ${summary.moved}, Trashed: ${summary.marketing}`);
      for (const r of summary.results) {
        if (r.action && r.action !== 'kept') {
          log(`  [${r.classification}] ${r.email.from} -> ${r.action}`);
        }
      }
    }
  } catch (err) {
    log(`Error during batch processing: ${err}`);
  }
}

main().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
