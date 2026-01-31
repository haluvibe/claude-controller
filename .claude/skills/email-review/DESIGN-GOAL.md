# Email Automation Stack — Design Goal

The entire email automation stack must run autonomously. You should be able to reboot your Mac, open Proton Mail Bridge, walk away, and trust that all four services come up, do their jobs, self-heal on failure, and improve over time — with zero ongoing human intervention.

The only manual step is opening Proton Mail Bridge after a reboot (it doesn't auto-start). Everything else is self-managing: the organizers classify and act, the watchdog monitors and restarts, and the review agent audits the results and fixes the organizers' rules when they get things wrong.

## The Four Services

1. **Proton Daemon** — always-on Node.js IMAP IDLE process. Classifies and sorts incoming Proton mail in real-time. Self-restarts via launchd KeepAlive.

2. **Gmail Organizer** — scheduled `claude -p` session every 4 hours. AI-classifies unread Gmail, trashes marketing, archives low-priority. Queues actions when Chrome is unavailable.

3. **Email Watchdog** — bash script every 15 minutes. Checks all services are alive and not stuck. Auto-restarts failed services. Sends iPad notification on issues.

4. **Email Review Agent** — scheduled `claude -p` session twice daily. Audits the last 30 days of actual emails across both inboxes. Catches misclassifications, fixes memory files, improves organizer rules. The mechanism by which the whole stack gets better over time.

## Technical Constraints

- **Claude Code subscription, not Anthropic API.** All `claude -p` sessions run through the Claude subscription (OAuth login). There is no API key. There is no per-token cost. Do not recommend switching to API-based billing or worry about token costs.
- **MCP servers for everything.** All email operations go through MCP servers — the Gmail MCP (`mcp__gmail__*`) for reading Gmail, the Claude in Chrome MCP (`mcp__claude-in-chrome__*`) for Gmail write operations (trash, archive, mark-as-read), and the claude-controller MCP for iPad notifications. Do NOT use the Gmail API directly or build custom API scripts. MCP is the integration layer.
- **Chrome for Gmail writes, not the Gmail API.** Gmail trash/archive/mark-read operations use the Claude in Chrome MCP to interact with the Gmail web UI. We do NOT use the Gmail API for write operations. This has been tried and ruled out — Chrome automation via MCP is the chosen approach. If Chrome is unavailable during a headless run, actions queue to `pending-actions.json` and get processed on the next run where Chrome is available.
- **Proton uses IMAP directly.** The Proton daemon talks to Proton Bridge via IMAP. No browser needed.

## Autonomy Requirements

- After a reboot + Bridge open, all services must come up without further input.
- No service should require interactive approval to do its job.
- Failures must be detected and recovered automatically (watchdog).
- Classification mistakes must be caught and corrected automatically (review agent).
- The system must improve its own rules over time without being told to.

## Improvement Plan

Findings from the swarm audit (2026-02-01). Ordered by priority.

### 1. Make the review agent actually apply fixes

The first run found 7 misclassifications and 11 missing memory entries but modified zero files. It reported everything perfectly but didn't act. The prompt needs restructuring so fixes happen inline as issues are discovered (e.g., find a missing sender in Step 1e, edit MEMORY.md right then) rather than deferring to a recommendations section.

### 2. Make the Proton daemon read MEMORY.md

All 5 Proton misclassifications (Luxury Escapes, G2A, Open Universities, 9Now, Westpac) trace to the daemon having zero awareness of the 73 senders in MEMORY.md. The hardcoded TypeScript classifiers operate in complete isolation from accumulated knowledge. The daemon should load sender preferences from MEMORY.md at startup and on SIGHUP.

### 3. Add email ID deduplication to the Gmail organizer

Sessions 12-16 re-scanned the same ~100 emails with near-identical classifications because Chrome wasn't available to mark them as read. A `classified-ids.json` file tracking already-processed email IDs would let the organizer skip known emails and only spend context on genuinely new ones.

### 4. Sync sender memory across Gmail and Proton

5+ senders are classified as marketing on Gmail but missing from Proton's memory (and vice versa). The review agent should include a cross-platform sync step that propagates sender rules between both MEMORY.md files.

### 5. Add Proton trash/Notifications audit to the review agent

The review agent checks Gmail trash for false positives (Step 1b) but has no equivalent check for Proton. If the daemon incorrectly trashes an important email, the review agent wouldn't catch it. Add a Proton Trash and Notifications folder scan.

### 6. Fix watchdog notification endpoint

The watchdog posts to `localhost:3742` but the actual endpoint is `localhost:19847`. Every alert has been silently failing. (Fixed 2026-02-01.)

### 7. Add pending-actions backlog check to the watchdog

The watchdog checks process liveness but is blind to the 64-item pending-actions queue that has been growing for days. Add a check: if `pending-actions.json` exists and is older than 48 hours or has >20 items, send an iPad notification.
