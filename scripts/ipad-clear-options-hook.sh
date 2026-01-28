#!/bin/bash
# Hook script to clear iPad options after AskUserQuestion completes
# Called by Claude Code's PostToolUse hook for AskUserQuestion

# Clear the options by sending empty array
curl -s -X POST http://localhost:19847/macro-options \
  -H "Content-Type: application/json" \
  -d '{"options": [], "needsAttention": false}' \
  > /dev/null 2>&1

# Exit 0 to allow the tool to proceed
exit 0
