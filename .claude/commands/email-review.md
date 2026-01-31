---
description: "Review the health and effectiveness of the entire email automation stack"
allowed-tools: mcp__gmail__gmail_search_messages, mcp__gmail__gmail_read_message, mcp__gmail__gmail_read_thread, Read, Bash, Edit, Write, Glob, Grep
---

# Email Review Agent

Audit the last 24 hours of emails across Gmail and Proton Mail. Verify the organizers (Gmail organizer + Proton daemon) classified and actioned everything correctly — nothing important was trashed, nothing junk was left in the inbox, no senders are being repeatedly re-processed instead of memorized.

**You MUST fix problems as you find them.** When you discover a missing sender, edit MEMORY.md immediately before moving on. When you find stale pending actions, delete the file right then. Do not defer fixes to a recommendations section — apply them inline as each issue is discovered. This is the mechanism by which the whole stack improves over time.

## Step 1: Check Gmail (last 24 hours)

### 1a. Review what's sitting in the inbox

Search for emails still in the inbox from the last 24 hours:

```
mcp__gmail__gmail_search_messages({ q: "in:inbox newer_than:1d", maxResults: 50 })
```

Read each email. For each one, check:
- Is this obvious marketing/junk that the organizer should have caught?
- Is this a low-priority notification that should have been archived?
- Is this sender missing from MEMORY.md?

**FIX INLINE:** If you find a sender that should be in MEMORY.md but isn't, edit `.claude/skills/gmail-unsubscribe/MEMORY.md` RIGHT NOW — add them to the appropriate list (Always Unsubscribe, Auto-Trash, Auto-Read + Archive, or Keep Unread) before moving to the next email.

### 1b. Review what was trashed

Search for recently trashed emails:

```
mcp__gmail__gmail_search_messages({ q: "in:trash newer_than:1d", maxResults: 50 })
```

Read each email. For each one, check:
- Was this important/personal email incorrectly trashed?
- Was this a receipt, security alert, or transactional email trashed by mistake?

**FIX INLINE:** If you find a legitimate email that was incorrectly trashed, edit `.claude/skills/gmail-unsubscribe/MEMORY.md` RIGHT NOW — add the sender to "Keep Unread" or "Never Unsubscribe" before moving on.

### 1c. Review the session log

Read `.claude/skills/gmail-unsubscribe/SESSION-LOG.md` (last 24h entries only). Check:
- How many runs in the last 24 hours?
- Are any senders showing up repeatedly (being reclassified each run instead of memorized)?
- Are runs actually taking action (trash/archive) or just classifying with no follow-through?

### 1d. Check pending actions

Read `.claude/skills/gmail-unsubscribe/pending-actions.json` if it exists:
- How many actions are queued? How old?
- Is the backlog growing because Chrome is never available?

**FIX INLINE:** If actions are older than 7 days, delete the file right now so the organizer starts fresh next run.

### 1e. Check and fix memory health

Read `.claude/skills/gmail-unsubscribe/MEMORY.md`:
- Any contradictions (same sender in multiple lists)?
- Any senders from Steps 1a-1c that still need adding?

**FIX INLINE:** Remove contradictions immediately. Add any remaining missing senders.

### 1f. Check classified-ids health

Read `.claude/skills/gmail-unsubscribe/classified-ids.json` if it exists:
- How many IDs tracked?
- Is the file growing unboundedly? (Should cap at ~500 entries)

**FIX INLINE:** If the file has >500 entries, trim to the most recent 200.

## Step 2: Check Proton Mail (last 24 hours)

### 2a. Scan current inbox

```bash
cd /Users/paulhayes/automations/claude-controller/assistant && node dist/proton-scan.js scan --limit 50 --json
```

Check the results:
- Are any obvious marketing/notification emails still in the inbox?
- Is the daemon actually moving notifications to the Notifications folder?

**FIX INLINE:** If a sender keeps appearing in the inbox that should be handled, edit `.claude/skills/proton-organizer/MEMORY.md` RIGHT NOW.

### 2b. Check Proton Trash and Notifications folders

```bash
cd /Users/paulhayes/automations/claude-controller/assistant && node dist/proton-scan.js scan --mailbox Trash --limit 30 --json
cd /Users/paulhayes/automations/claude-controller/assistant && node dist/proton-scan.js scan --mailbox "Folders/Notifications" --limit 30 --json
```

Check the results:
- Were any important emails incorrectly trashed by the daemon?
- Were any important emails incorrectly moved to Notifications?

**FIX INLINE:** If a legitimate email was misclassified, edit `.claude/skills/proton-organizer/MEMORY.md` RIGHT NOW — add the sender to "Never Unsubscribe".

### 2c. Check Proton daemon logs

Read `~/Library/Logs/proton-daemon/stdout.log` (last 24 hours of entries). Check:
- Is the daemon actively processing incoming mail?
- Any errors or connection drops?
- How many emails has it sorted?

### 2d. Check and fix memory health

Read `.claude/skills/proton-organizer/MEMORY.md`:
- Any contradictions?
- Any missing senders from Steps 2a-2b?

**FIX INLINE:** Remove contradictions and add missing senders immediately.

## Step 3: Cross-Platform Sync

Compare the two MEMORY.md files and sync sender rules:

1. Read `.claude/skills/gmail-unsubscribe/MEMORY.md` (the "Always Unsubscribe" list)
2. Read `.claude/skills/proton-organizer/MEMORY.md` (the "Always Unsubscribe" list)
3. For each sender on Gmail's marketing list that is missing from Proton's marketing list: **add it to Proton MEMORY.md right now**
4. For each sender on Proton's marketing list that is missing from Gmail's marketing list: **add it to Gmail MEMORY.md right now**
5. Same for "Never Unsubscribe" / "Keep Unread" lists — sync important senders both ways

Report how many senders were synced in each direction.

## Step 4: Produce Report

Write a concise summary with a letter grade (A through D-):

```
## Email Review — <date>

### Overall Grade: <A/B+/B/C+/C/D+/D/D->

Grading criteria:
- A: Zero misclassifications, all services running, no backlog
- B: 1-2 minor issues, services healthy, small backlog
- C: 3-5 issues, some service problems, growing backlog
- D: 6+ issues, services failing, large unresolved backlog

### Gmail (24 hours)
- Inbox: X emails — Y missed junk, Z legitimate
- Trash: X emails checked — Y correctly trashed, Z mistakes
- Sessions: X runs, Y took action
- Pending: X actions queued (age: Y days)

### Proton (24 hours)
- Inbox: X emails
- Trash: X emails checked for false positives
- Notifications: X emails checked for false positives
- Daemon: X emails processed, Y errors

### Misclassifications Found
- <list with sender, subject, date, what went wrong>
- If none: "No misclassifications detected"

### Fixes Applied
- <list every MEMORY.md edit, pending-actions cleanup, classified-ids trim, cross-platform sync>
- If none: "No fixes needed"

### Remaining Issues
- <anything that requires manual intervention or a code change>
```

## Step 5: Send iPad Notification

```bash
curl -s -X POST "http://localhost:19847/notify" \
  -H "Content-Type: application/json" \
  -d '{"message": "Email Review: Grade <X> — <1-line summary>"}' \
  || true
```

## Step 6: Update Review Log

Append the full report to `.claude/skills/email-review/REVIEW-LOG.md` with a timestamp header:

```markdown
---

## Review — <YYYY-MM-DD HH:MM>

<full report from Step 4>
```

Create the file if it doesn't exist yet.

## What You Can Modify

These files are yours to improve:

- `.claude/skills/gmail-unsubscribe/MEMORY.md` — Add/remove sender rules, fix contradictions
- `.claude/skills/proton-organizer/MEMORY.md` — Add/remove sender rules, fix contradictions
- `.claude/skills/gmail-unsubscribe/pending-actions.json` — Delete if stale (>7 days old)
- `.claude/skills/email-review/REVIEW-LOG.md` — Append review findings
- `.claude/commands/gmail-organizer.md` — Improve classification rules, fix bugs, tune thresholds
- `.claude/commands/proton-organizer.md` — Improve classification rules, fix bugs, tune thresholds
- `assistant/src/proton-client.ts` — Fix Proton daemon bugs if you identify them from logs

## Rules

- **Last 24 hours only.** Don't process or report on anything older.
- **Be specific.** Cite sender addresses, subject lines, dates, and counts. Don't say "looks good" — say "42 emails in trash, all correctly classified marketing."
- **Focus on mistakes.** The most valuable output is catching things the organizers got wrong — important emails trashed, junk left in inbox, senders not memorized.
- **Fix what you can.** If a sender keeps being reclassified, add it to memory. If a rule is wrong, fix it. If pending actions are stale, clear them. Don't just report — improve.
- **Don't touch emails.** You review and fix the automation config, but you don't trash/archive/move emails yourself. That's the organizers' job.
