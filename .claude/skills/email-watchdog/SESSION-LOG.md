# Email Watchdog - Session Log

Running log of watchdog checks. The watchdog runs every 15 minutes via launchd, monitoring Proton Bridge, Proton daemon, and Gmail scheduler health.

---

## Monitoring Period: 2026-01-30 21:00 to 2026-01-31 10:30

**Watchdog started:** 2026-01-30T21:00:16
**Check interval:** Every 15 minutes
**Total checks logged:** 57

### Health Summary

| Component | Status | Details |
|-----------|--------|---------|
| Proton Bridge | OK | Running throughout entire period |
| Proton Daemon | OK | Process alive, no error loops detected |
| Gmail Scheduler | ISSUE | Last run 28-42h ago (expected every 4h) |

### Issues Detected

| Time | Component | Issue | Resolution |
|------|-----------|-------|------------|
| 2026-01-30 21:00 - 2026-01-31 10:30 | Gmail | Last run 28-42h overdue (expected every 4h) | Persistent -- scheduler loaded but not executing |

### Check-by-Check Log

**2026-01-30:**
| Time | Bridge | Proton | Gmail | Issues |
|------|--------|--------|-------|--------|
| 21:00 | OK | OK | 28h overdue | 1 |
| 21:15 | OK | OK | 29h overdue | 1 |
| 21:30 | OK | OK | 29h overdue | 1 |
| 21:45 | OK | OK | 29h overdue | 1 |
| 22:00 | OK | OK | 29h overdue | 1 |
| 22:15 | OK | OK | 30h overdue | 1 |
| 22:30 | OK | OK | 30h overdue | 1 |
| 22:45 | OK | OK | 30h overdue | 1 |
| 23:00 | OK | No log 2h | 30h overdue | 1 |
| 23:15 | OK | No log 2h | 31h overdue | 1 |
| 23:30 | OK | No log 2h | 31h overdue | 1 |
| 23:45 | OK | No log 2h | 31h overdue | 1 |

**2026-01-31:**
| Time | Bridge | Proton | Gmail | Issues |
|------|--------|--------|-------|--------|
| 00:00 | OK | No log 3h | 31h overdue | 1 |
| 00:15 | OK | No log 3h | 32h overdue | 1 |
| 00:30 | OK | No log 3h | 32h overdue | 1 |
| 00:45 | OK | No log 3h | 32h overdue | 1 |
| 01:00 | OK | No log 4h | 32h overdue | 1 |
| 01:15 | OK | No log 4h | 33h overdue | 1 |
| 01:30 | OK | No log 4h | 33h overdue | 1 |
| 01:45 | OK | No log 4h | 33h overdue | 1 |
| 02:00 | OK | No log 5h | 33h overdue | 1 |
| 02:15 | OK | No log 5h | 34h overdue | 1 |
| 02:30 | OK | No log 5h | 34h overdue | 1 |
| 02:45 | OK | No log 5h | 34h overdue | 1 |
| 03:00 | OK | No log 6h | 34h overdue | 1 |
| 03:15 | OK | No log 6h | 35h overdue | 1 |
| 03:30 | OK | No log 6h | 35h overdue | 1 |
| 03:45 | OK | No log 6h | 35h overdue | 1 |
| 04:00 | OK | No log 7h | 35h overdue | 1 |
| 04:15 | OK | No log 7h | 36h overdue | 1 |
| 04:30 | OK | No log 7h | 36h overdue | 1 |
| 04:45 | OK | No log 7h | 36h overdue | 1 |
| 05:00 | OK | No log 8h | 36h overdue | 1 |
| 05:15 | OK | No log 8h | 37h overdue | 1 |
| 05:30 | OK | No log 8h | 37h overdue | 1 |
| 05:45 | OK | No log 8h | 37h overdue | 1 |
| 06:00 | OK | No log 9h | 37h overdue | 1 |
| 06:15 | OK | No log 9h | 38h overdue | 1 |
| 06:30 | OK | No log 9h | 38h overdue | 1 |
| 06:45 | OK | No log 9h | 38h overdue | 1 |
| 07:00 | OK | No log 10h | 38h overdue | 1 |
| 07:15 | OK | No log 10h | 39h overdue | 1 |
| 07:30 | OK | No log 10h | 39h overdue | 1 |
| 07:45 | OK | No log 10h | 39h overdue | 1 |
| 08:00 | OK | No log 11h | 39h overdue | 1 |
| 08:15 | OK | No log 11h | 40h overdue | 1 |
| 08:30 | OK | No log 11h | 40h overdue | 1 |
| 08:45 | OK | No log 11h | 40h overdue | 1 |
| 09:00 | OK | No log 12h | 40h overdue | 1 |
| 09:15 | OK | No log 12h | 41h overdue | 1 |
| 09:30 | OK | No log 12h | 41h overdue | 1 |
| 09:45 | OK | No log 12h | 41h overdue | 1 |
| 10:00 | OK | No log 13h | 41h overdue | 1 |
| 10:15 | OK | OK | 42h overdue | 1 |
| 10:18 | OK | OK | 42h overdue | 1 |
| 10:23 | OK | OK | 42h overdue | 1 |
| 10:25 | OK | OK | 42h overdue | 1 |
| 10:30 | OK | OK | 42h overdue | 1 |

### Observations
- Proton Bridge: Healthy throughout. No restarts needed.
- Proton Daemon: Process alive but no IMAP activity from 23:00 to 10:15 (13h). This is normal -- IDLE mode only logs when new mail arrives.
- Gmail Scheduler: Consistently overdue. The launchd job `com.claude.schedule.gmail-organizer` is loaded but has not executed in 42+ hours. Needs investigation -- the scheduler may be failing silently or the plist may have a configuration issue.

### Restarts / Interventions
- None during this period. No crashes detected.

---

## Notes

- Watchdog script location: `assistant/scripts/email-watchdog.sh`
- LaunchAgent plist: `assistant/scripts/com.paulhayes.email-watchdog.plist`
- Log file: `~/Library/Logs/email-watchdog/watchdog.log`
- Auto-trims log at 1MB (keeps last 500 lines)
- Monitors: Proton Bridge process, Proton daemon (proton-daemon.js), Gmail scheduler (com.claude.schedule.gmail-organizer)
