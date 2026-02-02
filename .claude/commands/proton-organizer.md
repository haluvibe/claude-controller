---
description: "Scan Proton Mail inbox for marketing and notification emails, classify them, and sort into folders via IMAP"
allowed-tools: Bash, Read, Edit
---

# Proton Mail Organizer

Scan unread Proton Mail emails via Bridge IMAP, classify marketing vs. notification vs. important, unsubscribe from marketing, and sort notifications into a dedicated folder.

## Memory

Before processing, read the memory file for learned preferences:
`.claude/skills/proton-organizer/MEMORY.md`

After processing, update that file with any new decisions.

## Step 1: Test Connection

Verify Proton Bridge is running and accessible:

```bash
cd /Users/paulhayes/automations/claude-controller/assistant && node dist/proton-scan.js test-connection
```

If connection fails, tell the user to start Proton Mail Bridge.

## Session Log

Before processing, read the session log for history of past runs:
`.claude/skills/proton-organizer/SESSION-LOG.md`

After processing, append a new entry to the session log with:
- Session number and date/time
- Number of emails scanned
- Classifications breakdown (keep / notification / marketing)
- All actions taken (unsubscribe attempts, trash, move, archive) with timestamps
- Any errors encountered
- Connection status

## Step 2: Scan Inbox

**IMPORTANT: Only process emails from the last 48 hours. When fetching messages via IMAP, only retrieve messages with a SINCE date of 2 days ago. Never process emails older than 48 hours. If using the CLI scanner, pass `--since 2d` to limit the date range. If the scanner does not support a date flag, filter results after fetching to exclude anything older than 48 hours.**

Fetch and classify unread emails (read-only, no side effects):

```bash
cd /Users/paulhayes/automations/claude-controller/assistant && node dist/proton-scan.js scan --limit 30 --json
```

Parse the JSON output. Each email gets a classification:
- **marketing**: score >= 4 (same scoring as Gmail organizer)
- **notification**: automated emails from dev tools, CI/CD, monitoring, social (score >= 3)
- **keep**: everything else

### Classification Rules

**Marketing Indicators (score-based, unsubscribe if score >= 4):**
- Sender patterns (+2): `no-reply@`, `newsletter@`, `marketing@`, `promotions@`, etc.
- Subject patterns (+2): sale/discount/deal/save/free/limited/offer
- List-Unsubscribe header (+3)
- Sent via marketing platform (+3): mailchimp, sendgrid, hubspot, etc.
- Campaign tracking headers (+2)
- Precedence: bulk/list (+2)
- Body contains "unsubscribe" (+1)

**Notification Indicators (score >= 3):**
- Sender domain (+3): github.com, slack.com, sentry.io, circleci.com, vercel.com, etc.
- Notification prefix + automated headers (+3): notify@, alert@, noreply@ with Auto-Submitted
- Automated headers (+2): x-github-reason, auto-submitted, x-notifications
- Subject patterns (+1): [org/repo], "build passed", "deploy complete", "alert"
- Categories: github, gitlab, slack, firebase, ci-cd, monitoring, social, service, security

**NEVER Unsubscribe From:**
- Receipts, invoices, order confirmations
- Password resets, security alerts, 2FA
- Appointments, bookings
- GitHub/GitLab/Bitbucket notifications (move to Notifications instead)
- Google/Apple/Microsoft account emails
- Conversation threads (have In-Reply-To/References headers)

### Memory Override

Check MEMORY.md first:
- If sender is in "Always Unsubscribe": auto-classify as marketing
- If sender is in "Never Unsubscribe": skip
- If sender is in "Always Move to Notifications": auto-classify as notification

## Step 3: Report Findings

Present a summary table in newest-first order:

```
| # | Date | From | Subject | Classification | Category | Confidence | Action |
```

The Category column shows the notification sub-category (github, slack, ci-cd, etc.) or "marketing" / "keep".

## Step 4: Act (automatic)

**Do NOT ask for user confirmation. Process all classified emails immediately.** This skill runs headless via `claude -p` and there is no user to respond. Execute the plan directly:
- Marketing emails: attempt unsubscribe + trash
- Notification emails: move to "Folders/Notifications" folder
- Keep emails: archive out of inbox (mark read + move to Archive)

Run with `--archive` to clear non-important emails from inbox:

```bash
cd /Users/paulhayes/automations/claude-controller/assistant && node dist/proton-scan.js act --limit 50 --archive --json
```

This processes ALL non-important emails:
- **Marketing** → unsubscribe attempt + trash
- **Notifications** → move to Folders/Notifications
- **Keep** (with `--archive`) → mark read + move to Archive

Selective options:
```bash
# Archive only (no unsubscribe, no trash, no notification move)
node dist/proton-scan.js act --no-unsubscribe --no-trash --no-move --archive --json

# Full cleanup except archiving kept emails
node dist/proton-scan.js act --json

# Only move notifications
node dist/proton-scan.js act --no-unsubscribe --no-trash --json
```

## Step 5: Update Memory

After processing, update `.claude/skills/proton-organizer/MEMORY.md`:
1. Add new sender preferences based on classifications and user decisions
2. Log decisions in the Decision Log
3. Update statistics
4. Note any new patterns learned

## Safety Rules

- When uncertain about classification, default to "keep" (do not ask — this runs headless)
- Notifications are moved, NOT deleted (always recoverable)
- Marketing emails go to Trash (Proton keeps for 30 days)
- Max 10 unsubscribe attempts per run
- Log all actions for review
- IMAP operations are all reversible (move back from Trash/Notifications)
