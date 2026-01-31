#!/bin/bash
#
# Email Daemon Watchdog
# Monitors Proton daemon and Gmail scheduler, restarts on failure.
# Designed to run periodically via launchd (every 15 min).
#
# Usage: email-watchdog.sh [--notify]
#   --notify  Send iPad notification on issues (requires MCP server)
#

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$HOME/Library/Logs/email-watchdog"
LOG_FILE="$LOG_DIR/watchdog.log"
PROTON_PLIST="com.paulhayes.proton-daemon"
GMAIL_PLIST="com.claude.schedule.gmail-organizer"
REVIEW_PLIST="com.paulhayes.email-review"
PROTON_STDERR="$HOME/Library/Logs/proton-daemon/stderr.log"
PROTON_STDOUT="$HOME/Library/Logs/proton-daemon/stdout.log"
GMAIL_LOG="$HOME/.claude/logs/gmail-organizer.log"
REVIEW_LOG="$HOME/.claude/logs/email-review.log"

NOTIFY=false
[ "$1" = "--notify" ] && NOTIFY=true

mkdir -p "$LOG_DIR"

ts() { date '+%Y-%m-%dT%H:%M:%S'; }
log() { echo "[$(ts)] $1" >> "$LOG_FILE"; }
issues=()

# --- Proton Daemon Health Check ---

check_proton() {
    # 1. Is the process alive?
    if ! pgrep -f "proton-daemon.js" > /dev/null 2>&1; then
        log "PROTON: Process not running. Restarting..."
        issues+=("Proton daemon was dead, restarted")
        restart_proton
        return
    fi

    # 2. Is it stuck in an error loop? (stderr growing fast)
    if [ -f "$PROTON_STDERR" ]; then
        STDERR_SIZE=$(stat -f%z "$PROTON_STDERR" 2>/dev/null || echo 0)
        # If stderr > 1MB, the daemon is likely stuck in a reconnect loop
        if [ "$STDERR_SIZE" -gt 1048576 ]; then
            log "PROTON: stderr is ${STDERR_SIZE} bytes (error loop detected). Restarting..."
            issues+=("Proton daemon stuck in error loop, restarted")
            restart_proton
            return
        fi
    fi

    # 3. Has it logged anything recently? (check stdout for activity in last 2 hours)
    if [ -f "$PROTON_STDOUT" ]; then
        LAST_MOD=$(stat -f%m "$PROTON_STDOUT" 2>/dev/null || echo 0)
        NOW=$(date +%s)
        AGE=$(( NOW - LAST_MOD ))
        # If stdout hasn't been modified in 2 hours, it might be stale
        # but IDLE mode means no writes unless mail arrives, so this is just info
        if [ "$AGE" -gt 7200 ]; then
            log "PROTON: No log activity in $(( AGE / 3600 ))h (normal if no new mail)"
        fi
    fi

    log "PROTON: OK (process alive, no error loop)"
}

restart_proton() {
    # Clear bloated error log
    if [ -f "$PROTON_STDERR" ]; then
        truncate -s 0 "$PROTON_STDERR"
    fi
    if [ -f "$PROTON_STDOUT" ]; then
        truncate -s 0 "$PROTON_STDOUT"
    fi

    launchctl stop "$PROTON_PLIST" 2>/dev/null
    sleep 2
    launchctl start "$PROTON_PLIST" 2>/dev/null

    sleep 5
    if pgrep -f "proton-daemon.js" > /dev/null 2>&1; then
        log "PROTON: Restart successful"
    else
        log "PROTON: Restart FAILED - manual intervention needed"
        issues+=("Proton restart failed!")
    fi
}

# --- Gmail Scheduler Health Check ---

check_gmail() {
    # 1. Is the plist loaded?
    if ! launchctl list 2>/dev/null | grep -q "$GMAIL_PLIST"; then
        log "GMAIL: Scheduler not loaded. Reloading..."
        issues+=("Gmail scheduler was unloaded, reloaded")
        GMAIL_PLIST_FILE="$HOME/Library/LaunchAgents/$GMAIL_PLIST.plist"
        if [ -f "$GMAIL_PLIST_FILE" ]; then
            launchctl load "$GMAIL_PLIST_FILE" 2>/dev/null
            log "GMAIL: Reloaded plist"
        else
            log "GMAIL: Plist not found at $GMAIL_PLIST_FILE"
            issues+=("Gmail plist file missing!")
        fi
        return
    fi

    # 2. Check if the process is stuck (running > 45 minutes)
    GMAIL_PID=$(launchctl list 2>/dev/null | grep "$GMAIL_PLIST" | awk '{print $1}')
    if [ "$GMAIL_PID" != "-" ] && [ -n "$GMAIL_PID" ] && [ "$GMAIL_PID" -gt 0 ] 2>/dev/null; then
        # Process is running — check how long
        PROC_START=$(ps -p "$GMAIL_PID" -o lstart= 2>/dev/null)
        if [ -n "$PROC_START" ]; then
            START_EPOCH=$(date -j -f "%a %b %d %T %Y" "$PROC_START" +%s 2>/dev/null || echo 0)
            NOW=$(date +%s)
            RUNTIME=$(( NOW - START_EPOCH ))
            if [ "$RUNTIME" -gt 2700 ]; then  # 45 minutes
                log "GMAIL: Process $GMAIL_PID stuck for $(( RUNTIME / 60 ))min. Killing..."
                issues+=("Gmail stuck for $(( RUNTIME / 60 ))min, killed")
                kill -TERM "$GMAIL_PID" 2>/dev/null
                sleep 3
                # Force kill if still alive
                if ps -p "$GMAIL_PID" > /dev/null 2>&1; then
                    kill -9 "$GMAIL_PID" 2>/dev/null
                    log "GMAIL: Force-killed $GMAIL_PID"
                fi
                return
            else
                log "GMAIL: Running (PID $GMAIL_PID, ${RUNTIME}s elapsed — normal)"
                return
            fi
        fi
    fi

    # 3. Check last run was successful (if log exists)
    if [ -f "$GMAIL_LOG" ]; then
        LAST_MOD=$(stat -f%m "$GMAIL_LOG" 2>/dev/null || echo 0)
        NOW=$(date +%s)
        AGE=$(( NOW - LAST_MOD ))
        HOURS=$(( AGE / 3600 ))
        if [ "$HOURS" -gt 8 ]; then
            log "GMAIL: Last run was ${HOURS}h ago (expected every 4h)"
            issues+=("Gmail hasn't run in ${HOURS}h")
        else
            log "GMAIL: OK (last run ${HOURS}h ago)"
        fi
    else
        log "GMAIL: OK (scheduler loaded, no log file yet)"
    fi
}

# --- Proton Bridge Check ---

check_bridge() {
    if ! pgrep -f "Proton Mail Bridge" > /dev/null 2>&1 && ! pgrep -f "bridge.*--grpc" > /dev/null 2>&1; then
        # Check by launchctl
        if ! launchctl list 2>/dev/null | grep -q "protonmail.bridge"; then
            log "BRIDGE: Proton Mail Bridge not running!"
            issues+=("Proton Bridge not running - daemons will fail")
        fi
    else
        log "BRIDGE: OK"
    fi
}

# --- Email Review Scheduler Health Check ---

check_review() {
    # 1. Is the plist loaded?
    if ! launchctl list 2>/dev/null | grep -q "$REVIEW_PLIST"; then
        log "REVIEW: Scheduler not loaded. Reloading..."
        issues+=("Email review scheduler was unloaded, reloaded")
        REVIEW_PLIST_FILE="$HOME/Library/LaunchAgents/$REVIEW_PLIST.plist"
        if [ -f "$REVIEW_PLIST_FILE" ]; then
            launchctl load "$REVIEW_PLIST_FILE" 2>/dev/null
            log "REVIEW: Reloaded plist"
        else
            log "REVIEW: Plist not found at $REVIEW_PLIST_FILE"
            issues+=("Email review plist file missing!")
        fi
        return
    fi

    # 2. Check if the process is stuck (running > 45 minutes)
    REVIEW_PID=$(launchctl list 2>/dev/null | grep "$REVIEW_PLIST" | awk '{print $1}')
    if [ "$REVIEW_PID" != "-" ] && [ -n "$REVIEW_PID" ] && [ "$REVIEW_PID" -gt 0 ] 2>/dev/null; then
        # Process is running — check how long
        PROC_START=$(ps -p "$REVIEW_PID" -o lstart= 2>/dev/null)
        if [ -n "$PROC_START" ]; then
            START_EPOCH=$(date -j -f "%a %b %d %T %Y" "$PROC_START" +%s 2>/dev/null || echo 0)
            NOW=$(date +%s)
            RUNTIME=$(( NOW - START_EPOCH ))
            if [ "$RUNTIME" -gt 2700 ]; then  # 45 minutes
                log "REVIEW: Process $REVIEW_PID stuck for $(( RUNTIME / 60 ))min. Killing..."
                issues+=("Email review stuck for $(( RUNTIME / 60 ))min, killed")
                kill -TERM "$REVIEW_PID" 2>/dev/null
                sleep 3
                # Force kill if still alive
                if ps -p "$REVIEW_PID" > /dev/null 2>&1; then
                    kill -9 "$REVIEW_PID" 2>/dev/null
                    log "REVIEW: Force-killed $REVIEW_PID"
                fi
                return
            else
                log "REVIEW: Running (PID $REVIEW_PID, ${RUNTIME}s elapsed — normal)"
                return
            fi
        fi
    fi

    # 3. Check last run (should run twice daily at 9am and 9pm)
    if [ -f "$REVIEW_LOG" ]; then
        LAST_MOD=$(stat -f%m "$REVIEW_LOG" 2>/dev/null || echo 0)
        NOW=$(date +%s)
        AGE=$(( NOW - LAST_MOD ))
        HOURS=$(( AGE / 3600 ))
        if [ "$HOURS" -gt 24 ]; then
            log "REVIEW: Last run was ${HOURS}h ago (expected every 12h)"
            issues+=("Email review hasn't run in ${HOURS}h")
        else
            log "REVIEW: OK (last run ${HOURS}h ago)"
        fi
    else
        log "REVIEW: OK (scheduler loaded, no log file yet)"
    fi
}

# --- Pending Actions Backlog Check ---

check_pending_actions() {
    PENDING_FILE="$SCRIPT_DIR/../../.claude/skills/gmail-unsubscribe/pending-actions.json"
    if [ -f "$PENDING_FILE" ]; then
        # Check file age
        LAST_MOD=$(stat -f%m "$PENDING_FILE" 2>/dev/null || echo 0)
        NOW=$(date +%s)
        AGE=$(( NOW - LAST_MOD ))
        HOURS=$(( AGE / 3600 ))

        # Count actions (rough count by counting "action" occurrences)
        ACTION_COUNT=$(grep -c '"action"' "$PENDING_FILE" 2>/dev/null || echo 0)

        if [ "$AGE" -gt 172800 ] || [ "$ACTION_COUNT" -gt 20 ]; then
            log "PENDING: ${ACTION_COUNT} actions queued, file is ${HOURS}h old (threshold: 48h or >20 items)"
            issues+=("Gmail pending actions backlog: ${ACTION_COUNT} items, ${HOURS}h old")
        else
            log "PENDING: OK (${ACTION_COUNT} actions, ${HOURS}h old)"
        fi
    else
        log "PENDING: OK (no pending actions file)"
    fi
}

# --- Run All Checks ---

log "=== Watchdog check starting ==="

check_bridge
check_proton
check_gmail
check_review
check_pending_actions

if [ ${#issues[@]} -eq 0 ]; then
    log "=== All systems healthy ==="
else
    log "=== Found ${#issues[@]} issue(s) ==="
    SUMMARY=$(printf '%s; ' "${issues[@]}")

    if $NOTIFY; then
        # Send notification via iPad MCP if available
        curl -s -X POST "http://localhost:19847/notify" \
            -H "Content-Type: application/json" \
            -d "{\"message\": \"Watchdog: $SUMMARY\"}" \
            > /dev/null 2>&1 || true
    fi
fi

# Trim log file if > 1MB
if [ -f "$LOG_FILE" ]; then
    LOG_SIZE=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$LOG_SIZE" -gt 1048576 ]; then
        tail -500 "$LOG_FILE" > "$LOG_FILE.tmp"
        mv "$LOG_FILE.tmp" "$LOG_FILE"
        log "Watchdog log trimmed"
    fi
fi
