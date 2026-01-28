# Session Context - iPad Options Hook Integration

## What We're Doing

Implementing automatic iPad options integration so that whenever Claude uses `AskUserQuestion`, the options are automatically sent to the iPad as tappable buttons.

## Approach: Claude Code Hooks (Not CLAUDE.md)

We're using Claude Code's hook system instead of CLAUDE.md instructions because hooks are more reliable and automatic.

## What Was Created

### 1. Hook Script
**File:** `scripts/ipad-options-hook.sh`

```bash
#!/bin/bash
# Extracts options from AskUserQuestion and sends to iPad
# Reads tool_input JSON from stdin, extracts questions[0].options
# Sends to macOS app at localhost:19847/macro-options
```

### 2. Hook Configuration
**File:** `.claude/settings.local.json`

Added `PreToolUse` hook for `AskUserQuestion`:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "AskUserQuestion",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/paulhayes/automations/claude-controller/scripts/ipad-options-hook.sh"
          }
        ]
      }
    ]
  }
}
```

## Next Steps After Restart

1. **Test the hook** - Ask a question with options to see if iPad receives them automatically
2. **If it works** - Done! The integration is complete
3. **If it doesn't work** - `AskUserQuestion` may not be hookable yet (GitHub issue #12605 requests this feature). Alternative approaches:
   - Use `PostToolUse` instead of `PreToolUse`
   - Try different matcher patterns
   - Fall back to CLAUDE.md instructions as last resort

## How It Should Work

```
Claude calls AskUserQuestion
    ↓
PreToolUse hook fires
    ↓
ipad-options-hook.sh runs
    ↓
Script extracts options from JSON input
    ↓
Script POSTs to localhost:19847/macro-options
    ↓
macOS app forwards to iPad
    ↓
iPad displays tappable buttons
```

## Test Command

After restart, just ask me any question with options like:
"Do you want to proceed? 1. Yes 2. No"

The iPad should automatically show buttons without needing to manually call `send_options_to_ipad`.
