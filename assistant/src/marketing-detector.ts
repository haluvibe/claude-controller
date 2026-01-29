/**
 * Marketing Email Detector
 *
 * Analyzes emails to determine if they're marketing/promotional
 */

import { Email } from './email-types.js';

export interface AnalysisResult {
  isMarketing: boolean;
  confidence: number;
  reasons: string[];
}

export class MarketingDetector {
  // Strong marketing sender patterns (+4) -- self-declaring as marketing/newsletter
  private strongMarketingSenderPatterns = [
    /newsletter@/i,
    /marketing@/i,
    /promotions@/i,
    /offers@/i,
    /deals@/i,
  ];

  // Weak marketing sender patterns (+2) -- suggestive but not conclusive alone
  // HIGH FIX 1: Removed overly aggressive patterns (info@, hello@, team@)
  // These caused false positives for legitimate business emails
  private weakMarketingSenderPatterns = [
    /no-?reply@/i,
    /noreply@/i,
    /news@/i,
    /updates@/i,
    /memberships?@/i,
    /travel-?insider@/i,
    /hello@/i,
    /support@.*\.(store|shop|sale)/i,
    // EDM (email direct marketing) in domain
    /@[a-z0-9]*edm[a-z0-9]*\./i,
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

  // Sender domain patterns -- always important regardless of content
  private importantSenderPatterns = [
    /@(github|gitlab|bitbucket|jira|confluence)\./i,
    // Handle subdomains and country TLDs (e.g., @mail.google.com, @amazon.co.uk)
    // Use \b instead of $ to handle "Display Name" <user@domain> format
    /@([a-z0-9-]+\.)*(google|apple|microsoft|amazon)\.[a-z.]+\b/i,
  ];

  // Subject patterns -- transactional keywords checked against subject only
  // (not from address, to avoid false positives like "transactional" in domains
  // or "delivery" in marketing subjects)
  private importantSubjectPatterns = [
    /\b(receipt|invoice)\b/i,
    /\border\s*(confirm|confirmed|confirmation|shipped|processed|number|details)\b/i,
    /\b(password\s*(reset|changed|updated|generated|expired)|reset\s*your\s*password)\b/i,
    /\b(security\s*(alert|notice|update|code)|verification\s*(code|link|email))\b/i,
    /\b(two.?factor|2fa|authenticate)\b/i,
    /\b(appointment|reservation)\b/i,
    /\bbooking\s*(confirm|detail|reference)\b/i,
    /\bpayment\s*(received|confirmed|processed|failed|receipt)\b/i,
    /\bwelcome\s*to\b/i,
    /\baccount\s*(created|activated|verified)\b/i,
    /\b(support\s*ticket|case\s*#)\b/i,
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

    // Check strong sender patterns (self-declaring as marketing/newsletter)
    let senderMatched = false;
    for (const pattern of this.strongMarketingSenderPatterns) {
      if (pattern.test(email.from)) {
        score += 4;
        reasons.push(`Sender is explicitly marketing/newsletter: ${pattern.source}`);
        senderMatched = true;
        break;
      }
    }

    // Check weak sender patterns (suggestive but not conclusive)
    if (!senderMatched) {
      for (const pattern of this.weakMarketingSenderPatterns) {
        if (pattern.test(email.from)) {
          score += 2;
          reasons.push(`Sender matches marketing pattern: ${pattern.source}`);
          break;
        }
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
        score += 2;
        reasons.push('Body contains unsubscribe language');
      }
    }

    // Calculate confidence (max score ~15)
    const confidence = Math.min(score / 10, 1);
    const isMarketing = score >= 4;

    return { isMarketing, confidence, reasons };
  }

  private isImportant(email: Email): boolean {
    // Check sender domain patterns (e.g., @github.com, @apple.com)
    for (const pattern of this.importantSenderPatterns) {
      if (pattern.test(email.from)) {
        return true;
      }
    }

    // Check subject-only patterns for transactional keywords
    for (const pattern of this.importantSubjectPatterns) {
      if (pattern.test(email.subject)) {
        return true;
      }
    }

    // Check for personal correspondence (reply thread)
    const inReplyTo = email.headers.get('in-reply-to');
    if (inReplyTo) {
      return true; // Direct reply to another message
    }

    // Check References header, but ignore Proton Bridge internal IDs
    // Bridge injects References: <...@protonmail.internalid> on all messages
    const references = email.headers.get('references');
    if (references && !references.includes('@protonmail.internalid')) {
      return true; // Part of a conversation thread
    }

    return false;
  }
}
