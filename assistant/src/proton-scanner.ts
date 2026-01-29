/**
 * Proton Mail Scanner / Orchestrator
 *
 * Fetches emails from Proton Bridge, classifies them using
 * MarketingDetector and NotificationDetector, and performs actions
 * (unsubscribe, move to folders, trash).
 */

import { ProtonClient } from './proton-client.js';
import { MarketingDetector, AnalysisResult } from './marketing-detector.js';
import { NotificationDetector, NotificationResult } from './notification-detector.js';
import { Unsubscriber, UnsubscribeResult } from './unsubscriber.js';
import { Email } from './email-types.js';

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

const NOTIFICATIONS_FOLDER = 'Folders/Notifications';

export class ProtonScanner {
  private client: ProtonClient;
  private marketingDetector: MarketingDetector;
  private notificationDetector: NotificationDetector;
  private unsubscriber: Unsubscriber;

  constructor(client: ProtonClient) {
    this.client = client;
    this.marketingDetector = new MarketingDetector();
    this.notificationDetector = new NotificationDetector();
    this.unsubscriber = new Unsubscriber();
  }

  /**
   * Scan unread emails: fetch, classify, and return results.
   * Does NOT take any action -- use act() for that.
   */
  async scan(limit: number = 50): Promise<ScanSummary> {
    const emails = await this.client.fetchUnread('INBOX', limit);
    const results: ScanResult[] = [];

    for (const email of emails) {
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
