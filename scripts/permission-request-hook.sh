#!/bin/bash
# Hook script for Claude Code PermissionRequest events
# Sends permission requests to iPad with options for user selection
# Returns the iPad's decision to Claude Code

# Read the tool input from stdin (Claude Code passes JSON)
TOOL_INPUT=$(cat)

# Extract tool name and command/input
TOOL_NAME=$(echo "$TOOL_INPUT" | jq -r '.tool_name // "Unknown"')

# Try to extract command for Bash, or stringify the input for other tools
DETAILS=$(echo "$TOOL_INPUT" | jq -r '
  if .tool_input.command then
    .tool_input.command
  elif .tool_input.file_path then
    .tool_input.file_path
  elif .tool_input then
    (.tool_input | tostring)
  else
    "No details"
  end
' | head -c 200)

# Escape details for JSON
DETAILS_ESCAPED=$(echo "$DETAILS" | jq -Rs '.')

# Build the options array - standard permission options
OPTIONS='[
  {"number": 1, "text": "Yes", "decision": "allow"},
  {"number": 2, "text": "Yes, always", "decision": "allowAlways"},
  {"number": 3, "text": "No", "decision": "deny"}
]'

# Build the request payload
PAYLOAD=$(jq -n \
  --arg tool "$TOOL_NAME" \
  --argjson details "$DETAILS_ESCAPED" \
  --argjson options "$OPTIONS" \
  '{tool: $tool, details: $details, options: $options}')

# Send blocking request to macOS app - waits for iPad response
# Timeout: 5 minutes (300 seconds)
RESPONSE=$(curl -s --max-time 300 -X POST http://localhost:19847/permission-request \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" 2>/dev/null)

# Check if curl succeeded
CURL_EXIT=$?
if [ $CURL_EXIT -ne 0 ]; then
  # If Mac app not running or timeout, deny by default
  echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"Mac controller not available"}}}'
  exit 0
fi

# Extract decision from response
DECISION=$(echo "$RESPONSE" | jq -r '.decision // "deny"')

case "$DECISION" in
  "allow")
    echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'
    ;;
  "allowAlways")
    # Return allow to Claude Code immediately
    echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"allow"}}}'

    # Build permission pattern based on tool type
    case "$TOOL_NAME" in
      "Bash")
        # Extract the command name (first word, basename only)
        COMMAND=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // ""' | awk '{print $1}' | xargs basename 2>/dev/null)
        if [ -n "$COMMAND" ]; then
          PATTERN="Bash($COMMAND:*)"
        else
          PATTERN="Bash"
        fi
        ;;
      "Write"|"Edit"|"NotebookEdit")
        # For file operations, just allow the tool type
        PATTERN="$TOOL_NAME"
        ;;
      *)
        # Default: allow the tool by name
        PATTERN="$TOOL_NAME"
        ;;
    esac

    # Persist to project-local settings file
    SETTINGS_DIR=".claude"
    SETTINGS_FILE="$SETTINGS_DIR/settings.local.json"

    # Create .claude directory if needed
    mkdir -p "$SETTINGS_DIR" 2>/dev/null

    # Create settings file if it doesn't exist
    if [ ! -f "$SETTINGS_FILE" ]; then
      echo '{"permissions":{"allow":[]}}' > "$SETTINGS_FILE"
    fi

    # Add pattern to permissions.allow array (avoid duplicates)
    if [ -n "$PATTERN" ]; then
      jq --arg pattern "$PATTERN" '
        .permissions.allow = ((.permissions.allow // []) + [$pattern] | unique)
      ' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" 2>/dev/null && mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
    fi
    ;;
  *)
    REASON=$(echo "$RESPONSE" | jq -r '.reason // "Denied via iPad"')
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PermissionRequest\",\"decision\":{\"behavior\":\"deny\",\"message\":\"$REASON\"}}}"
    ;;
esac
