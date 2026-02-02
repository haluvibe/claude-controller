---
description: "Scan inbox for marketing emails, report findings, and optionally unsubscribe via List-Unsubscribe headers"
allowed-tools: mcp__gmail__gmail_search_messages, mcp__gmail__gmail_read_message, mcp__gmail__gmail_read_thread, mcp__gmail__gmail_create_draft, mcp__gmail__gmail_list_drafts, mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__tabs_create_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_page, mcp__claude-in-chrome__find, mcp__claude-in-chrome__computer, mcp__claude-in-chrome__javascript_tool, mcp__claude-in-chrome__get_page_text, Read, Edit, WebFetch
---

# Gmail Organizer

Scan unread emails, classify into 4 tiers (important / low-priority / marketing / auto-trash), and clean up via Chrome. Important emails stay unread. Everything else gets handled automatically.

## THIS SKILL REQUIRES CLAUDE IN CHROME — NO EXCEPTIONS

**CLAUDE IN CHROME IS MANDATORY. THIS SKILL MUST USE CLAUDE IN CHROME (`mcp__claude-in-chrome__*` TOOLS) TO TRASH AND ARCHIVE EMAILS. THE GMAIL MCP IS READ-ONLY AND CANNOT MODIFY EMAILS. WITHOUT CHROME, THIS SKILL CANNOT DO ITS JOB.**

**CLAUDE IN CHROME IS MANDATORY. IF CHROME TOOLS ARE NOT AVAILABLE, DO NOT FALL BACK TO A QUEUE. DO NOT SAVE PENDING ACTIONS. ABORT THE ENTIRE RUN AND LOG "ABORTED: Chrome not available" TO THE SESSION LOG. CLASSIFICATION WITHOUT EXECUTION IS POINTLESS.**

**CLAUDE IN CHROME IS MANDATORY. AT THE START OF EVERY RUN, CALL `mcp__claude-in-chrome__tabs_context_mcp()` FIRST. IF IT FAILS OR RETURNS AN ERROR, STOP IMMEDIATELY. DO NOT PROCEED TO CLASSIFY EMAILS. DO NOT WASTE CONTEXT ON CLASSIFICATION YOU CANNOT ACT ON.**

## Memory

Before processing, read the memory file for learned preferences:
`.claude/skills/gmail-unsubscribe/MEMORY.md`

After processing, update that file with any new decisions.

## Step 0: Verify Chrome Connection (MANDATORY)

**Before doing ANYTHING else, verify Claude in Chrome is connected:**

```
mcp__claude-in-chrome__tabs_context_mcp({ createIfEmpty: true })
```

**If this call fails or returns an error: ABORT THE ENTIRE RUN.** Log "ABORTED: Chrome not available" to the session log and stop. Do not classify emails. Do not read emails. Do not continue.

**If Chrome is connected:** Check if `.claude/skills/gmail-unsubscribe/pending-actions.json` exists. If it does:
1. Read the file
2. Execute each pending trash/archive action via Chrome (same procedure as Steps 4b/4c)
3. Delete the file after all actions are processed
4. Report how many pending actions were completed

## Session Log

Before processing, read the session log for history of past runs:
`.claude/skills/gmail-unsubscribe/SESSION-LOG.md`

After processing, append a new entry to the session log with:
- Session number and date/time
- Number of emails scanned
- Classifications breakdown (keep / low-priority / marketing / auto-trash)
- All actions taken (unsubscribe attempts, trash, archive) with timestamps
- Any errors encountered
- Chrome availability status

## Step 1: Search Unread Emails

**IMPORTANT: Only process emails from the last 48 hours. Use the Gmail search query `is:unread newer_than:2d` instead of just `is:unread`. Never process emails older than 48 hours.**

```
mcp__gmail__gmail_search_messages({ q: "is:unread newer_than:2d", maxResults: 100 })
```

If there are more results (nextPageToken returned), fetch additional pages until all unread emails are retrieved or 200 emails are reached.

### Deduplication

After fetching, read `.claude/skills/gmail-unsubscribe/classified-ids.json` if it exists. This file tracks email IDs that have already been classified in previous sessions. **Skip any email whose ID is already in this file** — only classify genuinely new emails.

After classification, update the file with all newly classified IDs:
```json
{
  "lastUpdated": "<ISO timestamp>",
  "ids": ["id1", "id2", ...]
}
```

Cap the file at 500 IDs. If it exceeds 500, keep only the most recent 500. This prevents the organizer from wasting context re-classifying the same emails when Chrome is unavailable.

**CRITICAL: Process emails in order from MOST RECENT to LEAST RECENT (newest first).** Gmail returns results newest-first by default — preserve that order throughout ALL steps. Never reorder, shuffle, or batch by category before processing. Read, classify, report, unsubscribe, and trash in strict newest-first order.

Record the `id` of every email classified as marketing, auto-trash, or low-priority — you will need these IDs in Step 4b/4c.

## Step 2: Classify Each Email

Read each email with `mcp__gmail__gmail_read_message` **in order from most recent to least recent** and classify it.

### Marketing Indicators (score-based, unsubscribe if score >= 4)

**Sender patterns (+2):**
- `no-reply@`, `noreply@`, `newsletter@`, `marketing@`, `promotions@`, `offers@`, `deals@`, `news@`, `updates@`

**Subject patterns (+2):**
- Sale/discount/deal/save/free/limited/exclusive/offer
- "X% off", last chance/don't miss/ending soon/hurry/act now
- Weekly/monthly/daily digest/update/newsletter
- New arrivals/just dropped/now available, flash sale/clearance

**List-Unsubscribe header present (+3)**

**Gmail Promotions category (+4):**
- Look for `CATEGORY_PROMOTIONS` in labels

**Sent via marketing platform (+3):**
- Check if sent through: mailchimp.com, sendgrid.net, amazonses.com, mailgun.org, constantcontact.com, hubspot.com, klaviyo.com, brevo.com, sendinblue.com, postmarkapp.com, mandrill.com, intercom-mail.com, customer.io, drip.com, convertkit.com, getresponse.com, mailjet.com

**Campaign tracking headers (+2):**
- Has `x-campaign`, `x-mc-user`, or similar

**Precedence: bulk/list (+2)**

**Body contains "unsubscribe" / "opt out" / "manage preferences" (+1)**

### NEVER Unsubscribe From (override - skip immediately)

- Receipts, invoices, order confirmations, shipping/delivery notifications
- Password resets, security alerts, verification, 2FA codes
- Appointments, reservations, booking confirmations
- Payment/transaction/statement alerts
- Welcome/account created emails
- GitHub/GitLab/Bitbucket/Jira notifications
- Google/Apple/Microsoft/Amazon account emails (including subdomains)
- Support tickets, case numbers
- Emails that are part of a conversation thread (have In-Reply-To or References headers)

### Auto-Trash (skip reading, just delete)

Some emails should be trashed immediately without reading or reporting. Classify these as **"auto-trash"** — they skip Steps 2–4a entirely and go straight to Step 4b (mark read + trash). Do NOT spend time reading their content.

- **Google Cloud Alerting** (`alerting-noreply@google.com`) — Firebase billing/usage alerts
- **Firebase** (`firebase-noreply@google.com`) — Crash reports and issue notifications

### Low Priority (mark read + archive)

Emails that are legitimate but don't need the user's attention. These get marked as read and archived (removed from inbox but not deleted).

**Classify as low-priority if the email is:**
- Account/service notifications (ToS updates, privacy policy changes, feature announcements)
- Workspace/team notices (Slack content deletion, workspace updates)
- Developer platform alerts (API deprecation notices, SDK updates, version upgrades)
- Financial account notices (privacy updates, policy changes — NOT transactions or security)
- Social/professional network notifications (LinkedIn connection updates, endorsements)
- App update announcements from services you use
- Non-actionable informational emails from known services

**Low-priority senders (from Memory):**
- Check MEMORY.md "Auto-Read + Archive" list

**Key distinction:** If the email requires user action (password expiring, payment due, security alert), it is NOT low-priority — classify as "keep".

### Memory Override

Check MEMORY.md first:
- If sender is in "Always Unsubscribe" list: auto-classify as marketing
- If sender is in "Auto-Trash" list: classify as auto-trash (skip reading, just trash)
- If sender is in "Auto-Read + Archive" list: classify as low-priority
- If sender is in "Never Unsubscribe" or "Trusted Senders" list: classify as keep (leave unread)
- If sender is in "Needs Review": ask user

## Step 3: Report Findings

Present a summary table **in newest-first order** (the same order you read them — do NOT re-sort by classification):

```
| # | Date | From | Subject | Classification | Action |
```

Classifications: **keep** (leave unread), **low-priority** (read+archive), **marketing** (unsubscribe+trash), **auto-trash** (skip+trash)

Include the date column so the user can verify the order is correct (most recent at the top).

For large batches (50+), present a condensed summary instead of listing every email:
- Count by classification
- List only "keep" emails (so user can verify nothing important was missed)
- List any new/unknown senders that need a decision

## Step 4a: Unsubscribe (with user approval)

For confirmed marketing emails, attempt unsubscribe using **List-Unsubscribe headers only**:

1. **One-Click (RFC 8058):** If `List-Unsubscribe-Post` contains "One-Click", POST to the HTTPS URL from `List-Unsubscribe` header with body `List-Unsubscribe=One-Click`
2. **HTTPS GET:** If List-Unsubscribe has an HTTPS URL, visit it with WebFetch
3. **Mailto:** If List-Unsubscribe has a `mailto:` URL, create a draft unsubscribe email using `gmail_create_draft`

**Do NOT:**
- Follow unsubscribe links from the email body (only use List-Unsubscribe header)
- Follow redirects to unknown domains

**Safety:**
- Only use HTTPS URLs (never HTTP)
- Max 10 unsubscribes per run
- When uncertain, ask the user

## Step 4b: Trash via Chrome (marketing + auto-trash)

**IMPORTANT: You MUST use Claude in Chrome (`mcp__claude-in-chrome__*` tools) for this step. The Gmail MCP is read-only. Do not skip this step.**

For every email classified as **marketing** or **auto-trash**: mark as read and trash.

### Procedure

1. **Get browser context:**
   ```
   mcp__claude-in-chrome__tabs_context_mcp()
   ```

2. **Open a tab for Gmail** (or reuse existing):
   ```
   mcp__claude-in-chrome__tabs_create_mcp({ url: "https://mail.google.com" })
   ```

3. **For each email message ID**, navigate directly to it:
   ```
   mcp__claude-in-chrome__navigate({ url: "https://mail.google.com/mail/u/0/#all/{messageId}" })
   ```

4. **Wait for the email to load** (wait 2 seconds), then:
   - **Mark as read:** press `Shift+i`
     ```
     mcp__claude-in-chrome__computer({ action: "key", text: "shift+i" })
     ```
   - **Trash (bin):** click the trash icon in the Gmail toolbar (approximately x=421, y=88). Do NOT use the `#` keyboard shortcut — it does not work when Gmail keyboard shortcuts are disabled.
     ```
     mcp__claude-in-chrome__computer({ action: "left_click", coordinate: [421, 88] })
     ```
   - **Wait** 1.5 seconds for Gmail to navigate back to the list before proceeding to the next email.

5. **Repeat** for every marketing and auto-trash email.

## Step 4c: Read + Archive via Chrome (low-priority)

For every email classified as **low-priority**: mark as read and archive (remove from inbox but keep in All Mail).

### Procedure

Use the same Gmail tab from Step 4b.

1. **Navigate to the email:**
   ```
   mcp__claude-in-chrome__navigate({ url: "https://mail.google.com/mail/u/0/#all/{messageId}" })
   ```

2. **Wait for the email to load** (wait 2 seconds), then:
   - **Mark as read:** press `Shift+i`
     ```
     mcp__claude-in-chrome__computer({ action: "key", text: "shift+i" })
     ```
   - **Archive:** click the archive icon in the Gmail toolbar (1st action icon, approximately x=301, y=88). If the position is wrong, take a screenshot to locate the archive button (box with down-arrow icon).
     ```
     mcp__claude-in-chrome__computer({ action: "left_click", coordinate: [301, 88] })
     ```
   - **Wait** 1.5 seconds for Gmail to navigate back to the list.

3. **Repeat** for every low-priority email.

### If Chrome Is Not Available

**ABORT THE ENTIRE RUN.** Do not classify. Do not save pending actions. Do not continue. Log "ABORTED: Chrome not available — cannot execute trash/archive actions" to the session log and stop.

### Rules for Steps 4b and 4c
- **Trash:** marketing + auto-trash emails
- **Read + Archive:** low-priority emails
- **Do NOT touch:** emails classified as "keep" — leave them unread in the inbox
- If Chrome tools fail mid-execution, save remaining actions to `pending-actions.json` for the next run

## Step 5: Update Memory

After processing, update `.claude/skills/gmail-unsubscribe/MEMORY.md`:
1. Add new sender preferences based on classifications and user decisions
2. Log decisions in the User Decisions Log
3. Update statistics
4. Note any new patterns learned

## Safety Rules

- When uncertain about classification, ASK the user
- Never permanently delete emails — only trash (Gmail keeps trashed emails for 30 days)
- Max 10 unsubscribe attempts per run
- Log all actions for review
