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
    this.imap = new ImapFlow({
      host: config.imap.host,
      port: config.imap.port,
      secure: false,
      auth: config.imap.auth,
      tls: {
        rejectUnauthorized: config.imap.tls?.rejectUnauthorized ?? false,
      },
      logger: false,
    });

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
   */
  async startIdle(
    mailbox: string,
    onNewMail: () => Promise<void>,
  ): Promise<() => void> {
    await this.imap.getMailboxLock(mailbox);

    let running = true;

    const idleLoop = async () => {
      while (running) {
        try {
          // idle() resolves when the server sends an EXISTS update or the
          // idle timeout (29 min default) expires.
          await this.imap.idle();
          if (running) {
            await onNewMail();
          }
        } catch (err) {
          if (running) {
            // Reconnect after a brief delay
            console.error('[ProtonClient] IDLE error, reconnecting in 10s:', err);
            await new Promise(r => setTimeout(r, 10_000));
            try {
              await this.imap.connect();
              await this.imap.getMailboxLock(mailbox);
            } catch {
              // Will retry on next loop iteration
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
