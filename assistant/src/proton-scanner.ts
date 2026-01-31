/**
 * Proton Mail Scanner / Orchestrator
 *
 * Fetches emails from Proton Bridge, classifies them using
 * MarketingDetector and NotificationDetector, and performs actions
 * (unsubscribe, move to folders, trash).
 */

import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import { ProtonClient } from './proton-client.js';
import { MarketingDetector, AnalysisResult } from './marketing-detector.js';
import { NotificationDetector, NotificationResult } from './notification-detector.js';
import { Unsubscriber, UnsubscribeResult } from './unsubscriber.js';
import { Email } from './email-types.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

export type Classification = 'marketing' | 'notification' | 'keep';

export interface ScanResult {
  email: Email;
  classification: Classification;
  marketingAnalysis: AnalysisResult;
  notificationAnalysis: NotificationResult;
  action?: string;
  unsubscribeResult?: UnsubscribeResult;
}

export interface ScanSummary {
  total: number;
  marketing: number;
  notification: number;
  kept: number;
  unsubscribed: number;
  moved: number;
  archived: number;
  results: ScanResult[];
}

/**
 * Sender preferences loaded from MEMORY.md.
 * These override the hardcoded detectors.
 */
interface MemoryOverrides {
  marketing: Set<string>;      // Always Unsubscribe senders (lowercase email/domain)
  neverUnsubscribe: Set<string>; // Never Unsubscribe / important senders
  notification: Set<string>;   // Always Move to Notifications senders
}

const NOTIFICATIONS_FOLDER = 'Folders/Notifications';

export class ProtonScanner {
  private client: ProtonClient;
  private marketingDetector: MarketingDetector;
  private notificationDetector: NotificationDetector;
  private unsubscriber: Unsubscriber;
  private memoryOverrides: MemoryOverrides;

  constructor(client: ProtonClient) {
    this.client = client;
    this.marketingDetector = new MarketingDetector();
    this.notificationDetector = new NotificationDetector();
    this.unsubscriber = new Unsubscriber();
    this.memoryOverrides = this.loadMemory();
  }

  /**
   * Reload MEMORY.md from disk. Called on SIGHUP or manually.
   */
  reloadMemory(): void {
    this.memoryOverrides = this.loadMemory();
  }

  /**
   * Parse MEMORY.md and extract sender email addresses/domains
   * into categorized sets for classification override.
   */
  private loadMemory(): MemoryOverrides {
    const marketing = new Set<string>();
    const neverUnsubscribe = new Set<string>();
    const notification = new Set<string>();

    // Try multiple possible locations for MEMORY.md
    const memoryPaths = [
      resolve(__dirname, '../../.claude/skills/proton-organizer/MEMORY.md'),
      resolve(__dirname, '../../../.claude/skills/proton-organizer/MEMORY.md'),
    ];

    let content = '';
    for (const p of memoryPaths) {
      try {
        content = readFileSync(p, 'utf-8');
        break;
      } catch {
        // try next path
      }
    }

    if (!content) {
      console.log('[ProtonScanner] MEMORY.md not found, using hardcoded classifiers only');
      return { marketing, neverUnsubscribe, notification };
    }

    // Extract email addresses from table rows in each section
    let currentSection = '';
    for (const line of content.split('\n')) {
      const trimmed = line.trim();

      // Detect section headers
      if (trimmed.startsWith('### Always Unsubscribe')) {
        currentSection = 'marketing';
      } else if (trimmed.startsWith('### Never Unsubscribe')) {
        currentSection = 'neverUnsubscribe';
      } else if (trimmed.startsWith('### Always Move to Notifications')) {
        currentSection = 'notification';
      } else if (trimmed.startsWith('### ')) {
        currentSection = ''; // other section, stop collecting
      }

      if (!currentSection) continue;

      // Extract email addresses from table rows (format: | ... | domain | ...)
      // Look for email-like patterns in the line
      const emailMatches = trimmed.match(/[\w.+-]+@[\w.-]+\.\w+/g);
      if (emailMatches) {
        const targetSet = currentSection === 'marketing' ? marketing
          : currentSection === 'neverUnsubscribe' ? neverUnsubscribe
          : notification;
        for (const email of emailMatches) {
          targetSet.add(email.toLowerCase());
        }
      }
    }

    console.log(`[ProtonScanner] Loaded MEMORY.md: ${marketing.size} marketing, ${neverUnsubscribe.size} never-unsub, ${notification.size} notification senders`);
    return { marketing, neverUnsubscribe, notification };
  }

  /**
   * Check if a sender email matches any address in a set.
   * Matches both exact email and domain-level.
   */
  private senderMatchesSet(fromField: string, senderSet: Set<string>): boolean {
    const emailMatch = fromField.match(/[\w.+-]+@[\w.-]+\.\w+/);
    if (!emailMatch) return false;
    const email = emailMatch[0].toLowerCase();
    // Check exact email match
    if (senderSet.has(email)) return true;
    // Check domain match (e.g., if set has "info@g2a.com", match "info@g2a.com")
    // Also check if the domain portion matches any entry's domain
    const domain = email.split('@')[1];
    for (const entry of senderSet) {
      if (entry.split('@')[1] === domain && entry.split('@')[0] === email.split('@')[0]) {
        return true;
      }
    }
    return false;
  }

  /**
   * Scan unread emails: fetch, classify, and return results.
   * Does NOT take any action -- use act() for that.
   */
  async scan(limit: number = 50): Promise<ScanSummary> {
    const emails = await this.client.fetchUnread('INBOX', limit);
    const results: ScanResult[] = [];

    for (const email of emails) {
      // MEMORY.md overrides take priority over hardcoded detectors
      const memoryClassification = this.classifyByMemory(email);
      if (memoryClassification) {
        const dummyMarketing: AnalysisResult = { isMarketing: memoryClassification === 'marketing', confidence: 1, reasons: ['MEMORY.md override'] };
        const dummyNotification: NotificationResult = { isNotification: memoryClassification === 'notification', confidence: 1, category: 'service', reasons: ['MEMORY.md override'] };
        results.push({ email, classification: memoryClassification, marketingAnalysis: dummyMarketing, notificationAnalysis: dummyNotification });
        continue;
      }

      const marketingAnalysis = this.marketingDetector.analyze(email);
      const notificationAnalysis = this.notificationDetector.analyze(email);

      let classification: Classification;
      // When both detectors fire, prefer notification -- known notification
      // domains (GitHub, Firebase, Slack, etc.) should never be trashed.
      if (marketingAnalysis.isMarketing && notificationAnalysis.isNotification) {
        classification = 'notification';
      } else if (marketingAnalysis.isMarketing) {
        classification = 'marketing';
      } else if (notificationAnalysis.isNotification) {
        classification = 'notification';
      } else {
        classification = 'keep';
      }

      results.push({ email, classification, marketingAnalysis, notificationAnalysis });
    }

    return {
      total: results.length,
      marketing: results.filter(r => r.classification === 'marketing').length,
      notification: results.filter(r => r.classification === 'notification').length,
      kept: results.filter(r => r.classification === 'keep').length,
      unsubscribed: 0,
      moved: 0,
      archived: 0,
      results,
    };
  }

  /**
   * Classify an email using MEMORY.md overrides.
   * Returns null if no override applies (fall through to detectors).
   */
  private classifyByMemory(email: Email): Classification | null {
    // Never-unsubscribe takes highest priority (protect important senders)
    if (this.senderMatchesSet(email.from, this.memoryOverrides.neverUnsubscribe)) {
      return 'keep';
    }
    // Marketing override
    if (this.senderMatchesSet(email.from, this.memoryOverrides.marketing)) {
      return 'marketing';
    }
    // Notification override
    if (this.senderMatchesSet(email.from, this.memoryOverrides.notification)) {
      return 'notification';
    }
    return null;
  }

  /**
   * Act on scan results:
   * - marketing: attempt unsubscribe, then trash
   * - notification: move to Notifications folder
   * - keep: do nothing
   */
  async act(
    summary: ScanSummary,
    options: {
      unsubscribe?: boolean;
      moveNotifications?: boolean;
      trashMarketing?: boolean;
      archiveKept?: boolean;
      maxUnsubscribes?: number;
    } = {},
  ): Promise<ScanSummary> {
    const {
      unsubscribe = true,
      moveNotifications = true,
      trashMarketing = true,
      archiveKept = false,
      maxUnsubscribes = 10,
    } = options;

    if (moveNotifications) {
      await this.client.ensureFolder(NOTIFICATIONS_FOLDER);
    }

    let unsubscribeCount = 0;

    for (const result of summary.results) {
      const uid = parseInt(result.email.id, 10);

      if (result.classification === 'marketing') {
        // Attempt unsubscribe
        if (unsubscribe && unsubscribeCount < maxUnsubscribes && result.email.listUnsubscribe) {
          try {
            result.unsubscribeResult = await this.unsubscriber.unsubscribe(
              result.email,
              this.client,
            );
            if (result.unsubscribeResult.success) {
              unsubscribeCount++;
              summary.unsubscribed++;
            }
          } catch (err) {
            result.unsubscribeResult = {
              success: false,
              error: String(err),
            };
          }
        }

        // Mark read + trash
        if (trashMarketing) {
          try {
            await this.client.markAsRead(uid);
            await this.client.trash(uid);
            result.action = 'trashed';
          } catch (err) {
            result.action = `trash-failed: ${err}`;
          }
        }
      } else if (result.classification === 'notification') {
        if (moveNotifications) {
          try {
            await this.client.markAsRead(uid);
            await this.client.moveToFolder(uid, 'INBOX', NOTIFICATIONS_FOLDER);
            result.action = `moved to ${NOTIFICATIONS_FOLDER}`;
            summary.moved++;
          } catch (err) {
            result.action = `move-failed: ${err}`;
          }
        }
      } else if (archiveKept) {
        // Archive non-important emails out of the inbox
        try {
          await this.client.markAsRead(uid);
          await this.client.moveToFolder(uid, 'INBOX', 'Archive');
          result.action = 'archived';
          summary.archived++;
        } catch (err) {
          result.action = `archive-failed: ${err}`;
        }
      } else {
        result.action = 'kept';
      }
    }

    return summary;
  }

  /**
   * Convenience: scan + act in one call (for daemon use).
   */
  async scanAndAct(
    limit: number = 50,
    options?: Parameters<ProtonScanner['act']>[1],
  ): Promise<ScanSummary> {
    const summary = await this.scan(limit);
    return this.act(summary, options);
  }
}
