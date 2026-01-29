#!/bin/bash
# Hook script for Claude Code UserPromptSubmit events
# Clears iPad state when user submits a new prompt to ensure clean UI

# Read input from stdin (Claude Code passes JSON)
INPUT=$(cat)

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
    # Stale lockfile - clean it up
    rm -f "$LOCK_FILE"
  fi
fi

# Clear any stale macro options from iPad
# This ensures previous question options don't persist into new interactions
curl -s -X POST http://localhost:19847/macro-options \
  -H "Content-Type: application/json" \
  -d '{"options": [], "needsAttention": false}' \
  > /dev/null 2>&1

# Exit 0 to allow the prompt to proceed
exit 0
