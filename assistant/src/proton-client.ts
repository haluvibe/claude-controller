/**
 * Proton Mail Client
 *
 * Connects to Proton Mail Bridge via IMAP (imapflow) and SMTP (nodemailer)
 * for reading, moving, trashing, and sending emails.
 */

import { ImapFlow, FetchMessageObject } from 'imapflow';
import { createTransport, Transporter } from 'nodemailer';
import { simpleParser, ParsedMail } from 'mailparser';
import { Email, EmailSender } from './email-types.js';

export interface ProtonConfig {
  imap: {
    host: string;
    port: number;
    auth: { user: string; pass: string };
    tls?: { rejectUnauthorized?: boolean };
  };
  smtp: {
    host: string;
    port: number;
    auth: { user: string; pass: string };
    tls?: { rejectUnauthorized?: boolean };
  };
}

export class ProtonClient implements EmailSender {
  private imap: ImapFlow;
  private smtp: Transporter;
  private config: ProtonConfig;

  constructor(config: ProtonConfig) {
    this.config = config;

    // Proton Bridge runs on localhost and uses a self-signed TLS certificate.
    // We disable certificate verification (rejectUnauthorized: false) because:
    //   1. Bridge only listens on 127.0.0.1 — traffic never leaves the machine.
    //   2. Bridge uses STARTTLS (not implicit TLS), so `secure` must be false
    //      to allow the connection to upgrade via the STARTTLS command.
    //   3. The self-signed cert would fail Node's default CA verification.
    // This is safe ONLY for localhost Bridge connections. Do NOT use this
    // setting for remote IMAP/SMTP servers.
    this.imap = this.createImapClient();

    this.smtp = createTransport({
      host: config.smtp.host,
      port: config.smtp.port,
      secure: false,
      auth: config.smtp.auth,
      tls: {
        rejectUnauthorized: config.smtp.tls?.rejectUnauthorized ?? false,
      },
    });
  }

  /**
   * Create a fresh ImapFlow instance from config.
   */
  private createImapClient(): ImapFlow {
    return new ImapFlow({
      host: this.config.imap.host,
      port: this.config.imap.port,
      secure: false,
      auth: this.config.imap.auth,
      tls: {
        rejectUnauthorized: this.config.imap.tls?.rejectUnauthorized ?? false,
      },
      logger: false,
      // Keep socket alive during long IDLE periods. The default (5 min) kills
      // idle connections before the server's own IDLE timeout (~29 min).
      socketTimeout: 10 * 60 * 1000, // 10 minutes
      // We manage IDLE ourselves in startIdle(); prevent ImapFlow from
      // entering IDLE automatically which can conflict with our loop.
      disableAutoIdle: true,
    });
  }

  /**
   * Recreate the IMAP connection with a fresh instance.
   * Used when the existing connection is broken beyond recovery.
   */
  async reconnect(): Promise<void> {
    try { await this.imap.logout(); } catch { /* already dead */ }
    this.imap = this.createImapClient();
    await this.imap.connect();
  }

  async connect(): Promise<void> {
    await this.imap.connect();
  }

  async disconnect(): Promise<void> {
    await this.imap.logout();
  }

  /**
   * Test the connection by logging in and listing the INBOX.
   */
  async testConnection(): Promise<{ imap: boolean; smtp: boolean; folders: string[] }> {
    let imapOk = false;
    let smtpOk = false;
    let folders: string[] = [];

    try {
      await this.imap.connect();
      folders = await this.listFolders();
      imapOk = true;
      await this.imap.logout();
    } catch {
      imapOk = false;
    }

    try {
      await this.smtp.verify();
      smtpOk = true;
    } catch {
      smtpOk = false;
    }

    return { imap: imapOk, smtp: smtpOk, folders };
  }

  /**
   * List all IMAP folders.
   */
  async listFolders(): Promise<string[]> {
    const tree = await this.imap.list();
    return tree.map(f => f.path);
  }

  /**
   * Ensure a folder exists, creating it if necessary.
   */
  async ensureFolder(path: string): Promise<void> {
    const folders = await this.listFolders();
    if (!folders.includes(path)) {
      await this.imap.mailboxCreate(path);
    }
  }

  /**
   * Fetch unread emails from a mailbox.
   */
  async fetchUnread(mailbox: string = 'INBOX', limit: number = 50): Promise<Email[]> {
    const lock = await this.imap.getMailboxLock(mailbox);
    try {
      const emails: Email[] = [];
      let count = 0;

      // Search for unseen messages
      const result = await this.imap.search({ seen: false }, { uid: true });
      if (!result || (Array.isArray(result) && result.length === 0)) return [];

      const uids = Array.isArray(result) ? result : [];
      // Fetch in reverse order (newest first) and respect limit
      const targetUids = uids.reverse().slice(0, limit);

      for await (const msg of this.imap.fetch(targetUids, {
        source: true,
        uid: true,
        flags: true,
        envelope: true,
      }, { uid: true })) {
        if (count >= limit) break;

        const email = await this.parseMessage(msg);
        if (email) {
          emails.push(email);
          count++;
        }
      }

      return emails;
    } finally {
      lock.release();
    }
  }

  /**
   * Move a message to a different folder by UID.
   */
  async moveToFolder(uid: number, sourceMailbox: string, destinationFolder: string): Promise<void> {
    const lock = await this.imap.getMailboxLock(sourceMailbox);
    try {
      await this.imap.messageMove(String(uid), destinationFolder, { uid: true });
    } finally {
      lock.release();
    }
  }

  /**
   * Mark a message as read (add \Seen flag).
   */
  async markAsRead(uid: number, mailbox: string = 'INBOX'): Promise<void> {
    const lock = await this.imap.getMailboxLock(mailbox);
    try {
      await this.imap.messageFlagsAdd(String(uid), ['\\Seen'], { uid: true });
    } finally {
      lock.release();
    }
  }

  /**
   * Move a message to Trash.
   */
  async trash(uid: number, mailbox: string = 'INBOX'): Promise<void> {
    const lock = await this.imap.getMailboxLock(mailbox);
    try {
      await this.imap.messageMove(String(uid), 'Trash', { uid: true });
    } finally {
      lock.release();
    }
  }

  /**
   * Send an email via SMTP (implements EmailSender).
   */
  async sendEmail(to: string, subject: string, body: string): Promise<void> {
    await this.smtp.sendMail({
      from: this.config.smtp.auth.user,
      to,
      subject,
      text: body,
    });
  }

  /**
   * Start IMAP IDLE on a mailbox and call the handler on new mail.
   * Returns a function to stop idling.
   *
   * The loop acquires a mailbox lock for IDLE, releases it before
   * calling onNewMail (so the handler can acquire its own locks),
   * then re-acquires for the next IDLE cycle.  On connection failure
   * the ImapFlow instance is fully recreated.
   *
   * Proton Bridge does not reliably push IMAP IDLE EXISTS notifications,
   * so we race idle() against a poll timer. If idle() hasn't resolved
   * after IDLE_POLL_INTERVAL_MS we break out, check for new mail anyway,
   * and re-enter IDLE. This guarantees the daemon processes incoming
   * mail within the poll interval even if Bridge never sends EXISTS.
   */
  private static readonly IDLE_POLL_INTERVAL_MS = 5 * 60 * 1000; // 5 minutes

  async startIdle(
    mailbox: string,
    onNewMail: () => Promise<void>,
  ): Promise<() => void> {
    let running = true;
    let backoff = 10_000; // start at 10s, cap at 5 min

    const idleLoop = async () => {
      while (running) {
        let lock;
        try {
          lock = await this.imap.getMailboxLock(mailbox);

          // Race idle() against a poll timeout. If Proton Bridge sends an
          // EXISTS notification idle() resolves immediately; otherwise we
          // time out after IDLE_POLL_INTERVAL_MS and poll manually.
          const idleResult = await Promise.race([
            this.imap.idle().then(() => 'exists' as const),
            new Promise<'timeout'>(r =>
              setTimeout(() => r('timeout'), ProtonClient.IDLE_POLL_INTERVAL_MS),
            ),
          ]);

          lock.release();
          lock = undefined;

          if (running) {
            backoff = 10_000; // reset backoff on success
            if (idleResult === 'timeout') {
              console.log('[ProtonClient] IDLE poll timeout — checking for new mail');
            }
            await onNewMail();
          }
        } catch (err) {
          if (lock) { try { lock.release(); } catch { /* ignore */ } }

          if (running) {
            console.error(`[ProtonClient] IDLE error, reconnecting in ${backoff / 1000}s:`, err);
            await new Promise(r => setTimeout(r, backoff));
            backoff = Math.min(backoff * 2, 300_000); // exponential up to 5 min

            try {
              await this.reconnect();
              console.log('[ProtonClient] Reconnected successfully');
              // Process any mail that arrived while disconnected
              await onNewMail();
              backoff = 10_000; // reset on successful reconnect
            } catch (reconnectErr) {
              console.error('[ProtonClient] Reconnect failed:', reconnectErr);
              // Will retry on next loop iteration with increased backoff
            }
          }
        }
      }
    };

    // Fire-and-forget the loop
    idleLoop();

    return () => {
      running = false;
    };
  }

  /**
   * Parse a raw IMAP message into our Email interface.
   */
  private async parseMessage(msg: FetchMessageObject): Promise<Email | null> {
    try {
      if (!msg.source) {
        console.error('[ProtonClient] No source for message UID', msg.uid);
        return null;
      }

      const parsed = await simpleParser(msg.source);

      const headers = new Map<string, string>();
      if (parsed.headers) {
        for (const [key, value] of parsed.headers) {
          if (typeof value === 'string') {
            headers.set(key.toLowerCase(), value);
          } else if (value && typeof value === 'object' && 'value' in value) {
            headers.set(key.toLowerCase(), String((value as { value: unknown }).value));
          }
        }
      }

      // Extract List-Unsubscribe header
      const listUnsubscribe = headers.get('list-unsubscribe') || undefined;
      const listUnsubscribePost = headers.get('list-unsubscribe-post') || undefined;

      // Handle to field which can be AddressObject or AddressObject[]
      const toField = parsed.to;
      const toText = Array.isArray(toField)
        ? toField.map(a => a.text).join(', ')
        : toField?.text || '';

      return {
        id: String(msg.uid),
        threadId: parsed.messageId || undefined,
        from: parsed.from?.text || '',
        to: toText,
        subject: parsed.subject || '(no subject)',
        body: parsed.text || parsed.html || '',
        date: parsed.date || new Date(),
        labels: Array.from(msg.flags || []),
        headers,
        listUnsubscribe,
        listUnsubscribePost,
      };
    } catch (err) {
      console.error('[ProtonClient] Failed to parse message UID', msg.uid, err);
      return null;
    }
  }
}

/**
 * Load ProtonConfig from environment variables.
 */
export function loadProtonConfig(): ProtonConfig {
  const user = process.env.PROTON_BRIDGE_USER;
  const pass = process.env.PROTON_BRIDGE_PASS;
  const imapHost = process.env.PROTON_IMAP_HOST || '127.0.0.1';
  const imapPort = parseInt(process.env.PROTON_IMAP_PORT || '1143', 10);
  const smtpHost = process.env.PROTON_SMTP_HOST || '127.0.0.1';
  const smtpPort = parseInt(process.env.PROTON_SMTP_PORT || '1025', 10);

  if (!user || !pass) {
    throw new Error(
      'PROTON_BRIDGE_USER and PROTON_BRIDGE_PASS must be set.\n' +
      'Create assistant/config/.env.proton with your Bridge credentials.',
    );
  }

  return {
    imap: {
      host: imapHost,
      port: imapPort,
      auth: { user, pass },
      tls: { rejectUnauthorized: false },
    },
    smtp: {
      host: smtpHost,
      port: smtpPort,
      auth: { user, pass },
      tls: { rejectUnauthorized: false },
    },
  };
}
