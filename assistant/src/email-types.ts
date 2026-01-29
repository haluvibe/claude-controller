/**
 * Shared email interfaces used across Gmail and Proton clients.
 */

export interface Email {
  id: string;
  threadId?: string;
  from: string;
  to: string;
  subject: string;
  body: string;
  date: Date;
  labels: string[];
  headers: Map<string, string>;
  listUnsubscribe?: string;
  listUnsubscribePost?: string;
}

export interface EmailSender {
  sendEmail(to: string, subject: string, body: string): Promise<void>;
}
