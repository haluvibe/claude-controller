#!/bin/bash
# Hook script for Claude Code Stop events
# Clears iPad UI and notifies user that Claude has finished responding

# Read input from stdin (Claude Code passes JSON)
INPUT=$(cat)

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
