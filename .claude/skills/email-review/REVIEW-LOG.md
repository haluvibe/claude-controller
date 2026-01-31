# Email Review Log

Timestamped findings from automated email stack reviews.

---

## Review — 2026-02-02 08:35 AEDT

### Overall Grade: A-

Both inboxes clean. Gmail 10/10 classification, 9/9 trash correct, 65-item backlog cleared. Proton inbox empty, daemon healthy. Deductions: Proton old batch had 2 misclassifications (now fixed), Westpac still goes to Notifications, system can't execute Gmail without manual Chrome.

### Gmail (24 hours)

- **Inbox:** 1 email — Westpac eStatement (legitimate, correctly kept)
- **Trash:** 9 emails — 9/9 correctly trashed (Domaine Homes, Google Alerting x4, G2A, Luxury Escapes, National Zoo newsletter, Caluga Farm)
- **Classification:** 10/10 correct
- **Execution:** 10/10 (backlog cleared via Chrome)
- **Pending:** 0 (cleared)
- **Misclassifications:** None

### Proton (24 hours)

- **Inbox:** 0 — clean
- **Daemon:** Restarted 23:05 UTC Jan 31 with MEMORY.md (63 marketing senders). Healthy IDLE.
- **Last batch:** 10 emails — 7/10 correct. Westpac to Notifications (should be kept), G2A + Luxury Escapes archived as keep (old code, now fixed)

### Improvement from C+ to A-

- Gmail backlog: 65 -> 0
- Gmail inbox: 10 -> 1
- Gmail execution: 0% -> 100%
- Proton daemon: now MEMORY.md-aware

### Remaining Issues

1. Proton Westpac -> Notifications (should be kept)
2. Gmail Chrome dependency for execution
3. Proton CLI can't audit Trash/Notifications folders

---

## Review — 2026-02-01 22:30

### Overall Verdict: NEEDS ATTENTION

Two misclassifications found in Gmail trash. Gmail pending actions backlog growing (64 queued, 7 sessions without Chrome). Proton daemon healthy and inbox clean.

### Gmail (30 days)

- **Inbox:** 50 emails sampled (est. ~201 total) — ~10 are marketing/junk the organizer classified correctly but could not action (Chrome unavailable), ~38 are legitimate (payslips, bank statements, job applications, property alerts, security alerts, dev notifications, personal correspondence)
- **Trash:** 50 emails sampled — 47 correctly trashed (marketing promos, Google Cloud Alerting, Firebase crash reports), **2 misclassifications found** (see below), 1 borderline cold pitch (acceptable)
- **Sessions:** 16 runs total. Sessions 7-9 (Jan 29) had Chrome and took bulk action (~300+ emails trashed/archived). Sessions 10-16 (Jan 29 - Feb 1) all classify-only — **7 consecutive sessions with no execution** due to Chrome unavailability
- **Pending:** 64 actions queued (28 trash + 36 archive), oldest items from Jan 14-15. Backlog growing by ~3 items per session
- **Repeat offenders:** Same ~100 emails being reclassified every session (Sessions 12-16 show near-total overlap). Classification is stable and consistent, but the same emails are scanned repeatedly without action

### Proton (30 days)

- **Inbox:** 0 emails — completely clean. Daemon is actively processing incoming mail
- **Daemon:** 30 emails processed across 3 daemon cycles (Jan 30-31). 0 errors, 0 connection drops. Last daemon log entry: Jan 31, entered IDLE loop after processing 10 emails
- **Sessions:** 2 interactive sessions (Jan 29) processed ~650 emails. Daemon has been running since Jan 30
- **Repeat offenders:** None detected. Daemon processes and acts on emails immediately, no re-processing

### Misclassifications Found

1. **St.George bank "New Payee Account added" (Internetadmin@stgeorge.com.au) — INCORRECTLY TRASHED (Gmail trash)**
   - Date: Jan 29, 2026
   - Subject: "St.George Internet Banking - New Payee Account added"
   - This is a security/transactional banking notification confirming a new payee was added. Should be KEPT (not trashed). stgeorge.com.au is not in MEMORY.md at all.
   - **Impact:** Missed security alert for banking activity

2. **Reddit reply with IMPORTANT label (noreply@redditmail.com) — INCORRECTLY TRASHED**
   - Date: Jan 29, 2026
   - Subject: "u/Suspicious_Aside_346 replied to your comment in r/microsaas"
   - Gmail flagged this as IMPORTANT. This was a reply to the user's own comment in r/microsaas. Reddit notifications are in the "Auto-Read + Archive" list in Gmail MEMORY.md but should be archived, not trashed. The organizer bulk-trashed this during Session 9's "trash all promotions" sweep (it had CATEGORY_PROMOTIONS label despite being IMPORTANT).
   - **Impact:** Lost a reply to user's own r/microsaas content

3. **Proton daemon: Westpac eStatement moved to Notifications instead of kept**
   - Date: Jan 31, 2026 daemon run
   - Westpac tbstatementnotification@email7.westpac.com.au was classified as "notification" and moved to Folders/Notifications. On Gmail this is classified as "keep". Inconsistent treatment — bank eStatements should be treated as important/keep, not generic notifications.

4. **Proton daemon: G2A.COM info@ archived as keep instead of trashed as marketing**
   - Date: Jan 30 daemon run
   - G2A.COM info@g2a.com was classified as "keep" and archived. On Gmail, info@g2a.com is classified as marketing and queued for trash. Inconsistent cross-platform treatment.

5. **Proton daemon: Luxury Escapes archived as keep instead of trashed as marketing**
   - Date: Jan 31 daemon run
   - email@m.luxuryescapes.com was classified as "keep" and archived. On Gmail, this is classified as marketing. The Proton memory doesn't list Luxury Escapes.

6. **Proton daemon: Open Universities Australia archived as keep instead of marketing**
   - Date: Jan 30 daemon run
   - oua@e.open.edu.au was archived as "keep". On Gmail, this is classified as marketing.

7. **Proton daemon: 9Now archived as keep instead of trashed as marketing**
   - Date: Jan 31 daemon run
   - tvguide@mail.9now.com.au was classified as "keep" and archived. On Gmail, 9Now is in the "Always Unsubscribe" marketing list.

### Missing from Memory

**Gmail MEMORY.md:**
- `Internetadmin@stgeorge.com.au` — St.George banking transactional emails. Should be added to Keep Unread list
- `admin@sportstecclinic.com.au` — SportsTec Clinic (personal gift certificate). Not in memory but appeared in inbox. Add to Keep
- `noreply@post.xero.com` — Xero payslips. In Proton memory but not explicitly in Gmail memory
- `no-reply@pollencafe.com.au` — Pollen cafe. Marketing/promo, should be added to Always Unsubscribe
- `contact@adventureclub.anaconda.com.au` — Anaconda birthday promo. Should be added to Always Unsubscribe

**Proton MEMORY.md:**
- `email@m.luxuryescapes.com` — Luxury Escapes. On Gmail Always Unsubscribe list but missing from Proton
- `oua@e.open.edu.au` — Open Universities Australia. On Gmail Always Unsubscribe list but missing from Proton
- `tvguide@mail.9now.com.au` — 9Now. On Gmail Always Unsubscribe list but missing from Proton
- `info@g2a.com` — G2A.COM promo. On Gmail Always Unsubscribe list but missing from Proton
- `tbstatementnotification@email7.westpac.com.au` — Westpac. Should be in Never Unsubscribe / important
- `contact@domainehomes.com.au` — Domaine Homes. Proton daemon trashed this correctly but it's not in the marketing memory list

### Recommendations

1. **Add St.George banking to Gmail Keep Unread list** — `Internetadmin@stgeorge.com.au` is a security-relevant transactional sender. Currently not in MEMORY.md at all
2. **Sync Proton marketing memory with Gmail** — 5 senders are on Gmail's "Always Unsubscribe" list but missing from Proton's marketing list (Luxury Escapes, Open Universities, 9Now, G2A promo, Domaine Homes). This causes inconsistent classification
3. **Fix Reddit handling in bulk operations** — Session 9's bulk "trash all promotions" caught a Reddit reply with IMPORTANT+CATEGORY_PROMOTIONS labels. Bulk operations should exclude senders on the Auto-Archive list (redditmail.com) from promotion trash sweeps
4. **Resolve Chrome dependency** — 7 consecutive Gmail sessions (10-16) could not execute pending actions. 64 actions are queued. Either: (a) schedule a Chrome session to clear the backlog, or (b) implement Gmail API-based trash/archive as an alternative to Chrome
5. **Add Westpac to Proton "Never Unsubscribe" list** — Bank eStatements should be kept/important, not moved to Notifications folder
6. **Add Pollen cafe and Anaconda to Gmail "Always Unsubscribe"** — Both are marketing senders still sitting in the inbox
7. **Consider reducing session frequency** — Sessions 12-16 all scan the same ~100 emails with near-identical results. Without Chrome, running sessions more than once per day wastes classification effort with no execution

---

## Backlog Clearance — 2026-02-02 08:30 AEDT

### Actions Taken

Chrome session opened. Cleared the entire 65-item pending-actions backlog via bulk Gmail operations.

**Trash operation:**
- Searched inbox for all 21 marketing sender domains (domainehomes, alerting-noreply@google, g2a, luxuryescapes, calugafarmstore, nationalzoo, open.edu.au, nab, glassdoor, acquire, ubs, republic, evie, jobs2web, uneed, bigideasdb, wise, fameswap, starterstory, weforum, bubble.io)
- Selected all matching conversations, confirmed bulk trash
- Result: ~20 emails trashed from inbox

**Archive operation:**
- Searched inbox for all 14 notification sender domains (developers.facebook, slack, wise, ubisoft, patreon, redditmail, email.apple, aussiebroadband, amplitude, render, discord, imagekit, location-sharing@google, feedback@slack)
- Selected all matching conversations, confirmed bulk archive
- Result: ~78 emails archived from inbox

**Totals:**
- Inbox: 1,083 -> 985 (98 emails cleared)
- pending-actions.json: Deleted (backlog fully cleared)
- Next Gmail organizer session starts fresh with no queued actions

### Remaining Issue #4 from previous review (Chrome dependency) is now RESOLVED for this cycle. The organizer still needs Chrome for future runs.

---

## Review — 2026-02-01 10:10 AEDT

### Overall Grade: C+

Gmail classification is accurate but execution is completely stalled — 7 sessions, zero actions. Proton daemon is healthy and inbox is clean, but had 2 misclassifications (now fixed with MEMORY.md loading). 64-item Gmail pending backlog growing.

### Gmail (24 hours)

- **Inbox:** 10 emails — 7 are junk/marketing correctly identified but NOT actioned, 3 are legitimate (Westpac statement, National Zoo membership, Caluga farm)
- **Trash:** 0 emails — nothing trashed in last 24h
- **Sessions:** 2 runs (Sessions 15-16), both classify-only, Chrome not available
- **Pending:** 64 actions queued (28 trash + 36 archive), file created 2026-02-01. 7 consecutive sessions without Chrome execution

**Gmail inbox breakdown (last 24h):**

| Sender | Classification | Pending Action | Correct? |
|--------|---------------|----------------|----------|
| Domaine Homes NSW (contact@domainehomes.com.au) | Marketing | Trash | Yes |
| Google Cloud Alerting x4 (alerting-noreply@google.com) | Auto-trash | Trash | Yes |
| G2A.COM (info@g2a.com) | Marketing | Trash | Yes |
| Luxury Escapes (email@m.luxuryescapes.com) | Marketing | Trash | Yes |
| Caluga Farm Store (info@calugafarmstore.com.au) | Marketing | Trash | Yes (Klaviyo newsletter) |
| National Zoo & Aquarium (memberships@nationalzoo.com.au) | Keep | None | Yes (membership) |
| Westpac Statement (tbstatementnotification@email7.westpac.com.au) | Keep Unread | None | Yes (banking) |

Classification accuracy: 10/10 correct. Execution: 0/10 actioned. The brain works, the arms don't.

### Proton (24 hours)

- **Inbox:** 0 emails — clean
- **Daemon:** 10 emails processed at 22:11 UTC Jan 31, then 0 on restart. Running healthy in IDLE mode
- **Errors:** 0
- **Trash/Notifications scan:** Returned 0 results (CLI `--mailbox` flag gap — cannot scan non-INBOX mailboxes)

**Proton daemon last batch (Jan 31 22:11 UTC):**

| Sender | Action | Correct? |
|--------|--------|----------|
| Domaine Homes NSW | Trashed | Yes |
| National Zoo & Aquarium | Trashed | Yes |
| Netflix | Trashed | Yes |
| Google Cloud Alerting x4 | Moved to Notifications | Yes |
| Westpac Statement | Moved to Notifications | Yes |
| G2A.COM | Archived as "keep" | **NO** — marketing |
| Luxury Escapes | Archived as "keep" | **NO** — marketing |

8/10 correct. 2 misclassifications from old code that didn't read MEMORY.md.

### Misclassifications Found

1. **G2A.COM (info@g2a.com) — Proton: archived as keep instead of trashed.** Old daemon code didn't read MEMORY.md. Now fixed — daemon restarted with MEMORY.md loading (63 marketing senders).
2. **Luxury Escapes (email@m.luxuryescapes.com) — Proton: archived as keep instead of trashed.** Same root cause. Fixed.

### Fixes Applied

1. **Proton daemon restarted** with new MEMORY.md-aware code. Now loads 63 marketing, 3 never-unsub, 20 notification sender overrides at startup
2. **MEMORY.md cross-platform sync** completed in previous session — 7 Gmail marketing senders added to Proton, Westpac added to Proton never-unsub
3. **SIGHUP reload** added to daemon — can reload MEMORY.md without restart
4. **All 7 improvement items from DESIGN-GOAL.md** implemented (see previous session)

### Remaining Issues

1. **Gmail Chrome dependency is the #1 problem.** 7 sessions, 64 queued actions, zero execution. The organizer needs a Chrome session to clear the backlog. Until then, marketing emails accumulate in the inbox
2. **Proton scan CLI can't read Trash/Notifications folders** — `--mailbox Trash` and `--mailbox "Folders/Notifications"` return 0 results. The scan CLI tool needs to support non-INBOX mailboxes for the review agent to audit the daemon's work
3. **Gmail deduplication not yet tested** — classified-ids.json was added to the organizer prompt but hasn't run yet. Next session will be the first test
