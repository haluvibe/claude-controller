#!/bin/bash
# Hook script to send AskUserQuestion options to iPad
# Called by Claude Code's PreToolUse hook for AskUserQuestion

# Read the tool input from stdin (Claude Code passes JSON)
TOOL_INPUT=$(cat)

# Extract options from the AskUserQuestion input
# The input contains questions[].options[] array
OPTIONS_JSON=$(echo "$TOOL_INPUT" | jq -r '
  [.tool_input.questions[0].options | to_entries | .[] | {
    number: (.key + 1),
    text: .value.label
  }]
')

# Only proceed if we got valid options
if [ "$OPTIONS_JSON" != "null" ] && [ "$OPTIONS_JSON" != "[]" ]; then
  # Send to iPad via macOS app
  curl -s -X POST http://localhost:19847/macro-options \
    -H "Content-Type: application/json" \
    -d "{\"options\": $OPTIONS_JSON, \"needsAttention\": true}" \
    > /dev/null 2>&1
fi

# Exit 0 to allow the tool to proceed
exit 0
