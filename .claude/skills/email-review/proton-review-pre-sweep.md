# Proton Mail Review — Pre-Sweep Baseline

**Date:** 2026-02-03 08:08 AEDT
**Window:** Last 48 hours (Feb 1-3)
**Purpose:** Baseline snapshot before scheduled email sweep at 08:14

---

## Overall Grade: D+

The Proton daemon is fundamentally broken. It only processes emails on startup — the IMAP IDLE loop never fires. As a result, 17 emails that the scanner correctly identifies as marketing or notification are sitting in the inbox unactioned.

---

## Daemon Activity (48 hours)

| Cycle | Timestamp | Emails Processed | Actions | Notes |
|-------|-----------|-----------------|---------|-------|
| 1 | Jan 31 22:10 | 10 | 3 trashed, 5 moved to Notifications, 2 archived | Working correctly on startup |
| 2 | Jan 31 23:05 | 0 | None | Restarted, processed 0, entered IDLE |
| 3 | Feb 1 23:27 | 8 | 1 trashed, 4 moved to Notifications, 3 archived | Manual restart by user |

**Total processed:** 18 emails in 48 hours
**IDLE gap:** 24+ hours between cycles 2 and 3 (Jan 31 23:05 → Feb 1 23:27) with zero processing

**Root cause:** The IMAP IDLE loop enters IDLE state but never wakes up on new mail. Proton Bridge may not properly support IMAP IDLE push notifications. The daemon only processes emails at startup, then sits idle forever.

---

## Current Inbox Snapshot (45 emails)

### Marketing — 8 emails (SHOULD BE TRASHED, still in inbox)

| # | From | Subject |
|---|------|---------|
| 1 | IdeaMiner `<hello@ideaminer.io>` | IdeaMiner Daily - Feb 02 |
| 2 | Chloe Tse `<letschat@partnerstack.com>` | What top B2B brands did to reach $2.7B GMV |
| 3 | Wise `<noreply@info.wise.com>` | Ready to earn a return? |
| 4 | Deep Teaching Solutions `<no-reply@m.mail.coursera.org>` | Cheery Friday Greetings from Barb Oakley! |
| 5 | Amplitude `<noreply@amplitude.com>` | [Amplitude] Train Effective Ltd weekly data health summary |
| 6 | Temu `<email@market.temuemail.com>` | Your package is arriving soon! |
| 7 | Temu `<email@market.temuemail.com>` | Please confirm your Free Items |
| 8 | St.George `<email@e.stgeorge.com.au>` | Fresh Cashback picks are waiting, Paul. |

**Scanner correctly identified all 8 as marketing.** The daemon never processed them because IDLE didn't fire.

### Notification — 9 emails (SHOULD BE IN Notifications FOLDER, still in inbox)

| # | From | Subject |
|---|------|---------|
| 1 | Google Cloud Alerting `<alerting-noreply@google.com>` | Firebase billing alert (x5 emails) |
| 2 | LinkedIn Messaging `<messages-noreply@linkedin.com>` | Messages from Dr. Theoni and 6 others are waiting |
| 3 | Slack `<feedback@slack.com>` | Train Effective updates for the week of January 25th |
| 4 | Firebase `<firebase-noreply@google.com>` | Trending stability issues - Android com.traineffective |
| 5 | Firebase App Distribution `<firebase-noreply@google.com>` | Train Effective 3.2.481 for Android is ready to test |

**Scanner correctly identified all 9 as notification.** Same root cause — daemon IDLE not triggering.

### Kept — 28 emails (left in inbox as intended)

**Job application confirmations (correctly kept):**
- SEEK Applications (x6) — application submitted confirmations
- Indeed Apply (x3) — application confirmations
- WeAreShovels.com, Mission, Pathify, Workable, Canva, Bookipi — application acknowledgements
- SEEK Pass — access code (security, correctly kept)

**Job match suggestions (correctly kept — user is job hunting):**
- Indeed match emails (x6) — job suggestions from Indeed

**Work/dev (correctly kept):**
- App Store Connect — build issue alert
- TestFlight — new build available to test
- Otter.ai (x2) — meeting summaries from Weekly Kick-Off
- Mission Events Team — job application journey update

**All 28 "kept" emails are correctly classified.** No misclassifications found in the kept category.

---

## Daemon Log Misclassifications (from processed emails)

### Cycle 1 (Jan 31 22:10)
- **G2A.COM `<info@g2a.com>` classified as "keep"** — G2A is a gaming marketplace. This is likely marketing. Should be in Always Unsubscribe list. (Note: `no-reply@g2a.com` was processed as "keep" in Cycle 3 too — the daemon has both `info@` and `no-reply@` addresses.)
- **Luxury Escapes `<email@m.luxuryescapes.com>` classified as "keep"** — This is a travel deals company. Should be marketing/trash.
- **Westpac Statement Notification `<tbstatementnotification@email7.westpac.com.au>` moved to Notifications** — Bank statement notifications are important. Should be "keep" in inbox.

### Cycle 3 (Feb 1 23:27)
- **G2A.COM `<no-reply@g2a.com>` classified as "keep"** — Repeat misclassification. G2A should be marketing.
- **Luke Allan `<lukeallan@mcgrath.propertyemail.com.au>` classified as "keep"** — Real estate agent email. Likely marketing unless actively house-hunting.
- **Lily Yu `<lily@uplusrealty.com.au>` classified as "keep"** — Same — real estate, likely marketing.

---

## Scanner --mailbox Bug

The `--mailbox` flag on `proton-scan.js` is broken. Running:
- `proton-scan.js scan --mailbox Trash`
- `proton-scan.js scan --mailbox "Folders/Notifications"`

Both return the **exact same 45 emails as the inbox scan**. Cannot verify Trash or Notifications folder contents. This bug has persisted across multiple reviews.

---

## Memory Health

MEMORY.md loaded: 65 marketing, 18 never-unsubscribe, 20 notification senders.

**Already in MEMORY.md (correctly covered):**
- `partnerstack.com` — marketing (added 2026-02-03)
- `email@e.stgeorge.com.au` — marketing (added 2026-02-02)
- `info@g2a.com` — marketing (added 2026-02-01)
- `email@m.luxuryescapes.com` — marketing (added 2026-02-01)
- `lukeallan@mcgrath.propertyemail.com.au` — Never Unsubscribe (user actively house-hunting)
- `lily@uplusrealty.com.au` — Never Unsubscribe (user actively house-hunting)
- `tbstatementnotification@email7.westpac.com.au` — Never Unsubscribe (bank statements)

**Missing from MEMORY.md (FIXED — added during this review):**
- `no-reply@g2a.com` — marketing (daemon classified as "keep" in Cycle 3; `info@` was listed but `no-reply@` variant was not)
- `no-reply@m.mail.coursera.org` — marketing (Coursera newsletters via Deep Teaching Solutions)
- `noreply@amplitude.com` — marketing (weekly product data digest)

---

## Summary of Issues

| Issue | Severity | Status |
|-------|----------|--------|
| IDLE loop never fires — daemon only processes on startup | CRITICAL | Unfixed (code bug in proton-client.ts) |
| 17 emails in inbox that should be trashed/moved | HIGH | Will be addressed by next daemon restart or Proton organizer run |
| 6 senders missing from MEMORY.md | MEDIUM | Needs MEMORY.md update |
| G2A, Luxury Escapes, real estate agents misclassified as "keep" | MEDIUM | Needs MEMORY.md update |
| Westpac statement notification moved to Notifications instead of kept | LOW | Needs MEMORY.md never-unsub entry |
| `--mailbox` scanner flag broken | LOW | Known bug, no fix applied |

---

## Recommendations

1. **Fix the IDLE loop** in `assistant/src/proton-client.ts` — either fix the IMAP IDLE implementation or add a polling fallback (check every 5-10 minutes)
2. **Update MEMORY.md** with the 6 missing marketing senders and Westpac as never-unsubscribe
3. **Restart the daemon** after MEMORY.md updates so it processes the 17 backlogged emails
4. **Fix the --mailbox flag** in proton-scan.js so reviews can audit Trash and Notifications folders

---

*This file is a pre-sweep baseline. Compare against post-sweep results after the 08:14 scheduled run.*
