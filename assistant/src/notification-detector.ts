/**
 * Notification Email Detector
 *
 * Classifies emails as automated notifications (GitHub, CI/CD, Slack, etc.)
 * and assigns a category for folder routing.
 */

import { Email } from './email-types.js';

export type NotificationCategory =
  | 'github'
  | 'gitlab'
  | 'slack'
  | 'firebase'
  | 'banking'
  | 'service'
  | 'social'
  | 'ci-cd'
  | 'monitoring'
  | 'security'
  | 'none';

export interface NotificationResult {
  isNotification: boolean;
  confidence: number;
  category: NotificationCategory;
  reasons: string[];
}

export class NotificationDetector {
  // Sender domains that are almost always automated notifications (+3)
  private notificationDomains = new Map<string, NotificationCategory>([
    ['github.com', 'github'],
    ['gitlab.com', 'gitlab'],
    ['bitbucket.org', 'github'],
    ['noreply.github.com', 'github'],

    ['slack.com', 'slack'],
    ['slack-msgs.com', 'slack'],

    ['firebase.google.com', 'firebase'],
    ['firebaseappcheck-noreply.google.com', 'firebase'],
    ['firebaseapptesters.com', 'firebase'],

    ['youtube.com', 'social'],

    ['sentry.io', 'monitoring'],
    ['pagerduty.com', 'monitoring'],
    ['opsgenie.com', 'monitoring'],
    ['datadoghq.com', 'monitoring'],
    ['newrelic.com', 'monitoring'],
    ['statuspage.io', 'monitoring'],

    ['circleci.com', 'ci-cd'],
    ['travis-ci.com', 'ci-cd'],
    ['travis-ci.org', 'ci-cd'],
    ['vercel.com', 'ci-cd'],
    ['netlify.com', 'ci-cd'],
    ['heroku.com', 'ci-cd'],
    ['render.com', 'ci-cd'],
    ['railway.app', 'ci-cd'],
    ['fly.io', 'ci-cd'],
    ['cloudflare.com', 'ci-cd'],

    ['linear.app', 'service'],
    ['notion.so', 'service'],
    ['atlassian.com', 'service'],
    ['trello.com', 'service'],
    ['asana.com', 'service'],
    ['monday.com', 'service'],
    ['figma.com', 'service'],

    ['twitter.com', 'social'],
    ['x.com', 'social'],
    ['facebookmail.com', 'social'],
    ['linkedin.com', 'social'],
    ['reddit.com', 'social'],
    ['discord.com', 'social'],
    ['medium.com', 'social'],
  ]);

  // Sender prefixes that strongly suggest automated notification (+3 when combined with auto headers)
  private notificationPrefixes = [
    'notify@',
    'alert@',
    'alerts@',
    'notification@',
    'notifications@',
    'noreply@',
    'no-reply@',
    'no_reply@',
    'donotreply@',
    'do-not-reply@',
    'system@',
    'bot@',
    'builds@',
    'ci@',
    'deploy@',
    'monitor@',
  ];

  // Headers that indicate automated/notification emails (+2)
  private automatedHeaders = [
    'auto-submitted',        // RFC 3834
    'x-auto-response-suppress',
    'x-github-reason',
    'x-github-sender',
    'x-notifications',
    'x-gitlab-pipeline-id',
    'x-bitbucket-event',
    'x-mailer',
    'x-slack-req-id',
    'x-sentry-event-id',
    'x-linear-event',
  ];

  // Subject patterns suggesting notifications (+1)
  private notificationSubjectPatterns: [RegExp, NotificationCategory][] = [
    [/\[[\w-]+\/[\w-]+\]/i, 'github'],                          // [org/repo]
    [/\[[\w-]+\]/i, 'service'],                                  // [ProjectName]
    [/\bpull request\b/i, 'github'],
    [/\bmerge request\b/i, 'gitlab'],
    [/\bmerged\b.*\b#\d+/i, 'github'],
    [/\bclosed\b.*\b#\d+/i, 'github'],
    [/\bpipeline\b.*\b(passed|failed|success|broken)\b/i, 'ci-cd'],
    [/\bbuild\b.*\b(passed|failed|success|broken)\b/i, 'ci-cd'],
    [/\bdeploy(ment)?\b.*\b(success|fail|complete|started)\b/i, 'ci-cd'],
    [/\balert\b/i, 'monitoring'],
    [/\bnotification\b/i, 'service'],
    [/\bincident\b/i, 'monitoring'],
    [/\b(crash|error|exception)\s+(report|detected|alert)\b/i, 'monitoring'],
    [/\bnew sign-?in\b/i, 'security'],
    [/\bsecurity alert\b/i, 'security'],
    [/\bunusual (activity|sign-?in)\b/i, 'security'],
    [/\bbilling\b.*\b(alert|threshold|limit)\b/i, 'firebase'],
  ];

  // Precedence header values that indicate bulk/automated mail
  private bulkPrecedence = new Set(['bulk', 'list', 'junk']);

  analyze(email: Email): NotificationResult {
    const reasons: string[] = [];
    let score = 0;
    let category: NotificationCategory = 'none';

    // 1. Check sender domain (+3)
    const senderDomain = this.extractDomain(email.from);
    for (const [domain, cat] of this.notificationDomains) {
      if (senderDomain === domain || senderDomain.endsWith('.' + domain)) {
        score += 3;
        category = cat;
        reasons.push(`Sender domain matches notification source: ${domain}`);
        break;
      }
    }

    // 2. Check sender prefix (+3 if also has automated headers, +1 alone)
    const fromLower = email.from.toLowerCase();
    const hasNotifyPrefix = this.notificationPrefixes.some(p => fromLower.includes(p));
    const hasAutomatedHeaders = this.checkAutomatedHeaders(email);

    if (hasNotifyPrefix && hasAutomatedHeaders) {
      score += 3;
      reasons.push('Notification sender prefix with automated headers');
    } else if (hasNotifyPrefix) {
      score += 1;
      reasons.push('Has notification sender prefix');
    }

    // 3. Check automated headers (+2)
    if (hasAutomatedHeaders) {
      score += 2;
      reasons.push('Has automated email headers');

      // Try to refine category from headers
      if (category === 'none') {
        if (email.headers.get('x-github-reason') || email.headers.get('x-github-sender')) {
          category = 'github';
        } else if (email.headers.get('x-gitlab-pipeline-id')) {
          category = 'gitlab';
        } else if (email.headers.get('x-slack-req-id')) {
          category = 'slack';
        } else if (email.headers.get('x-sentry-event-id')) {
          category = 'monitoring';
        }
      }
    }

    // 4. Check subject patterns (+1 each, max +2)
    let subjectScore = 0;
    for (const [pattern, cat] of this.notificationSubjectPatterns) {
      if (pattern.test(email.subject)) {
        subjectScore++;
        if (category === 'none') category = cat;
        reasons.push(`Subject matches notification pattern: ${pattern.source}`);
        if (subjectScore >= 2) break;
      }
    }
    score += Math.min(subjectScore, 2);

    // 5. Check precedence header (+1)
    const precedence = email.headers.get('precedence')?.toLowerCase();
    if (precedence && this.bulkPrecedence.has(precedence)) {
      score += 1;
      reasons.push(`Precedence: ${precedence}`);
    }

    // 6. Check Auto-Submitted header value (+1)
    const autoSubmitted = email.headers.get('auto-submitted')?.toLowerCase();
    if (autoSubmitted && autoSubmitted !== 'no') {
      score += 1;
      reasons.push(`Auto-Submitted: ${autoSubmitted}`);
    }

    const confidence = Math.min(score / 8, 1);
    const isNotification = score >= 3;

    return { isNotification, confidence, category, reasons };
  }

  private checkAutomatedHeaders(email: Email): boolean {
    for (const header of this.automatedHeaders) {
      const value = email.headers.get(header);
      if (value && value.toLowerCase() !== 'no') {
        return true;
      }
    }
    return false;
  }

  private extractDomain(from: string): string {
    // Handle "Name <email@domain.com>" or "email@domain.com"
    const match = from.match(/@([\w.-]+)/);
    return match ? match[1].toLowerCase() : '';
  }
}
