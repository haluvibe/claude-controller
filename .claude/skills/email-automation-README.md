# Email Automation Stack

## Services

| Service | Scheduler | Schedule | Notes |
|---------|-----------|----------|-------|
| **Gmail organizer** | Claude scheduler plugin | Every 4 hours (midnight, 4am, 8am, noon, 4pm, 8pm) | `claude -p /gmail-organizer --chrome` |
| **Proton daemon** | Manual plist (KeepAlive) | Always running | Polls every 5 min via IDLE timeout fallback |
| **Email review** | Manual plist | Twice daily (9am, 9pm) | `claude -p /email-review` |
| **Email watchdog** | Manual plist | Every 15 minutes | Bash health checker |

## Plist Locations

- Gmail organizer: `/Users/paulhayes/Library/LaunchAgents/com.claude.schedule.gmail-organizer.plist`
- Proton daemon: `/Users/paulhayes/Library/LaunchAgents/com.paulhayes.proton-daemon.plist`
- Email review: `/Users/paulhayes/Library/LaunchAgents/com.paulhayes.email-review.plist`
- Email watchdog: `/Users/paulhayes/Library/LaunchAgents/com.paulhayes.email-watchdog.plist`

## Skill Files

- Gmail organizer: `.claude/commands/gmail-organizer.md`
- Proton organizer: `.claude/commands/proton-organizer.md`
- Email review: `.claude/commands/email-review.md`

## Memory Files

- Gmail: `.claude/skills/gmail-unsubscribe/MEMORY.md`
- Proton: `.claude/skills/proton-organizer/MEMORY.md`

These are separate files for separate inboxes. The email review agent syncs sender rules between them.

## Logs

- Gmail organizer: `~/.claude/logs/gmail-organizer.log`
- Proton daemon: `~/Library/Logs/proton-daemon/stdout.log`
- Email review: `~/.claude/logs/email-review.log`
- Watchdog: `~/Library/Logs/email-watchdog/watchdog.log`

## Known Issues

- Proton scanner `--mailbox` flag broken — cannot audit Trash or Notifications folders.
- Mission Events (events@e.mission.dev) repeatedly trashed by Gmail organizer despite being in Keep list — body-based unsubscribe detection overrides MEMORY.md rules.
