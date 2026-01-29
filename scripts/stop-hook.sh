#!/bin/bash
# Hook script for Claude Code Stop events
# Clears iPad UI and notifies user that Claude has finished responding

# Read input from stdin (Claude Code passes JSON)
INPUT=$(cat)

# Ensure lockfile directory has restricted permissions
mkdir -p /tmp/claude-controller 2>/dev/null && chmod 700 /tmp/claude-controller 2>/dev/null

# Check if a permission request is pending - don't clear the iPad UI if so,
# because that would wipe the permission buttons the user needs to tap
LOCK_FILE="/tmp/claude-controller/permission-pending"
if [ -f "$LOCK_FILE" ]; then
  # Verify the lock is still held by a running process
  LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
  if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
    # Permission request is active - skip clearing, still send completion notification
    curl -s -X POST http://localhost:19847/notify \
      -H "Content-Type: application/json" \
      -d '{"message": "Claude finished", "playSound": false, "haptic": true}' \
      > /dev/null 2>&1
    exit 0
  else
    # Stale lockfile - clean it up
    rm -f "$LOCK_FILE"
  fi
fi

# 1. Clear any stale macro options from iPad
curl -s -X POST http://localhost:19847/macro-options \
  -H "Content-Type: application/json" \
  -d '{"options": [], "needsAttention": false}' \
  > /dev/null 2>&1

# 2. Send subtle completion notification (haptic only, no sound)
curl -s -X POST http://localhost:19847/notify \
  -H "Content-Type: application/json" \
  -d '{"message": "Claude finished", "playSound": false, "haptic": true}' \
  > /dev/null 2>&1

# Exit 0 to allow normal processing
exit 0
