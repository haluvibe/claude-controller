---
name: gmail-unsubscribe
description: Check inbox and unsubscribe from marketing emails
allowed-tools: mcp__gmail__* Read Edit WebFetch
---

# Gmail Unsubscribe Skill

This skill has been consolidated into `/gmail-organizer`.

Run `/gmail-organizer` instead. It uses Gmail MCP tools directly (no custom code) and includes the same marketing detection heuristics and List-Unsubscribe header logic.

The shared memory file remains at:
`.claude/skills/gmail-unsubscribe/MEMORY.md`
