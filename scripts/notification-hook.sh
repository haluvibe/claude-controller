#!/bin/bash
# Hook script for Claude Code Notification events
# Sends notifications to iPad for user attention
# Handles: idle_prompt, elicitation_dialog, and other notification types

# Read the notification from stdin (Claude Code passes JSON)
INPUT=$(cat)

# Extract notification type and message
TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')
MESSAGE=$(echo "$INPUT" | jq -r '.message // "Claude Code notification"')

# Only handle notification types we care about
case "$TYPE" in
  "idle_prompt")
    # Claude has been waiting for input for 60+ seconds
    curl -s -X POST http://localhost:19847/notify \
      -H "Content-Type: application/json" \
      -d '{"message": "Claude is waiting for your input", "playSound": true, "haptic": true}' \
      > /dev/null 2>&1
    ;;
  "elicitation_dialog")
    # MCP tool needs input from user
    curl -s -X POST http://localhost:19847/notify \
      -H "Content-Type: application/json" \
      -d '{"message": "MCP tool needs input", "playSound": true, "haptic": true}' \
      > /dev/null 2>&1
    ;;
  "permission_prompt")
    # Backup notification for permission dialogs (PermissionRequest hook is primary)
    # Skip - handled by PermissionRequest hook
    ;;
  *)
    # Generic notification - forward to iPad
    ESCAPED_MESSAGE=$(echo "$MESSAGE" | jq -Rs '.' | sed 's/^"//;s/"$//')
    curl -s -X POST http://localhost:19847/notify \
      -H "Content-Type: application/json" \
      -d "{\"message\": \"$ESCAPED_MESSAGE\", \"playSound\": false, \"haptic\": true}" \
      > /dev/null 2>&1
    ;;
esac

# Exit 0 to allow normal processing
exit 0
