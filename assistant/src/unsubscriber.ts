/**
 * Email Unsubscriber
 *
 * Handles the unsubscribe process for marketing emails
 */

import { Email, GmailClient } from './gmail-client.js';
import { BrowserUnsubscriber } from './browser-unsubscriber.js';

export interface UnsubscribeResult {
  success: boolean;
  method?: 'mailto' | 'http' | 'one-click' | 'browser' | 'none';
  error?: string;
  screenshotPath?: string;
}

// Rate limiting for mailto unsubscribes
const mailtoRateLimit = {
  count: 0,
  windowStart: Date.now(),
  maxPerHour: 10
};

/**
 * SECURITY: Check if a URL is safe to fetch (SSRF prevention)
 * Blocks private IPs, localhost, cloud metadata, and link-local addresses
 */
function isUrlSafe(urlString: string): { safe: boolean; reason?: string } {
  try {
    const url = new URL(urlString);
    const hostname = url.hostname.toLowerCase();

    // Must be HTTPS for security
    if (url.protocol !== 'https:') {
      return { safe: false, reason: 'Only HTTPS URLs are allowed' };
    }

    // Block localhost variations
    if (hostname === 'localhost' ||
        hostname === '127.0.0.1' ||
        hostname === '::1' ||
        hostname === '[::1]' ||
        hostname === '0.0.0.0') {
      return { safe: false, reason: 'Localhost URLs are blocked' };
    }

    // Parse IP address if hostname is an IP
    const ipv4Match = hostname.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/);
    if (ipv4Match) {
      const [, a, b, c, d] = ipv4Match.map(Number);

      // Block private IP ranges (RFC 1918)
      // 10.0.0.0/8
      if (a === 10) {
        return { safe: false, reason: 'Private IP range 10.x.x.x is blocked' };
      }
      // 172.16.0.0/12 (172.16.0.0 - 172.31.255.255)
      if (a === 172 && b >= 16 && b <= 31) {
        return { safe: false, reason: 'Private IP range 172.16-31.x.x is blocked' };
      }
      // 192.168.0.0/16
      if (a === 192 && b === 168) {
        return { safe: false, reason: 'Private IP range 192.168.x.x is blocked' };
      }

      // Block loopback (127.0.0.0/8)
      if (a === 127) {
        return { safe: false, reason: 'Loopback addresses are blocked' };
      }

      // Block link-local (169.254.0.0/16) - includes cloud metadata
      if (a === 169 && b === 254) {
        return { safe: false, reason: 'Link-local/cloud metadata addresses are blocked' };
      }

      // Block multicast (224.0.0.0/4)
      if (a >= 224 && a <= 239) {
        return { safe: false, reason: 'Multicast addresses are blocked' };
      }

      // Block reserved (240.0.0.0/4)
      if (a >= 240) {
        return { safe: false, reason: 'Reserved addresses are blocked' };
      }

      // Block 0.0.0.0/8
      if (a === 0) {
        return { safe: false, reason: 'Zero-prefix addresses are blocked' };
      }
    }

    // Block cloud metadata hostnames
    const metadataHostnames = [
      'metadata.google.internal',
      'metadata.google',
      'instance-data',
      'metadata.local'
    ];
    if (metadataHostnames.some(h => hostname === h || hostname.endsWith('.' + h))) {
      return { safe: false, reason: 'Cloud metadata hostnames are blocked' };
    }

    // Block IPv6 private/special addresses
    if (hostname.startsWith('[') || hostname.includes(':')) {
      // Simplified IPv6 check - block all IPv6 for now as parsing is complex
      return { safe: false, reason: 'IPv6 addresses are not supported' };
    }

    return { safe: true };
  } catch (error) {
    return { safe: false, reason: `Invalid URL: ${error}` };
  }
}

/**
 * SECURITY: Validate mailto domain matches sender domain
 */
function isMailtoDomainValid(mailtoAddress: string, senderAddress: string): boolean {
  try {
    // Extract domain from mailto address
    const mailtoDomain = mailtoAddress.split('@')[1]?.toLowerCase();
    if (!mailtoDomain) return false;

    // Extract domain from sender address
    const senderDomain = senderAddress.split('@')[1]?.toLowerCase();
    if (!senderDomain) return false;

    // Check if domains match (allow subdomains)
    // e.g., unsubscribe@mail.example.com should match sender@example.com
    return mailtoDomain === senderDomain ||
           mailtoDomain.endsWith('.' + senderDomain) ||
           senderDomain.endsWith('.' + mailtoDomain);
  } catch {
    return false;
  }
}

/**
 * SECURITY: Check rate limit for mailto unsubscribes
 */
function checkMailtoRateLimit(): { allowed: boolean; reason?: string } {
  const now = Date.now();
  const oneHour = 60 * 60 * 1000;

  // Reset window if expired
  if (now - mailtoRateLimit.windowStart > oneHour) {
    mailtoRateLimit.count = 0;
    mailtoRateLimit.windowStart = now;
  }

  if (mailtoRateLimit.count >= mailtoRateLimit.maxPerHour) {
    return {
      allowed: false,
      reason: `Rate limit exceeded: max ${mailtoRateLimit.maxPerHour} mailto unsubscribes per hour`
    };
  }

  return { allowed: true };
}

/**
 * Increment mailto rate limit counter
 */
function incrementMailtoRateLimit(): void {
  mailtoRateLimit.count++;
}

/**
 * Fetch timeout in milliseconds
 */
const FETCH_TIMEOUT_MS = 10000;

/**
 * Fetch with timeout wrapper using AbortController
 */
async function fetchWithTimeout(url: string, options: RequestInit = {}): Promise<Response> {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal
    });
    return response;
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      throw new Error(`Request timed out after ${FETCH_TIMEOUT_MS}ms`);
    }
    throw error;
  } finally {
    clearTimeout(timeoutId);
  }
}

// Success indicators in response body (case-insensitive)
const SUCCESS_INDICATORS = [
  'unsubscribed',
  'successfully',
  'removed',
  'you have been removed',
  'you\'ve been removed',
  'preferences updated',
  'subscription cancelled',
  'subscription canceled',
  'no longer receive',
  'opted out',
  'thank you for unsubscribing',
  'you are now unsubscribed',
  'email preferences saved'
];

// Error indicators in response body (case-insensitive)
const ERROR_INDICATORS = [
  'error',
  'failed',
  'invalid',
  'expired',
  'not found',
  'unable to',
  'could not',
  'problem',
  'something went wrong',
  'already unsubscribed',
  'link has expired',
  'token invalid'
];

/**
 * Analyze response body to determine unsubscribe success
 */
function analyzeUnsubscribeResponse(body: string): {
  likelySuccess: boolean;
  likelyError: boolean;
  uncertain: boolean;
  indicators: string[];
} {
  const lowerBody = body.toLowerCase();
  const foundSuccess: string[] = [];
  const foundError: string[] = [];

  for (const indicator of SUCCESS_INDICATORS) {
    if (lowerBody.includes(indicator.toLowerCase())) {
      foundSuccess.push(indicator);
    }
  }

  for (const indicator of ERROR_INDICATORS) {
    if (lowerBody.includes(indicator.toLowerCase())) {
      foundError.push(indicator);
    }
  }

  // Determine outcome
  const hasSuccess = foundSuccess.length > 0;
  const hasError = foundError.length > 0;

  return {
    likelySuccess: hasSuccess && !hasError,
    likelyError: hasError && !hasSuccess,
    uncertain: (!hasSuccess && !hasError) || (hasSuccess && hasError),
    indicators: hasSuccess ? foundSuccess : foundError
  };
}

export class Unsubscriber {
  private browserUnsubscriber: BrowserUnsubscriber | null = null;

  /**
   * Set the browser unsubscriber instance (for shared lifecycle management)
   */
  setBrowserUnsubscriber(browserUnsubscriber: BrowserUnsubscriber): void {
    this.browserUnsubscriber = browserUnsubscriber;
  }

  /**
   * Try browser-based unsubscribe for complex pages
   */
  async tryBrowserUnsubscribe(url: string): Promise<UnsubscribeResult> {
    if (!this.browserUnsubscriber) {
      return { success: false, error: 'Browser unsubscriber not initialized' };
    }

    return await this.browserUnsubscriber.unsubscribeViaPage(url);
  }

  /**
   * Attempt to unsubscribe from an email
   * Uses List-Unsubscribe header if available
   */
  async unsubscribe(email: Email, client: GmailClient): Promise<UnsubscribeResult> {
    // Try one-click unsubscribe first (RFC 8058)
    if (email.listUnsubscribePost && email.listUnsubscribe) {
      const oneClickResult = await this.tryOneClick(email);
      if (oneClickResult.success) {
        return oneClickResult;
      }
    }

    // Try List-Unsubscribe header
    if (email.listUnsubscribe) {
      return await this.tryListUnsubscribe(email, client);
    }

    return { success: false, method: 'none', error: 'No unsubscribe mechanism found' };
  }

  /**
   * Try RFC 8058 one-click unsubscribe
   */
  private async tryOneClick(email: Email): Promise<UnsubscribeResult> {
    try {
      // Parse List-Unsubscribe header for HTTPS URL
      const urls = this.parseListUnsubscribe(email.listUnsubscribe!);
      const httpsUrl = urls.find(u => u.startsWith('https://'));

      if (!httpsUrl) {
        return { success: false, error: 'No HTTPS URL for one-click' };
      }

      // SECURITY: Validate URL is safe (SSRF prevention)
      const urlCheck = isUrlSafe(httpsUrl);
      if (!urlCheck.safe) {
        return { success: false, error: `URL blocked: ${urlCheck.reason}` };
      }

      // Check if List-Unsubscribe-Post is "List-Unsubscribe=One-Click"
      if (email.listUnsubscribePost?.includes('One-Click')) {
        const response = await fetchWithTimeout(httpsUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body: 'List-Unsubscribe=One-Click',
          redirect: 'manual' // SECURITY: Don't follow redirects automatically
        });

        if (response.ok || response.status === 202) {
          return { success: true, method: 'one-click' };
        }
      }

      return { success: false, error: 'One-click POST failed' };
    } catch (error) {
      return { success: false, error: `One-click error: ${error}` };
    }
  }

  /**
   * Try standard List-Unsubscribe (mailto or http)
   */
  private async tryListUnsubscribe(email: Email, client: GmailClient): Promise<UnsubscribeResult> {
    const urls = this.parseListUnsubscribe(email.listUnsubscribe!);

    // Try HTTPS first
    const httpsUrl = urls.find(u => u.startsWith('https://'));
    if (httpsUrl) {
      // SECURITY: Validate URL is safe (SSRF prevention)
      const urlCheck = isUrlSafe(httpsUrl);
      if (urlCheck.safe) {
        try {
          // Just GET the URL - most unsubscribe pages work with GET
          const response = await fetchWithTimeout(httpsUrl, {
            method: 'GET',
            redirect: 'follow', // Follow redirects for initial GET
            headers: {
              'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
            }
          });

          if (response.ok) {
            const contentType = response.headers.get('content-type') || '';
            const responseBody = await response.text();

            // Check if response indicates success
            const analysis = analyzeUnsubscribeResponse(responseBody);

            if (analysis.likelySuccess) {
              return { success: true, method: 'http' };
            }

            // If the page has HTML with forms/buttons, try browser automation
            if (contentType.includes('text/html') && this.requiresBrowserInteraction(responseBody)) {
              const browserResult = await this.tryBrowserUnsubscribe(httpsUrl);
              if (browserResult.success) {
                return browserResult;
              }
              // If browser also failed, continue to mailto fallback
            }

            // If uncertain but no clear error, consider it a success
            // (many pages just show a simple "unsubscribed" text)
            if (analysis.uncertain && !analysis.likelyError) {
              return { success: true, method: 'http' };
            }
          } else {
            // HTTP request failed, try browser automation
            const browserResult = await this.tryBrowserUnsubscribe(httpsUrl);
            if (browserResult.success) {
              return browserResult;
            }
          }
        } catch (error) {
          // Network error, try browser automation as fallback
          const browserResult = await this.tryBrowserUnsubscribe(httpsUrl);
          if (browserResult.success) {
            return browserResult;
          }
          // Fall through to mailto
        }
      }
    }

    // Try mailto
    const mailtoUrl = urls.find(u => u.startsWith('mailto:'));
    if (mailtoUrl) {
      try {
        const { to, subject, body } = this.parseMailto(mailtoUrl);

        // SECURITY: Validate mailto domain matches sender domain
        if (!isMailtoDomainValid(to, email.from)) {
          return {
            success: false,
            error: `Mailto domain mismatch: unsubscribe address domain does not match sender domain`
          };
        }

        // SECURITY: Check rate limit
        const rateCheck = checkMailtoRateLimit();
        if (!rateCheck.allowed) {
          return { success: false, error: rateCheck.reason };
        }

        await client.sendEmail(
          to,
          subject || 'Unsubscribe',
          body || 'Please unsubscribe me from this mailing list.'
        );

        // Increment rate limit counter after successful send
        incrementMailtoRateLimit();

        return { success: true, method: 'mailto' };
      } catch (error) {
        return { success: false, error: `Mailto error: ${error}` };
      }
    }

    return { success: false, error: 'No valid unsubscribe URL found' };
  }

  /**
   * Check if response HTML requires browser interaction (has forms/buttons)
   */
  private requiresBrowserInteraction(html: string): boolean {
    const htmlLower = html.toLowerCase();

    // Check for forms
    if (htmlLower.includes('<form')) {
      return true;
    }

    // Check for JavaScript-dependent content
    if (htmlLower.includes('onclick') ||
        htmlLower.includes('javascript:') ||
        htmlLower.includes('data-action')) {
      return true;
    }

    // Check for button elements that need clicking
    if (htmlLower.includes('<button') ||
        (htmlLower.includes('type="submit"') && htmlLower.includes('unsubscribe'))) {
      return true;
    }

    // Check for confirmation text suggesting interaction needed
    const interactionKeywords = [
      'click here to confirm',
      'click the button',
      'confirm your unsubscription',
      'please confirm',
      'enter your email',
    ];

    return interactionKeywords.some(keyword => htmlLower.includes(keyword));
  }

  /**
   * Parse List-Unsubscribe header into array of URLs
   * Format: <url1>, <url2> or <url1>
   */
  private parseListUnsubscribe(header: string): string[] {
    const urls: string[] = [];
    const matches = header.match(/<([^>]+)>/g);

    if (matches) {
      for (const match of matches) {
        urls.push(match.slice(1, -1)); // Remove < >
      }
    }

    return urls;
  }

  /**
   * Parse mailto: URL into components
   */
  private parseMailto(mailto: string): { to: string; subject?: string; body?: string } {
    const url = new URL(mailto);
    const to = url.pathname;
    const subject = url.searchParams.get('subject') || undefined;
    const body = url.searchParams.get('body') || undefined;

    return { to, subject, body };
  }
}
