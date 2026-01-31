# Email Automation Stack — Design Goal

The entire email automation stack must run autonomously. You should be able to reboot your Mac, open Proton Mail Bridge, walk away, and trust that all four services come up, do their jobs, self-heal on failure, and improve over time — with zero ongoing human intervention.

The only manual step is opening Proton Mail Bridge after a reboot (it doesn't auto-start). Everything else is self-managing: the organizers classify and act, the watchdog monitors and restarts, and the review agent audits the results and fixes the organizers' rules when they get things wrong.

## The Four Services

1. **Proton Daemon** — always-on Node.js IMAP IDLE process. Classifies and sorts incoming Proton mail in real-time. Self-restarts via launchd KeepAlive.

2. **Gmail Organizer** — scheduled `claude -p` session every 4 hours. AI-classifies unread Gmail, trashes marketing, archives low-priority. Queues actions when Chrome is unavailable.

3. **Email Watchdog** — bash script every 15 minutes. Checks all services are alive and not stuck. Auto-restarts failed services. Sends iPad notification on issues.

4. **Email Review Agent** — scheduled `claude -p` session twice daily. Audits the last 30 days of actual emails across both inboxes. Catches misclassifications, fixes memory files, improves organizer rules. The mechanism by which the whole stack gets better over time.

## Autonomy Requirements

- After a reboot + Bridge open, all services must come up without further input.
- No service should require interactive approval to do its job.
- Failures must be detected and recovered automatically (watchdog).
- Classification mistakes must be caught and corrected automatically (review agent).
- The system must improve its own rules over time without being told to.
