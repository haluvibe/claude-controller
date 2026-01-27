# Claude Controller MCP Server

MCP server that enables Claude to interact with your iPad trackpad controller.

## Features

- **Macro Keyboard**: Send numbered options to iPad for quick selection
- **Notifications**: Alert the user with sound and haptic feedback
- **Connection Status**: Check if iPad is connected

## Setup

### 1. Install the MCP Server

Add to your Claude Code configuration:

```bash
claude mcp add claude-controller -- node /path/to/claude-controller/mcp-server/dist/index.js
```

Or add manually to `~/.claude/settings.json`:

```json
{
  "mcpServers": {
    "claude-controller": {
      "command": "node",
      "args": ["/path/to/claude-controller/mcp-server/dist/index.js"]
    }
  }
}
```

### 2. Run the macOS App

Make sure ClaudeController.app is running in your menu bar. It listens on port 19847 for MCP commands.

### 3. Connect iPad

Open the TrackpadController app on your iPad. It will automatically connect to the Mac.

## Available Tools

### `send_options_to_ipad`
Send numbered options for quick selection. When you present choices like "1. Yes 2. No 3. Skip", call this tool to display them as buttons on the iPad. User taps a button → types the number + Enter.

```json
{
  "options": [
    {"number": 1, "text": "Yes, proceed"},
    {"number": 2, "text": "No, cancel"},
    {"number": 3, "text": "Skip"}
  ],
  "needsAttention": true
}
```

### `clear_ipad_options`
Clear the macro bar from the iPad.

### `notify_ipad`
Send a notification to the iPad to get the user's attention.

```json
{
  "message": "Task complete!",
  "playSound": true,
  "haptic": true
}
```

### `get_connection_status`
Check if the iPad is connected.

## Architecture

```
Claude Code ←MCP→ MCP Server ←HTTP→ macOS App ←Network→ iPad
```

The MCP server communicates with the ClaudeController macOS app via HTTP on localhost:19847. The macOS app then forwards commands to the connected iPad.
