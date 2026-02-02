# Proton Mail Organizer - Session Log

Running log of every Proton Mail organizer session (both interactive and daemon runs). Each entry records what was scanned, classified, and acted upon.

---

## Interactive Run (2026-02-03T~14:00Z)

**Connection:** Connected to Proton Bridge (IMAP OK, SMTP OK)
**Emails scanned:** 0 (inbox empty)
**Actions:** None (inbox clean, no unread emails in last 48 hours)
**Memory senders loaded:** 67 marketing, 19 never-unsub, 20 notification

---

## Daemon Run (2026-01-30T23:24:36Z)

**Status:** Active (IDLE, waiting for new mail)
**Connection:** Connected to Proton Bridge
**Emails processed:** 0
**Actions:** None (inbox clean)

---

## Daemon Run (2026-01-30T23:06:04Z)

**Connection:** Connected to Proton Bridge
**Emails processed:** 10

### Actions Taken
| Time | Classification | Sender | Action |
|------|---------------|--------|--------|
| 23:06:29Z | keep | Selim Bucher <selim.bucher@taxperts.ch> | Archived |
| 23:06:29Z | marketing | Lauren Smith <marketing@origon.ai> | Trashed |
| 23:06:29Z | keep | Manish Sanganeria <manish.sanganeria@kreatetechnologies.com> | Archived |
| 23:06:29Z | notification | Robert Pollai <hit-reply@linkedin.com> | Moved to Folders/Notifications |
| 23:06:29Z | keep | Internetadmin@stgeorge.com.au | Archived |
| 23:06:29Z | notification | Google Cloud Alerting <alerting-noreply@google.com> | Moved to Folders/Notifications |
| 23:06:29Z | marketing | Reddit <noreply@redditmail.com> | Trashed |
| 23:06:29Z | notification | Theodore Koutsikamanis <theo@bastionpg.propertyemail.com.au> | Moved to Folders/Notifications |
| 23:06:29Z | keep | noreply@post.xero.com | Archived |
| 23:06:29Z | keep | 9Now <tvguide@mail.9now.com.au> | Archived |

### Summary
- Unsubscribed: 0, Moved: 3, Trashed: 2, Archived: 5

---

## Daemon Run (2026-01-30T09:57:32Z)

**Connection:** Connected to Proton Bridge
**Emails processed:** 20

### Actions Taken
| Time | Classification | Sender | Action |
|------|---------------|--------|--------|
| 09:58:23Z | notification | Facebook <noreply@developers.facebook.com> | Moved to Folders/Notifications |
| 09:58:23Z | notification | ServiceNow University <nowlearning@service-now.com> | Moved to Folders/Notifications |
| 09:58:23Z | keep | G2A.COM <no-reply@g2a.com> | Archived |
| 09:58:23Z | marketing | Matt Pocock (AI Hero) <matt@aihero.dev> | Trashed |
| 09:58:23Z | notification | Google Cloud Alerting <alerting-noreply@google.com> | Moved to Folders/Notifications |
| 09:58:23Z | notification | Google Cloud <CloudPlatform-noreply@google.com> | Moved to Folders/Notifications |
| 09:58:23Z | keep | Open Universities Australia <oua@e.open.edu.au> | Archived |
| 09:58:23Z | keep | Origon AI <noreply@origon.ai> | Archived |
| 09:58:23Z | notification | Google Cloud Alerting <alerting-noreply@google.com> | Moved to Folders/Notifications |
| 09:58:23Z | notification | firebase-noreply@google.com | Moved to Folders/Notifications |
| 09:58:23Z | notification | ServiceNow <signon@service-now.com> | Moved to Folders/Notifications |
| 09:58:23Z | marketing | IdeaMiner <hello@ideaminer.io> | Trashed |
| 09:58:23Z | notification | firebase-noreply@google.com | Moved to Folders/Notifications |
| 09:58:23Z | keep | ATO SMSF news <smsf@news.ato.gov.au> | Archived |
| 09:58:23Z | notification | Google Cloud Alerting <alerting-noreply@google.com> | Moved to Folders/Notifications |
| 09:58:23Z | notification | Dropbox <no-reply@em-s.dropbox.com> | Moved to Folders/Notifications |
| 09:58:23Z | notification | Google Cloud Alerting <alerting-noreply@google.com> | Moved to Folders/Notifications |
| 09:58:23Z | keep | Apple Developer <developer@insideapple.apple.com> | Archived |
| 09:58:23Z | notification | Google Cloud Alerting <alerting-noreply@google.com> | Moved to Folders/Notifications |
| 09:58:23Z | marketing | Base44 <no-reply@marketing.base44.com> | Trashed |

### Summary
- Unsubscribed: 0, Moved: 12, Trashed: 3, Archived: 5

---

## Session 2 - Interactive (2026-01-29)

**Date:** 2026-01-29
**Emails processed:** 199 (2 batches of ~100)

### Classifications
| Category | Count |
|----------|-------|
| Marketing | 44 |
| Notification | 77 |
| Keep (archived) | 78 |

### Actions Taken
| Time | Action | Target | Result |
|------|--------|--------|--------|
| -- | Trash | 44 marketing senders | 2 batches |
| -- | Move to Folders/Notifications | 77 notification senders | Completed |
| -- | Archive | 78 kept emails | Moved to Archive |

### Code Fixes Applied
- Split isImportant() patterns: sender domain patterns check `from` only, keyword patterns check `subject` only
- Added `hello@`, `memberships?@`, `travel-insider@`, `@*edm*` as weak marketing sender patterns (+2)
- Added firebaseapptesters.com and youtube.com to notification detector
- Scanner now prioritizes notification over marketing when both detectors fire
- Fixed Apple domain regex: `$` anchor to `\b` for display name format

### Excluded by User
- Rose Cochrane (kjblaw.com.au) -- "Sale" in subject is property sale, not discount

---

## Session 1 - Interactive (2026-01-29)

**Date:** 2026-01-29
**Emails processed:** ~450 (7 batches of 50 + 2 batches of 100)

### Classifications
| Category | Count |
|----------|-------|
| Marketing | ~80 |
| Notification | ~50 |
| Keep (archived) | ~320 |

### Actions Taken
| Time | Action | Target | Result |
|------|--------|--------|--------|
| -- | Trash | ~80 marketing senders | Multiple batches |
| -- | Move to Folders/Notifications | ~50 notification senders | Completed |
| -- | Archive | ~320 kept emails | Moved to Archive |

### Excluded by User
- Sales Support (OneAgent, oneagentcanberra.com.au) -- real estate transaction, not marketing

---

## Cumulative Statistics

- Total emails processed: ~680+ (interactive + daemon)
- Marketing trashed: ~130+
- Notifications moved: ~142+
- Archived (kept): ~408+
- Excluded by user: 2
- False positive rate: Low (2 flagged across ~650 interactive emails)
- Daemon uptime: Running since 2026-01-30, 30 emails processed across 2 daemon cycles
