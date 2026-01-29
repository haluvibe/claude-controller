#!/bin/bash
# Hook script for Claude Code PermissionRequest events
# Sends permission requests to iPad with options for user selection
# Returns the iPad's decision to Claude Code

# Read the tool input from stdin (Claude Code passes JSON)
TOOL_INPUT=$(cat)

# Create a lockfile so other hooks (stop, user-prompt) don't clear the iPad UI
# while we're waiting for a permission response
LOCK_DIR="/tmp/claude-controller"
mkdir -p "$LOCK_DIR" 2>/dev/null && chmod 700 "$LOCK_DIR" 2>/dev/null
LOCK_FILE="$LOCK_DIR/permission-pending"
echo $$ > "$LOCK_FILE"
cleanup() { rm -f "$LOCK_FILE"; }
trap cleanup EXIT

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

# --- Determine which options to show ---
# Check if "Yes Always" would be redundant (pattern already in allow list)
SETTINGS_FILE=".claude/settings.local.json"
SHOW_ALWAYS=true

if [ -f "$SETTINGS_FILE" ]; then
  if [ "$TOOL_NAME" = "Bash" ]; then
    # Extract the command name (first word, basename) - same logic used to build the allow pattern
    COMMAND=$(echo "$TOOL_INPUT" | jq -r '.tool_input.command // ""' | awk '{print $1}' | xargs basename 2>/dev/null)
    if [ -n "$COMMAND" ]; then
      PATTERN="Bash($COMMAND:*)"
      EXISTING=$(jq -r --arg p "$PATTERN" '.permissions.allow // [] | map(select(. == $p)) | length' "$SETTINGS_FILE" 2>/dev/null)
      if [ "$EXISTING" -gt 0 ] 2>/dev/null; then
        SHOW_ALWAYS=false
      fi
    fi
  else
    # For Write/Edit/NotebookEdit, check if the tool name is already allowed
    EXISTING=$(jq -r --arg p "$TOOL_NAME" '.permissions.allow // [] | map(select(. == $p)) | length' "$SETTINGS_FILE" 2>/dev/null)
    if [ "$EXISTING" -gt 0 ] 2>/dev/null; then
      SHOW_ALWAYS=false
    fi
  fi
fi

# Build the options array - only include "Yes Always" when it would add a new pattern
if [ "$SHOW_ALWAYS" = true ]; then
  OPTIONS='[
    {"number": 1, "text": "Yes", "decision": "allow"},
    {"number": 2, "text": "Yes, always", "decision": "allowAlways"},
    {"number": 3, "text": "No", "decision": "deny"}
  ]'
else
  OPTIONS='[
    {"number": 1, "text": "Yes", "decision": "allow"},
    {"number": 2, "text": "No", "decision": "deny"}
  ]'
fi

# Build the request payload
PAYLOAD=$(jq -n \
  --arg tool "$TOOL_NAME" \
  --argjson details "$DETAILS_ESCAPED" \
  --argjson options "$OPTIONS" \
  '{tool: $tool, details: $details, options: $options}')

# --- Pre-flight: verify Mac app is reachable before blocking ---
HEALTH=$(curl -s --max-time 2 http://localhost:19847/health 2>/dev/null)
if [ -z "$HEALTH" ]; then
  # First attempt failed - retry once after a brief pause
  sleep 0.5
  HEALTH=$(curl -s --max-time 2 http://localhost:19847/health 2>/dev/null)
  if [ -z "$HEALTH" ]; then
    echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"Mac controller not available"}}}'
    exit 0
  fi
fi

# Send blocking request to macOS app - waits for iPad response
# Retry up to 2 times on connection failure (not on timeout)
MAX_RETRIES=2
ATTEMPT=0
RESPONSE=""
CURL_EXIT=1

while [ $ATTEMPT -le $MAX_RETRIES ] && [ $CURL_EXIT -ne 0 ]; do
  RESPONSE=$(curl -s --max-time 300 -X POST http://localhost:19847/permission-request \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" 2>/dev/null)
  CURL_EXIT=$?

  if [ $CURL_EXIT -ne 0 ] && [ $ATTEMPT -lt $MAX_RETRIES ]; then
    sleep 1
  fi
  ATTEMPT=$((ATTEMPT + 1))
done

if [ $CURL_EXIT -ne 0 ]; then
  echo '{"hookSpecificOutput":{"hookEventName":"PermissionRequest","decision":{"behavior":"deny","message":"Mac controller not available after retries"}}}'
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
