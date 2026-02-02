# Email Review Log

Timestamped findings from automated email stack reviews.

---

## Review — 2026-02-04 01:45 AEDT

### Overall Grade: B

Gmail organizer running well — 12 sessions in 48h, Chrome available for 7 consecutive sessions (S22-S28), dedup working, no pending backlog, classification mostly accurate. One repeat misclassification (Mission Events job app trashed again — 4th consecutive review, code-level bug). Proton daemon idle >48h since 2026-02-01T23:27Z. Proton scanner Trash returned 1 result this time (partial improvement) but Notifications still returns 0.

### Gmail (48 hours)
- Inbox: 18 emails — 0 missed junk, 18 legitimate (2x Otter.ai work notes, 1x WeAreShovels job app, 1x Mission welcome, 1x Resolve Recruit job app, 6x SEEK Applications, 1x Workable job app, 2x Indeed job matches, 1x Google Cloud Alerting, 1x G2A rating reminder, 1x McGrath real estate, 1x Uplus real estate)
- Trash: 17 emails checked — 16 correctly trashed (7x Google Cloud Alerting, 1x PartnerStack, 1x Coursera/Deep Teaching, 1x Wise, 1x Firebase App Distribution, 1x Firebase crash, 2x Temu, 1x St.George cashback, 1x VisualCV), **1 mistake** (Mission Events job app)
- Sessions: 12 runs (S17-S28), 7 consecutive with Chrome (S22-S28), dedup working (1-3 new emails per session)
- Pending: 0 actions queued — no backlog
- classified-ids.json: 37 entries — healthy (cap: 500)

### Proton (48 hours)
- Inbox: 10 emails scanned — 2 marketing, 0 notification, 8 kept (all classifications correct via MEMORY.md overrides)
- Trash: 1 email checked (St.George marketing) — correctly trashed
- Notifications: 0 emails returned (scanner still can't read this folder)
- Daemon: Last active 2026-02-01T23:27Z, processed 8 on restart (1 trashed VisualCV, 4 moved to notifications, 3 kept), entered IDLE. **Idle >48 hours.** Not processing new arrivals.
- Errors: 0

### Misclassifications Found
1. **Mission Events Team** (events@e.mission.dev) — "Your journey to Senior Frontend Engineer (React and Typescript) at Travel Solutions has begun!", 2026-02-02 03:59 UTC, Gmail trash — job application email incorrectly trashed. **4th consecutive review** flagging this. Sender IS in MEMORY.md Keep list (added 2026-02-02) but organizer still trashes it — unsubscribe link in email body triggers false-positive marketing classification that overrides Keep memory match. Requires code fix to prioritize MEMORY.md Keep rules over body-based marketing detection.

### Fixes Applied
1. Cross-platform sync verified: no new senders needed syncing — marketing and keep lists already aligned from previous review.
2. No MEMORY.md contradictions found on either platform.
3. No stale pending actions (file doesn't exist).
4. classified-ids.json healthy at 37 entries (under 500 cap).

### Remaining Issues
1. **Mission Events (events@e.mission.dev) repeat trashing** — 4th consecutive review. Sender is in Gmail Keep list since 2026-02-02 but organizer still trashes it. Root cause: unsubscribe link in email body triggers false-positive marketing classification override. Needs a code fix to prioritize MEMORY.md Keep rules over body-based marketing detection.
2. **Proton daemon idle >48h** — Bridge IMAP IDLE not triggering on new mail. Needs manual restart.
3. **Proton scanner --mailbox flag** — Trash now returns 1 result (partial improvement from 0 in prior reviews). Notifications still returns 0.

---

## Review — 2026-02-04 00:30 AEDT

### Overall Grade: B

Gmail organizer running well — 12 sessions in 48h, Chrome available for 7 consecutive sessions (S22-S28), dedup working, no pending backlog, classification mostly accurate. One repeat misclassification (Mission Events job app trashed again despite being in Keep list). Proton daemon idle since Feb 2 with 45 emails unprocessed. One cross-platform contradiction fixed (G2A no-reply@). One "Needs Review" sender resolved (Coursera).

### Gmail (48 hours)
- Inbox: 18 emails — 0 missed junk, 18 legitimate (2x Otter.ai work notes, 1x WeAreShovels job app, 1x Mission welcome, 1x Resolve Recruit job app, 6x SEEK Applications, 1x Workable job app, 2x Indeed job matches, 1x Google Cloud Alerting, 1x G2A rating reminder, 1x McGrath real estate, 1x Uplus real estate, 1x Mathspace job app)
- Trash: 17 emails checked — 16 correctly trashed (7x Google Cloud Alerting, 1x PartnerStack, 1x Coursera/Deep Teaching, 1x Wise, 1x Firebase App Distribution, 1x Firebase crash, 2x Temu, 1x St.George cashback, 1x VisualCV), **1 mistake** (Mission Events job app)
- Sessions: 12 runs (S17-S28), 7 consecutive with Chrome (S22-S28), dedup working (1-3 new emails per session)
- Pending: 0 actions queued — no backlog
- classified-ids.json: 37 entries — healthy (cap: 500)

### Proton (48 hours)
- Inbox: 45 emails scanned — 8 marketing, 9 notification, 28 kept
- Trash: Cannot audit (scanner --mailbox flag bug, known issue)
- Notifications: Cannot audit (same bug)
- Daemon: Last active 2026-02-01T23:27Z, processed 8 on restart, entered IDLE. **Idle >48 hours.** 45 emails sitting unprocessed.
- Errors: 0

### Misclassifications Found
1. **Mission Events Team** (events@e.mission.dev) — "Your journey to Senior Frontend Engineer (React and Typescript) at Travel Solutions has begun!", 2026-02-02 03:59 UTC, Gmail trash — job application email incorrectly trashed. **Repeat** of same issue from 2026-02-02 20:30 and 2026-02-03 21:00 reviews. Sender IS in MEMORY.md Keep list but organizer still trashes it — unsubscribe link in email body triggers false-positive marketing classification that overrides Keep memory match. Requires code fix.

### Fixes Applied
1. Proton MEMORY.md: Removed G2A.COM no-reply@g2a.com from Always Unsubscribe (was contradicting Gmail's correct classification as transactional). Added to Never Unsubscribe.
2. Gmail MEMORY.md: Moved Deep Teaching Solutions / Coursera (m.mail.coursera.org) from Needs Review to Always Unsubscribe (recurring weekly newsletter, resolved as marketing).
3. Cross-platform sync: Verified — no additional senders needed syncing beyond the G2A fix. Marketing and keep lists aligned.

### Remaining Issues
1. **Mission Events (events@e.mission.dev) repeat trashing** — 3rd consecutive review flagging this. Sender is in Gmail Keep list since 2026-02-02 but organizer still trashes it. Root cause: unsubscribe link in email body triggers false-positive marketing classification override. Needs a code fix to prioritize MEMORY.md Keep rules over body-based marketing detection.
2. **Proton daemon idle >48h** — Bridge IMAP IDLE not triggering on new mail. 45 emails sitting unprocessed. Needs manual restart.
3. **Proton scanner --mailbox flag** — Still can't audit Trash/Notifications folders (known bug, unresolved across all reviews).

---

## Review — 2026-02-03 21:00 AEDT

### Overall Grade: B+

Gmail organizer running well -- Session 26 completed with Chrome, 1 archive action executed, classification accurate. Two issues: 1 repeat misclassification (Mission Events job app trashed again), 3 Google Cloud Alerting auto-trash emails sitting in inbox unactioned, and 1 new marketing sender (PartnerStack) missed. Proton daemon idle >48 hours, 44 emails unprocessed in inbox. Proton scanner misclassified Otter.ai as marketing.

### Gmail (24 hours)
- Inbox: 19 emails -- 3 missed auto-trash (Google Cloud Alerting), 1 missed marketing (PartnerStack), 1 needs-review (Coursera newsletter), 14 legitimate (2 Otter.ai work, 1 Workable job app, 5 SEEK apps, 2 Indeed matches, 1 Mission Welcome, 1 WeAreShovels app, 1 Resolve Recruit app, 1 SEEK Change Recruitment)
- Trash: 9 emails checked -- 8 correctly trashed (2x GCloud Alerting, 1x Wise marketing, 1x Firebase App Dist, 2x Temu, 1x Firebase crash, 1x St.George marketing), **1 mistake** (Mission Events job app)
- Sessions: 1 run (Session 26), Chrome available (5th consecutive), 1 archive executed (Slack weekly)
- Pending: 0 actions queued -- no backlog
- classified-ids.json: 33 entries -- healthy (cap: 500)

### Proton (24 hours)
- Inbox: 44 emails scanned by CLI -- 10 marketing, 8 notification, 26 kept
- Daemon: Last active 2026-02-01T23:27Z, processed 8 on restart, entered IDLE. **Idle >48 hours.** 44 emails sitting unprocessed.
- Daemon last batch: 8 emails processed correctly (4 notifications moved, 1 marketing trashed, 3 kept/archived)
- Proton scanner: Otter.ai (no-reply@otter.ai) misclassified as marketing (no-reply@ pattern + unsubscribe link triggered false positive). Should be "keep" (work meeting notes).
- Errors: 0

### Misclassifications Found
1. **Mission Events Team** (events@e.mission.dev) -- "Your journey to Senior Frontend Engineer (React and Typescript) at Travel Solutions has begun!", 2026-02-02 03:59 UTC, Gmail trash -- job application email incorrectly trashed. This is a **repeat** of the same misclassification found in the 2026-02-02 20:30 review. Sender IS in MEMORY.md Keep list (added 2026-02-02) but organizer still trashing it. The unsubscribe link in the email body triggers a false positive classification override.
2. **Proton: Otter.ai** (no-reply@otter.ai) -- "Meeting Summary for Weekly Kick-Off", 2026-02-02 12:04 UTC -- classified as marketing by Proton scanner (0.6 confidence, no-reply@ sender pattern + unsubscribe language). Should be "keep" (work meeting notes shared by colleague).
3. **Gmail: PartnerStack** (letschat@partnerstack.com) -- "What top B2B brands did to reach $2.7B GMV", 2026-02-02 18:08 UTC -- new marketing sender sitting in inbox unactioned, not in MEMORY.md.
4. **Gmail: 3x Google Cloud Alerting** (alerting-noreply@google.com) -- auto-trash list match but still sitting in inbox unactioned (arrived after Session 26 ran).

### Fixes Applied
1. Gmail MEMORY.md: Added PartnerStack (partnerstack.com) to Always Unsubscribe + Marketing Senders
2. Gmail MEMORY.md: Added Deep Teaching Solutions / Coursera (m.mail.coursera.org) to Needs Review
3. Proton MEMORY.md: Added Otter.ai (no-reply@otter.ai) to Never Unsubscribe (work meeting notes)
4. Proton MEMORY.md: Added SEEK Pass (no-reply@seekpass.co) to Never Unsubscribe (2FA codes)
5. Proton MEMORY.md: Added PartnerStack (partnerstack.com) to Always Unsubscribe + Marketing Senders
6. Cross-platform sync: 3 senders Gmail->Proton (Otter.ai, SEEK Pass, PartnerStack)
7. Updated both MEMORY.md timestamps to 2026-02-03

### Remaining Issues
1. **Mission Events (events@e.mission.dev) repeat trashing** -- Sender is in Gmail Keep list since 2026-02-02 but organizer still trashes it. Root cause: the unsubscribe link in email body triggers false-positive marketing classification that overrides the Keep memory match. Needs a code fix to prioritize MEMORY.md Keep rules over body-based marketing detection.
2. **Proton daemon idle >48h** -- Bridge IMAP IDLE not triggering on new mail. 44 emails sitting unprocessed. Needs manual restart.
3. **Proton scanner no-reply@ false positives** -- no-reply@otter.ai classified as marketing despite being work content. Scanner doesn't check Never Unsubscribe list for no-reply@ pattern exemptions.
4. **Coursera/Deep Teaching Solutions** -- New recurring newsletter sender (no-reply@m.mail.coursera.org). Added to Needs Review for user decision. "Cheery Friday Greetings from Barb Oakley!" educational content.

---

## Review — 2026-02-02 20:30 AEDT

### Overall Grade: B+

**Summary:** Gmail organizer running well with 9 sessions in last 24h and Chrome available for 4 consecutive sessions. One misclassification (Mission Events job application email trashed). Proton daemon running but IDLE since restart -- not processing new arrivals for ~21 hours. 5 new senders memorized, 14 cross-platform senders synced.

### Gmail (24 hours)
- Inbox: 14 emails -- 1 missed low-priority (Slack weekly summary should have been archived), 1 missed auto-trash (Google Cloud Alerting at 01:05 UTC), 4 new job platform senders not yet in memory, 8 legitimate job application confirmations correctly kept
- Trash: 11 emails checked -- 10 correctly trashed (2x Temu, 1x Wise, 3x GCloud Alerting, 1x Firebase crash, 1x Firebase App Dist, 1x VisualCV, 1x St.George), **1 mistake** (Mission Events job app trashed)
- Sessions: 9 runs (S17-S25), all classified, 4 consecutive with Chrome (S22-S25)
- Pending: 0 actions queued -- no backlog
- classified-ids.json: 33 entries -- healthy (cap: 500)

### Proton (24 hours)
- Inbox: 38 emails scanned -- 10 marketing, 6 notifications, 22 kept
- Daemon: Started 2026-02-01T23:27Z, processed 8 on startup (4 notifications moved, 1 marketing trashed, 3 kept/archived), entered IDLE. No further processing for ~21 hours.
- Daemon bug: Luxury Escapes classified as "keep" on 2026-01-31 despite being in marketing list (stale MEMORY.md)
- Errors: 0

### Misclassifications Found
1. **Mission Events Team** (events@e.mission.dev) -- "Your journey to Senior Frontend Engineer at Travel Solutions has begun!", 2026-02-02 03:59 UTC, Gmail -- job application email incorrectly trashed (sender not in memory, unsubscribe link triggered false positive)
2. **Proton: Luxury Escapes** (email@m.luxuryescapes.com) -- classified as "keep" on 2026-01-31 despite being in Always Unsubscribe list (daemon loaded stale MEMORY.md from before the sender was added)

### Fixes Applied
1. Gmail MEMORY.md: Added 4 new job application platform senders (Mission/mission.dev, Resolve Recruit/idibu, Workable, WeAreShovels/Join.com)
2. Gmail MEMORY.md: Updated job application pattern recognition list
3. Proton MEMORY.md: Added 3 marketing senders synced from Gmail (St.George, Temu, Caluga Farm Store)
4. Proton MEMORY.md: Added 11 job application senders to Never Unsubscribe (SEEK Applications, Canva, Indeed x2, Bookipi, Mission x2, Workable, Join.com, Resolve Recruit)
5. Cross-platform sync: 14 senders Gmail->Proton, 0 Proton->Gmail

### Remaining Issues
1. **Proton daemon IDLE >21h:** Not processing new mail. Needs restart to pick up ~10 marketing emails in Proton inbox.
2. **Proton daemon stale MEMORY.md:** Doesn't hot-reload; needs code fix to reload on IDLE wakeup or file watch.
3. **Slack weekly summary in Gmail inbox:** feedback@slack.com in Auto-Archive list but not caught -- organizer should handle next run.

---

## Review — 2026-02-03 00:30 AEDT

### Overall Grade: A-

Major improvement over previous reviews. The `--chrome` flag fix resolved the 13-session Chrome drought — Session 22 ran with Chrome and cleared all 5 pending actions. Gmail classification remains perfect. Proton daemon still idle >24h (only remaining issue). No misclassifications on either platform.

### Gmail (24 hours)
- Inbox: 3 emails — 0 missed junk, 3 legitimate (G2A transactional, McGrath real estate, Uplus real estate)
- Trash: 4 emails checked — 4 correctly trashed (3x GCloud Alerting auto-trash, 1x VisualCV marketing)
- Sessions: 1 run (Session 22). Chrome available for first time since Session 9. Dedup working (0 new emails to classify)
- Pending: 0 actions queued. Queue fully cleared, pending-actions.json deleted
- classified-ids.json: 9 entries. Healthy, well under 500 cap
- MEMORY.md: No contradictions. 51 marketing, 2 auto-trash, 16 auto-archive, 23 keep-unread senders

### Proton (24 hours)
- Inbox: 8 emails (1 marketing VisualCV, 4 notification, 3 keep)
- Daemon: Last active 2026-01-31T23:05Z. IDLE >24 hours. 0 emails processed
- Daemon logs: Clean — no errors, no crashes. IDLE loop not triggering on new mail
- MEMORY.md: No contradictions. 79 marketing, 12 never-unsubscribe, 20 notification senders

### Misclassifications Found
- No misclassifications detected on either platform

### Fixes Applied
- No MEMORY.md fixes needed — all senders correctly listed
- No pending-actions cleanup needed — queue already cleared by Session 22
- No cross-platform sync needed — all senders already synced from previous reviews

### Key Improvement: Chrome Fixed
- Root cause of 13-session Chrome drought identified: `claude -p` launched by launchd was missing `--chrome` flag
- Fix applied: `--chrome` added to launchd plist command
- Gmail organizer skill updated: now aborts entirely if Chrome unavailable (no more pending-actions fallback)
- Verified: Session 22 test run at 10:11 AM confirmed Chrome connection and cleared all pending actions

### Remaining Issues
1. **Proton daemon idle >24h** — Bridge IMAP IDLE not triggering on new mail. Needs manual restart
2. **Proton scanner --mailbox flag** — Still can't audit Trash/Notifications folders (known bug)

---

## Review — 2026-02-02 22:15 AEDT

### Overall Grade: B

Same state as 21:15 review. No new emails arrived in the last hour. Gmail classification remains perfect (8/8 correct) but Chrome-less, so 5 pending actions unexecuted. Proton daemon still idle >24h — 8 emails sitting in inbox unprocessed. No misclassifications. No fixes needed (all senders already in MEMORY.md from earlier reviews). Grade held at B: classification is solid, execution is the bottleneck.

### Gmail (24 hours)
- Inbox: 8 emails — 5 correctly classified for action (3x GCloud Alerting auto-trash, 1x VisualCV marketing trash, 1x YouTube archive), 3 legitimate (G2A rating reminder, McGrath real estate, Uplus real estate)
- Trash: 0 emails — Chrome unavailable, no actions executed
- Sessions: 5 runs (17-21), all classify-only. Dedup working perfectly (7 of 8 emails skipped as already classified)
- Pending: 5 actions (4 trash + 1 archive), created 2026-02-02T20:10Z. Fresh, not stale
- classified-ids.json: 9 entries. Healthy
- MEMORY.md: No contradictions found. All 8 inbox senders already have correct rules

### Proton (24 hours)
- Inbox: 8 emails (same as Gmail via forwarding). Scanner classifications correct for all 8
- Daemon: Last active 2026-01-31T23:05Z. IDLE >24 hours. 0 emails processed. The 8 inbox emails are NOT being handled by daemon IDLE loop
- Daemon logs: Clean — no errors, no crashes. Just not receiving IMAP IDLE triggers for new mail

### Misclassifications Found
- No new misclassifications detected (Gmail or Proton)

### Fixes Applied
- No fixes needed — all senders already correctly listed from earlier review sessions today

### Remaining Issues
1. **Gmail Chrome dependency** — 5 pending actions, 13 sessions without execution. Organizer classifies perfectly but can't act
2. **Proton daemon IDLE >24h** — Bridge IMAP IDLE not triggering on new mail. Needs manual restart
3. **Proton scanner --mailbox flag** — Still can't audit Trash/Notifications folders (known bug from prior reviews)

---

## Review -- 2026-02-02 21:15 AEDT

### Overall Grade: B

Gmail classification perfect (8/8 correct). No misclassifications on either platform. But Gmail cannot execute actions (Chrome unavailable again -- 5 items queued), and Proton daemon has been idle >24 hours despite 8 new emails arriving. Both organizers can think but neither can act.

### Gmail (24 hours)
- **Inbox:** 8 emails -- 0 missed junk, 3 legitimate (kept correctly), 5 correctly classified for action but unexecuted
  - Google Cloud Alerting x3 (alerting-noreply@google.com) -- auto-trash, pending execution
  - YouTube (noreply@youtube.com) -- low-priority subscriber notification, pending archive
  - VisualCV (team@visualcv.com) -- marketing, pending trash (new sender added to MEMORY.md in Session 20)
  - G2A.COM (no-reply@g2a.com) -- transactional rating reminder, correctly kept
  - McGrath / Luke Allan (lukeallan@mcgrath.propertyemail.com.au) -- real estate listings, correctly kept
  - Uplus Real Estate (lily@uplusrealty.com.au) -- real estate listings, correctly kept
- **Trash:** 0 emails -- nothing trashed in last 24h. Chrome unavailable.
- **Sessions:** 3 runs (Sessions 19, 20, 21). Dedup working correctly (1-2 new emails per session). All classify-only.
- **Pending:** 5 actions queued (4 trash + 1 archive), created 2026-02-02. Fresh, not stale.
- **classified-ids.json:** 9 IDs tracked. Healthy, well under 500 cap.
- **MEMORY.md:** No contradictions. 33 marketing, 2 auto-trash, 16 auto-archive, 23 keep-unread. VisualCV added correctly in Session 20.

### Proton (24 hours)
- **Inbox:** 8 emails (same as Gmail -- forwarding). Scanner classifications all correct:
  - Google Cloud Alerting x3 -- notification (correct)
  - YouTube -- notification (correct)
  - VisualCV -- marketing (correct)
  - G2A.COM (no-reply@) -- keep (correct, transactional)
  - McGrath -- keep (correct, real estate)
  - Uplus Real Estate -- keep (correct)
- **Trash:** Cannot audit -- scanner returns same 8 emails regardless of `--mailbox` flag (known bug)
- **Notifications:** Cannot audit -- same scanner bug
- **Daemon:** Last active 2026-01-31 23:05 UTC. Connected, processed 0 emails, entered IDLE. Has been idle >24 hours. The 8 new emails are NOT being processed by the daemon.

### Misclassifications Found
- No misclassifications detected. All 8 Gmail emails and 8 Proton emails classified correctly.

### Fixes Applied
1. Added VisualCV (team@visualcv.com) to Proton MEMORY.md "Always Unsubscribe" list (cross-platform sync from Gmail)
2. Added `team@visualcv.com` to Proton marketing sender patterns
3. Updated Proton MEMORY.md timestamp to 2026-02-02

### Remaining Issues
1. **Proton daemon idle >24 hours** -- IDLE loop is not receiving new mail triggers from Proton Bridge. 8 emails sitting unprocessed. Needs manual restart or investigation into Bridge IMAP IDLE support.
2. **Gmail Chrome still needed for execution** -- 5 pending actions queued today. The early-morning backlog clearance was effective but the pattern repeats: classify during the day, queue grows, need Chrome to clear.
3. **Proton scanner `--mailbox` flag broken** -- Cannot audit Trash or Notifications folders. Returns inbox results regardless of flag value.

---

## Review -- 2026-02-02 05:30 AEDT

### Overall Grade: B+

Gmail classification perfect (6/6), trash correct (3/3). Proton has 1 misclassification (McGrath as notification), 1 cross-platform contradiction fixed (Bastion PG). Daemon running but idle >20h. Gmail pending backlog is fresh (2 items), no Chrome dependency issues today.

### Gmail (24 hours)
- **Inbox:** 6 emails -- 0 missed junk, 6 legitimate
  - G2A.COM (no-reply@g2a.com) -- post-purchase rating reminder, correctly kept
  - Google Cloud Alerting x2 (alerting-noreply@google.com) -- correctly identified as auto-trash, pending execution
  - McGrath / Luke Allan (lukeallan@mcgrath.propertyemail.com.au) -- new real estate sender, correctly kept and added to MEMORY.md
  - Uplus Real Estate (lily@uplusrealty.com.au) -- new real estate sender, correctly kept and added to MEMORY.md
  - Westpac eStatement (email7.westpac.com.au) -- banking service message, correctly kept
- **Trash:** 3 emails checked -- 3 correctly trashed, 0 mistakes
  - Domaine Homes NSW (contact@domainehomes.com.au) -- marketing, correct
  - Google Cloud Alerting x2 (alerting-noreply@google.com) -- auto-trash, correct
- **Sessions:** 3 runs today (Sessions 16, 17, 18). Sessions 17-18 used `newer_than:1d` + classified-ids.json dedup -- much more efficient than previous 100-email full scans.
- **Pending:** 2 actions queued (2x GCloud Alerting trash), age: <1 day. Fresh.
- **classified-ids.json:** 6 IDs tracked. Healthy, well under 500 cap.
- **MEMORY.md:** No contradictions. 32 marketing, 2 auto-trash, 16 auto-archive, 22 keep-unread.

### Proton (24 hours)
- **Inbox:** 5 emails scanned by CLI
  - Google Cloud Alerting x2 -- correctly classified as notification
  - G2A.COM (no-reply@g2a.com) -- correctly classified as keep (transactional)
  - McGrath / Luke Allan -- MISCLASSIFIED as "notification" (should be keep/real estate)
  - Uplus Real Estate -- correctly classified as keep
- **Daemon:** Last active 2026-01-31 22:10 UTC -- processed 10 emails. Restarted at 23:05, processed 0, went to IDLE. Has been idle >20 hours.
- **Daemon last batch accuracy:** 7/10 correct (Luxury Escapes + G2A archived instead of trashed, Westpac to Notifications instead of kept -- all pre-dating MEMORY.md sync)

### Misclassifications Found
1. **Proton: McGrath (lukeallan@mcgrath.propertyemail.com.au)** -- classified as "notification" by scanner. Should be "keep" (real estate listings). Scanner doesn't have a real estate category; fell through to notification via Precedence:bulk header.
2. **Proton: Bastion Property Group (bastionpropertygroup.com.au)** -- was in Proton "Always Unsubscribe" but is on Gmail "Keep Unread" list. Cross-platform contradiction.

### Fixes Applied
1. Added Uplus Real Estate (lily@uplusrealty.com.au) to Proton "Never Unsubscribe"
2. Added McGrath / Luke Allan (lukeallan@mcgrath.propertyemail.com.au) to Proton "Never Unsubscribe"
3. Moved Bastion Property Group from Proton "Always Unsubscribe" to "Never Unsubscribe" (cross-platform contradiction fix)
4. Added 4 trusted sender domain patterns to Proton: `*@uplusrealty.com.au`, `*@mcgrath.propertyemail.com.au`, `*@bastionpropertygroup.com.au`, `*@bastionpg.propertyemail.com.au`
5. Updated Proton MEMORY.md timestamp

### Remaining Issues
1. **Proton daemon idle >20 hours** -- IDLE loop not receiving new mail triggers. Needs restart or Proton Bridge IMAP IDLE investigation.
2. **Proton scanner can't distinguish mailboxes** -- `--mailbox Trash` and `--mailbox "Folders/Notifications"` return same results as inbox scan. Limits audit capability.
3. **Gmail Chrome still needed for execution** -- Current pending is only 2 items (manageable), but future sessions will queue again without Chrome.

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
