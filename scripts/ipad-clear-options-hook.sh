#!/bin/bash
set -euo pipefail
# Hook script to clear iPad options after AskUserQuestion completes
# Called by Claude Code's PostToolUse hook for AskUserQuestion

# Ensure lockfile directory has restricted permissions
mkdir -p /tmp/claude-controller 2>/dev/null && chmod 700 /tmp/claude-controller 2>/dev/null

# Check if a permission request is pending - don't clear the iPad UI if so
LOCK_FILE="/tmp/claude-controller/permission-pending"
if [ -f "$LOCK_FILE" ]; then
  LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
  if [ -n "$LOCK_PID" ] && kill -0 "$LOCK_PID" 2>/dev/null; then
    # Permission request is active - don't wipe the buttons
    exit 0
  else
    rm -f "$LOCK_FILE"
  fi
fi

# Clear the options by sending empty array
curl -s -X POST http://localhost:19847/macro-options \
  -H "Content-Type: application/json" \
  -d '{"options": [], "needsAttention": false}' \
  > /dev/null 2>&1

# Exit 0 to allow the tool to proceed
exit 0
