# Session Context - MCP Server Testing

## What We Built

An MCP server (`claude-controller`) that lets Claude send commands to an iPad via a macOS menu bar app.

## Architecture

```
Claude Code ←MCP→ MCP Server (Node.js) ←HTTP:19847→ macOS App ←Network→ iPad
```

## Available MCP Tools

| Tool | Purpose |
|------|---------|
| `send_options_to_ipad` | Display numbered options as tappable buttons on iPad |
| `clear_ipad_options` | Clear the macro bar |
| `notify_ipad` | Alert user with sound/haptic |
| `get_connection_status` | Check if iPad is connected |

## What Needs Testing

1. **Connection status** - Call `get_connection_status` to verify iPad is connected
2. **Send options** - Call `send_options_to_ipad` with test options, verify they appear on iPad
3. **User selection** - Tap an option on iPad, verify number + Enter is typed
4. **Clear options** - Call `clear_ipad_options`, verify bar disappears
5. **Notify** - Call `notify_ipad`, verify chime/haptic fires on iPad

## Test Commands

```
# Check connection
Use get_connection_status tool

# Send test options
Use send_options_to_ipad with:
{
  "options": [
    {"number": 1, "text": "Yes, proceed"},
    {"number": 2, "text": "No, cancel"},
    {"number": 3, "text": "Skip this step"}
  ],
  "needsAttention": true
}

# Send notification
Use notify_ipad with:
{
  "message": "Hello from Claude!",
  "playSound": true,
  "haptic": true
}
```

## Files Changed (uncommitted)

- `mcp-server/` - New MCP server (Node.js/TypeScript)
- `macOS/ClaudeController/Sources/Network/MCPBridgeServer.swift` - HTTP bridge
- `macOS/ClaudeController/Sources/App/ClaudeControllerApp.swift` - MCP integration
- `macOS/ClaudeController/Sources/Network/ConnectionManager.swift` - Notification support
- `iPadApp/Sources/Network/ConnectionManager.swift` - Notification handling
- `iPadApp/Sources/Managers/MacroManager.swift` - showNotification method

## Prerequisites for Testing

1. macOS ClaudeController app running (menu bar)
2. iPad TrackpadController app running and connected
3. Claude Code restarted to load MCP server
