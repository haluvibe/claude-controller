#!/bin/bash
# Hook script for Claude Code UserPromptSubmit events
# Clears iPad state when user submits a new prompt to ensure clean UI

# Read input from stdin (Claude Code passes JSON)
INPUT=$(cat)

# Clear any stale macro options from iPad
# This ensures previous question options don't persist into new interactions
curl -s -X POST http://localhost:19847/macro-options \
  -H "Content-Type: application/json" \
  -d '{"options": [], "needsAttention": false}' \
  > /dev/null 2>&1

# Exit 0 to allow the prompt to proceed
exit 0
