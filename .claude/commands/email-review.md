---
description: "Review the health and effectiveness of the entire email automation stack"
allowed-tools: mcp__gmail__gmail_search_messages, mcp__gmail__gmail_read_message, mcp__gmail__gmail_read_thread, Read, Bash, Edit, Write, Glob, Grep
---

# Email Review Agent

Audit the last 30 days of emails across Gmail and Proton Mail. Verify the organizers (Gmail organizer + Proton daemon) classified and actioned everything correctly — nothing important was trashed, nothing junk was left in the inbox, no senders are being repeatedly re-processed instead of memorized.

**You are allowed to fix problems you find.** Update memory files, clean up stale pending actions, add missing sender rules, and fix contradictions. This is how the email automation stack improves over time.

## Step 1: Check Gmail (last 30 days)

### 1a. Review what's sitting in the inbox

Search for emails still in the inbox from the last 30 days:

```
mcp__gmail__gmail_search_messages({ q: "in:inbox newer_than:30d", maxResults: 50 })
```

Read each email. Check:
- Are any of these obvious marketing/junk that the organizer should have caught?
- Are any low-priority notifications still sitting unread that should have been archived?
- Flag any senders that look like they should be in MEMORY.md but aren't.

### 1b. Review what was trashed

Search for recently trashed emails:

```
mcp__gmail__gmail_search_messages({ q: "in:trash newer_than:30d", maxResults: 50 })
```

Read each email. Check:
- Were any important/personal emails incorrectly trashed?
- Were any receipts, security alerts, or transactional emails trashed by mistake?
- Are the trashed emails genuinely marketing/junk?

### 1c. Review the session log

Read `.claude/skills/gmail-unsubscribe/SESSION-LOG.md`. Check:
- How many runs in the last 30 days?
- What's the classification breakdown across runs?
- Are any senders showing up repeatedly (being reclassified each run instead of memorized)?
- Are runs actually taking action (trash/archive) or just classifying with no follow-through?

### 1d. Check pending actions

Read `.claude/skills/gmail-unsubscribe/pending-actions.json` if it exists:
- How many actions are queued? How old?
- Is the backlog growing because Chrome is never available?
- **Fix:** If actions are older than 7 days, they're stale — delete the file so the organizer starts fresh next run.

### 1e. Check and fix memory health

Read `.claude/skills/gmail-unsubscribe/MEMORY.md`:
- Is it growing appropriately (new senders being added)?
- Any contradictions (same sender in multiple lists)?
- Any senders that should be there based on session log patterns but are missing?

**Fix any issues you find:**
- Remove contradictions (sender in both "Always Unsubscribe" and "Never Unsubscribe")
- Add senders that appear 3+ times in session logs to the appropriate memory list
- Add senders you identified in Step 1a (junk still in inbox) to "Always Unsubscribe" or "Auto-Trash"
- Add senders you identified in Step 1b (legitimate emails incorrectly trashed) to "Never Unsubscribe" or "Trusted Senders"

## Step 2: Check Proton Mail (last 30 days)

### 2a. Scan current inbox

```bash
cd /Users/paulhayes/automations/claude-controller/assistant && node dist/proton-scan.js scan --limit 50 --json
```

Check the results:
- Are any obvious marketing/notification emails still in the inbox?
- Is the daemon actually moving notifications to the Notifications folder?
- Any senders that keep appearing that should be auto-handled?

### 2b. Review the session log

Read `.claude/skills/proton-organizer/SESSION-LOG.md`. Check:
- How many runs/actions in the last 30 days?
- Classification breakdown — keep/notification/marketing ratio
- Repeat senders being re-processed instead of memorized

### 2c. Check Proton daemon logs

Read `~/Library/Logs/proton-daemon/stdout.log` (last 30 days of entries). Check:
- Is the daemon actively processing incoming mail?
- Any errors or connection drops?
- How many emails has it sorted?

### 2d. Check and fix memory health

Read `.claude/skills/proton-organizer/MEMORY.md`:
- Same checks as Gmail memory — growing, no contradictions, no missing patterns

**Fix any issues you find:**
- Remove contradictions
- Add repeat senders from session logs to appropriate lists
- Add senders from Step 2a (junk still in inbox) to "Always Unsubscribe" or "Always Move to Notifications"

## Step 3: Cross-check and Produce Report

Write a concise summary:

```
## Email Review — <date>

### Overall Verdict: <GOOD / NEEDS ATTENTION / PROBLEMS FOUND>

### Gmail (30 days)
- Inbox: X emails — Y look like missed junk, Z are legitimate
- Trash: X emails checked — Y were correctly trashed, Z look like mistakes
- Sessions: X runs, Y% of runs took action
- Pending: X actions queued (age: Y days)
- Repeat offenders: <senders appearing in multiple runs without being memorized>

### Proton (30 days)
- Inbox: X emails — Y look like missed junk, Z are legitimate
- Daemon: X emails processed, Y errors, Z restarts
- Sessions: X organizer runs
- Repeat offenders: <senders appearing repeatedly>

### Misclassifications Found
- <list any emails that were incorrectly trashed or incorrectly left in inbox>
- If none: "No misclassifications detected"

### Fixes Applied
- <list all changes made to MEMORY.md files, pending-actions.json, etc.>
- If none: "No fixes needed"

### Remaining Recommendations
- <anything that requires manual intervention or a code change to the organizers/daemon>
```

## Step 4: Send iPad Notification

```bash
curl -s -X POST "http://localhost:19847/notify" \
  -H "Content-Type: application/json" \
  -d '{"message": "Email Review: <GOOD/NEEDS ATTENTION/PROBLEMS> — <1-line summary>"}' \
  || true
```

## Step 5: Update Review Log

Append the full report to `.claude/skills/email-review/REVIEW-LOG.md` with a timestamp header:

```markdown
---

## Review — <YYYY-MM-DD HH:MM>

<full report from Step 3>
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

- **Last 30 days only.** Don't process or report on anything older.
- **Be specific.** Cite sender addresses, subject lines, dates, and counts. Don't say "looks good" — say "42 emails in trash, all correctly classified marketing."
- **Focus on mistakes.** The most valuable output is catching things the organizers got wrong — important emails trashed, junk left in inbox, senders not memorized.
- **Fix what you can.** If a sender keeps being reclassified, add it to memory. If a rule is wrong, fix it. If pending actions are stale, clear them. Don't just report — improve.
- **Don't touch emails.** You review and fix the automation config, but you don't trash/archive/move emails yourself. That's the organizers' job.
