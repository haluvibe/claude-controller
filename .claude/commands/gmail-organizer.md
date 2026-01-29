---
description: "Scan inbox for marketing emails, report findings, and optionally unsubscribe via List-Unsubscribe headers"
allowed-tools: mcp__gmail__gmail_search_messages, mcp__gmail__gmail_read_message, mcp__gmail__gmail_read_thread, mcp__gmail__gmail_create_draft, mcp__gmail__gmail_list_drafts, mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__tabs_create_mcp, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__read_page, mcp__claude-in-chrome__find, mcp__claude-in-chrome__computer, mcp__claude-in-chrome__javascript_tool, mcp__claude-in-chrome__get_page_text, Read, Edit, WebFetch
---

# Gmail Organizer

Scan unread emails, classify marketing vs. important, and handle unsubscribes using Gmail MCP tools. After successful unsubscribe, mark emails as read and trash them via Chrome.

## Memory

Before processing, read the memory file for learned preferences:
`.claude/skills/gmail-unsubscribe/MEMORY.md`

After processing, update that file with any new decisions.

## Step 1: Search Unread Emails

```
mcp__gmail__gmail_search_messages({ q: "is:unread", maxResults: 30 })
```

Process most recent first. Record the `id` of every email classified as marketing — you will need these IDs in Step 4b.

## Step 2: Classify Each Email

Read each email with `mcp__gmail__gmail_read_message` and classify it.

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

### Memory Override

Check MEMORY.md first:
- If sender is in "Always Unsubscribe" list: auto-classify as marketing
- If sender is in "Never Unsubscribe" or "Trusted Senders" list: skip
- If sender is in "Needs Review": ask user

## Step 3: Report Findings

Present a summary table:

```
| # | From | Subject | Classification | Confidence | Action |
```

Group by:
1. Marketing (high confidence) - will unsubscribe
2. Marketing (uncertain) - ask user
3. Important/kept - no action

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

## Step 4b: Mark as Read and Trash via Claude in Chrome

**IMPORTANT: You MUST use Claude in Chrome (`mcp__claude-in-chrome__*` tools) for this step. There is no other way to modify emails — the Gmail MCP is read-only. Do not skip this step.**

For every email where unsubscribe was attempted (confirmed or partial), use Claude in Chrome to open it in the Gmail web UI, mark it as read, and move it to the bin (trash).

### Procedure

1. **Get browser context:**
   ```
   mcp__claude-in-chrome__tabs_context_mcp()
   ```

2. **Open a tab for Gmail:**
   ```
   mcp__claude-in-chrome__tabs_create_mcp({ url: "https://mail.google.com" })
   ```

3. **For each marketing email message ID**, navigate directly to it:
   ```
   mcp__claude-in-chrome__navigate({ url: "https://mail.google.com/mail/u/0/#all/{messageId}" })
   ```

4. **Wait for the email to load**, then use Gmail keyboard shortcuts:
   - **Mark as read:** press `Shift+i`
   - **Trash (bin):** press `#`
   ```
   mcp__claude-in-chrome__computer({ action: "key", text: "shift+i" })
   mcp__claude-in-chrome__computer({ action: "key", text: "#" })
   ```

5. **Repeat** for every marketing email that was processed in Step 4a.

### Rules
- Only trash emails where unsubscribe was attempted (confirmed or partial)
- Do NOT trash emails classified as "keep" or "uncertain"
- If Chrome is not available or the browser tools fail, report which message IDs still need manual cleanup

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
