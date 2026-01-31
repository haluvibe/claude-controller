# Email Review Log

Timestamped findings from automated email stack reviews.

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
