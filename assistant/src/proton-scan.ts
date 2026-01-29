#!/usr/bin/env node
/**
 * Proton Mail Scanner CLI
 *
 * Usage:
 *   node dist/proton-scan.js test-connection
 *   node dist/proton-scan.js folders
 *   node dist/proton-scan.js scan [--limit N] [--json]
 *   node dist/proton-scan.js act [--limit N] [--no-unsubscribe] [--no-move] [--no-trash] [--json]
 */

import { config as dotenvConfig } from 'dotenv';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { ProtonClient, loadProtonConfig } from './proton-client.js';
import { ProtonScanner, ScanResult, ScanSummary } from './proton-scanner.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Load .env.proton from config directory
dotenvConfig({ path: resolve(__dirname, '../config/.env.proton') });

function parseArgs(argv: string[]): { command: string; flags: Record<string, string | boolean> } {
  const args = argv.slice(2);
  const command = args[0] || 'help';
  const flags: Record<string, string | boolean> = {};

  for (let i = 1; i < args.length; i++) {
    const arg = args[i];
    if (arg.startsWith('--no-')) {
      flags[arg.slice(5)] = false;
    } else if (arg.startsWith('--')) {
      const key = arg.slice(2);
      const next = args[i + 1];
      if (next && !next.startsWith('--')) {
        flags[key] = next;
        i++;
      } else {
        flags[key] = true;
      }
    }
  }

  return { command, flags };
}

function formatTable(summary: ScanSummary): string {
  const lines: string[] = [];
  const divider = '|---|------|------|---------|----------------|------------|--------|';

  lines.push('| # | Date | From | Subject | Classification | Confidence | Action |');
  lines.push(divider);

  for (let i = 0; i < summary.results.length; i++) {
    const r = summary.results[i];
    const date = r.email.date.toISOString().slice(0, 10);
    const from = r.email.from.slice(0, 30);
    const subject = r.email.subject.slice(0, 40);
    const conf = r.classification === 'marketing'
      ? (r.marketingAnalysis.confidence * 100).toFixed(0) + '%'
      : r.classification === 'notification'
        ? (r.notificationAnalysis.confidence * 100).toFixed(0) + '%'
        : '-';
    const action = r.action || '-';

    lines.push(`| ${i + 1} | ${date} | ${from} | ${subject} | ${r.classification} | ${conf} | ${action} |`);
  }

  return lines.join('\n');
}

function printSummary(summary: ScanSummary): void {
  console.log(`\nScan complete: ${summary.total} emails`);
  console.log(`  Marketing:     ${summary.marketing}`);
  console.log(`  Notification:  ${summary.notification}`);
  console.log(`  Kept:          ${summary.kept}`);
  if (summary.unsubscribed > 0) console.log(`  Unsubscribed:  ${summary.unsubscribed}`);
  if (summary.moved > 0) console.log(`  Moved:         ${summary.moved}`);
  if (summary.archived > 0) console.log(`  Archived:      ${summary.archived}`);
}

async function main(): Promise<void> {
  const { command, flags } = parseArgs(process.argv);
  const jsonOutput = flags.json === true;

  if (command === 'help' || command === '--help' || command === '-h') {
    console.log(`Proton Mail Scanner

Commands:
  test-connection   Test IMAP/SMTP connection to Proton Bridge
  folders           List all IMAP folders
  scan              Fetch and classify unread emails (read-only)
  act               Scan + take action (unsubscribe, move, trash)

Options:
  --limit N         Max emails to fetch (default: 50)
  --json            Output as JSON
  --no-unsubscribe  Skip unsubscribe attempts
  --no-move         Don't move notifications
  --no-trash        Don't trash marketing emails
  --archive         Archive non-important 'keep' emails out of inbox`);
    return;
  }

  let config;
  try {
    config = loadProtonConfig();
  } catch (err) {
    console.error(String(err));
    process.exit(1);
  }

  const client = new ProtonClient(config);

  try {
    switch (command) {
      case 'test-connection': {
        const result = await client.testConnection();
        if (jsonOutput) {
          console.log(JSON.stringify(result, null, 2));
        } else {
          console.log(`IMAP: ${result.imap ? 'OK' : 'FAILED'}`);
          console.log(`SMTP: ${result.smtp ? 'OK' : 'FAILED'}`);
          console.log(`Folders: ${result.folders.join(', ')}`);
        }
        break;
      }

      case 'folders': {
        await client.connect();
        const folders = await client.listFolders();
        if (jsonOutput) {
          console.log(JSON.stringify(folders, null, 2));
        } else {
          console.log('IMAP folders:');
          for (const f of folders) {
            console.log(`  ${f}`);
          }
        }
        await client.disconnect();
        break;
      }

      case 'scan': {
        await client.connect();
        const scanner = new ProtonScanner(client);
        const limit = typeof flags.limit === 'string' ? parseInt(flags.limit, 10) : 50;
        const summary = await scanner.scan(limit);

        if (jsonOutput) {
          console.log(JSON.stringify(summary, null, 2));
        } else {
          console.log(formatTable(summary));
          printSummary(summary);
        }
        await client.disconnect();
        break;
      }

      case 'act': {
        await client.connect();
        const scanner = new ProtonScanner(client);
        const limit = typeof flags.limit === 'string' ? parseInt(flags.limit, 10) : 50;

        const summary = await scanner.scanAndAct(limit, {
          unsubscribe: flags.unsubscribe !== false,
          moveNotifications: flags.move !== false,
          trashMarketing: flags.trash !== false,
          archiveKept: flags.archive === true,
        });

        if (jsonOutput) {
          console.log(JSON.stringify(summary, null, 2));
        } else {
          console.log(formatTable(summary));
          printSummary(summary);
        }
        await client.disconnect();
        break;
      }

      default:
        console.error(`Unknown command: ${command}. Run with --help for usage.`);
        process.exit(1);
    }
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
}

main();
