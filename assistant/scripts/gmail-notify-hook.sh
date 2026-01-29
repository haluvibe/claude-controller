#!/bin/bash
#
# Gmail Daemon Notification Hook
# Sends notifications to the iPad app via claude-controller when emails are processed
#
# This script can be called by the Gmail daemon to notify the user about:
# - Marketing emails found and unsubscribed
# - Errors during processing
# - Daily summary reports
#
# Usage: gmail-notify-hook.sh <event_type> [message]
#
# Event types:
#   unsubscribed  - Successfully unsubscribed from a sender
#   error         - Error during processing
#   summary       - Daily/periodic summary
#   started       - Daemon started
#   stopped       - Daemon stopped
#

EVENT_TYPE="${1:-info}"
MESSAGE="${2:-Gmail daemon notification}"

# Claude Controller iPad notification endpoint
NOTIFY_URL="http://localhost:19847/notify"

# Determine notification settings based on event type
case "$EVENT_TYPE" in
    unsubscribed)
        PLAY_SOUND="false"
        HAPTIC="true"
        ;;
    error)
        PLAY_SOUND="true"
        HAPTIC="true"
        ;;
    summary)
        PLAY_SOUND="true"
        HAPTIC="true"
        ;;
    started|stopped)
        PLAY_SOUND="false"
        HAPTIC="false"
        ;;
    *)
        PLAY_SOUND="false"
        HAPTIC="true"
        ;;
esac

# Escape message for JSON
ESCAPED_MESSAGE=$(echo "$MESSAGE" | jq -Rs '.' | sed 's/^"//;s/"$//')

# Send notification to iPad
curl -s -X POST "$NOTIFY_URL" \
    -H "Content-Type: application/json" \
    -d "{\"message\": \"$ESCAPED_MESSAGE\", \"playSound\": $PLAY_SOUND, \"haptic\": $HAPTIC}" \
    > /dev/null 2>&1

exit 0
