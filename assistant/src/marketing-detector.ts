/**
 * Marketing Email Detector
 *
 * Analyzes emails to determine if they're marketing/promotional
 */

import { Email } from './gmail-client.js';

export interface AnalysisResult {
  isMarketing: boolean;
  confidence: number;
  reasons: string[];
}

export class MarketingDetector {
  // Patterns that indicate marketing emails
  // HIGH FIX 1: Removed overly aggressive patterns (info@, hello@, team@)
  // These caused false positives for legitimate business emails
  private marketingSenderPatterns = [
    /no-?reply@/i,
    /noreply@/i,
    /newsletter@/i,
    /marketing@/i,
    /promotions@/i,
    /offers@/i,
    /deals@/i,
    /news@/i,
    /updates@/i,
    /support@.*\.(store|shop|sale)/i
  ];

  private marketingSubjectPatterns = [
    /\b(sale|discount|off|deal|save|free|limited|exclusive|offer)\b/i,
    /\b(\d+%\s*off)\b/i,
    /\b(last chance|don't miss|ending soon|hurry|act now)\b/i,
    /\b(unsubscribe|update preferences)\b/i,
    /\b(weekly|monthly|daily)\s*(digest|update|newsletter)\b/i,
    /\b(new arrivals?|just dropped|now available)\b/i,
    /\b(flash sale|clearance|black friday|cyber monday)\b/i
  ];

  // MEDIUM FIX 2: Added missing marketing platforms
  private marketingDomains = new Set([
    'mailchimp.com',
    'sendgrid.net',
    'amazonses.com',
    'mailgun.org',
    'constantcontact.com',
    'hubspot.com',
    'klaviyo.com',
    'brevo.com',
    'sendinblue.com',
    'campaign-archive.com',
    'postmarkapp.com',
    'mandrill.com',
    'intercom-mail.com',
    'customer.io',
    'drip.com',
    'convertkit.com',
    'getresponse.com',
    'mailjet.com'
  ]);

  // Patterns for emails we should NOT unsubscribe from
  private importantPatterns = [
    /receipt|invoice|order\s*confirm|shipping|delivery/i,
    /password|security|verification|authenticate/i,
    /appointment|reservation|booking|confirm/i,
    /payment|transaction|statement/i,
    /welcome\s*to|account\s*created/i,
    /@(github|gitlab|bitbucket|jira|confluence)\./i,
    // MEDIUM FIX 3: Handle subdomains and country TLDs (e.g., @mail.google.com, @amazon.co.uk)
    /@([a-z0-9-]+\.)*(google|apple|microsoft|amazon)\.[a-z.]+$/i,
    /support\s*ticket|case\s*#/i
  ];

  analyze(email: Email): AnalysisResult {
    const reasons: string[] = [];
    let score = 0;

    // Check if it's an important/transactional email first
    if (this.isImportant(email)) {
      return { isMarketing: false, confidence: 0.95, reasons: ['Important/transactional email'] };
    }

    // Check for List-Unsubscribe header (strong indicator)
    if (email.listUnsubscribe) {
      score += 3;
      reasons.push('Has List-Unsubscribe header');
    }

    // Check Gmail's Promotions category
    if (email.labels.includes('CATEGORY_PROMOTIONS')) {
      score += 4;
      reasons.push('In Promotions category');
    }

    // Check sender patterns
    for (const pattern of this.marketingSenderPatterns) {
      if (pattern.test(email.from)) {
        score += 2;
        reasons.push(`Sender matches marketing pattern: ${pattern.source}`);
        break;
      }
    }

    // Check if sent via marketing platform
    // LOW FIX 4: Check all Received headers (may be multiple in raw email)
    // The headers Map stores the last value, so we also check x-received and
    // look in both received headers for marketing domains
    const receivedHeader = email.headers.get('received') || '';
    const xReceivedHeader = email.headers.get('x-received') || '';
    const allReceivedHeaders = `${receivedHeader} ${xReceivedHeader}`;
    const xMailer = email.headers.get('x-mailer') || '';
    const xCampaign = email.headers.get('x-campaign') || email.headers.get('x-mc-user') || '';

    for (const domain of this.marketingDomains) {
      if (allReceivedHeaders.includes(domain) || xMailer.includes(domain)) {
        score += 3;
        reasons.push(`Sent via marketing platform: ${domain}`);
        break;
      }
    }

    if (xCampaign) {
      score += 2;
      reasons.push('Has campaign tracking headers');
    }

    // Check subject patterns
    for (const pattern of this.marketingSubjectPatterns) {
      if (pattern.test(email.subject)) {
        score += 2;
        reasons.push(`Subject matches marketing pattern`);
        break;
      }
    }

    // Check for bulk mail headers
    const precedence = email.headers.get('precedence');
    if (precedence === 'bulk' || precedence === 'list') {
      score += 2;
      reasons.push('Precedence: bulk/list');
    }

    // Check body for unsubscribe links
    if (email.body) {
      const unsubscribeLinkPattern = /unsubscribe|opt-?out|manage\s*preferences|email\s*preferences/i;
      if (unsubscribeLinkPattern.test(email.body)) {
        score += 1;
        reasons.push('Body contains unsubscribe links');
      }
    }

    // Calculate confidence (max score ~15)
    const confidence = Math.min(score / 10, 1);
    const isMarketing = score >= 4;

    return { isMarketing, confidence, reasons };
  }

  private isImportant(email: Email): boolean {
    const combined = `${email.from} ${email.subject}`;

    for (const pattern of this.importantPatterns) {
      if (pattern.test(combined)) {
        return true;
      }
    }

    // Check for personal correspondence (single recipient, reply, etc.)
    const replyTo = email.headers.get('in-reply-to');
    const references = email.headers.get('references');
    if (replyTo || references) {
      return true; // Part of a conversation thread
    }

    return false;
  }
}
