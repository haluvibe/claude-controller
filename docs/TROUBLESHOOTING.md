# ClaudeController Troubleshooting Guide

> **For Claude**: This document captures known issues and solutions for the ClaudeController project. Read this before debugging connectivity or permission issues.

## Project Overview

- **iPad App**: `TrackpadController` - sends touch/gesture data to Mac
- **macOS App**: `ClaudeController` - receives data and injects input via Accessibility APIs
- **Connection**: Bonjour discovery over WiFi, TCP on port 9847

---

## 🚨 Issue #1: Accessibility Permissions Keep Breaking

### Symptoms
- iPad shows "Connected" but trackpad doesn't move cursor
- macOS app runs but doesn't respond to input
- Previously working setup suddenly stops

### Root Cause
macOS Accessibility permissions are tied to the **code signature** of the executable. When you:
- Rebuild with `swift build`
- Copy a new binary into an existing `.app` bundle
- Run from a different path (`.build/debug/` vs `/Applications/`)

...macOS treats it as a **different app** and revokes permissions.

### Solution: Use the DMG Install

**ALWAYS use the DMG for the macOS app:**

```bash
cd /Users/paulhayes/automations/claude-controller/macOS/ClaudeController
./build-dmg.sh
```

Then:
1. Open `ClaudeController.dmg`
2. Drag to `/Applications`
3. Run from `/Applications/ClaudeController.app`
4. Grant Accessibility permissions once

**The `/Applications` install persists permissions across rebuilds.**

### If You Must Debug with `swift run`

The debug executable at `.build/arm64-apple-macosx/debug/ClaudeController` needs **separate** Accessibility permissions. Add it to:

**System Settings > Privacy & Security > Accessibility**

Use Finder's "Go > Go to Folder" to navigate to:
```
/Users/paulhayes/automations/claude-controller/macOS/ClaudeController/.build/arm64-apple-macosx/debug/
```

---

## 🚨 Issue #2: iPad Shows "Connected" But No TCP Connection

### Symptoms
- iPad UI shows green dot and "Connected"
- `lsof -i :9847` only shows `LISTEN`, no `ESTABLISHED`
- Trackpad doesn't work

### Diagnostic Commands

```bash
# Check if macOS app is listening
lsof -i :9847

# Check Bonjour advertising
dns-sd -B _claudecontrol._tcp local.

# Check Mac IP
ipconfig getifaddr en0
```

### Common Causes

1. **Different networks**: iPad and Mac must be on same WiFi (same subnet)
2. **macOS app not running**: Check menu bar for hand icon
3. **Firewall blocking**: Check System Settings > Network > Firewall
4. **Stale connection state**: Restart both apps

### Solution

1. Verify same network: Mac and iPad should have similar IPs (e.g., both 192.168.20.x)
2. Restart macOS app from `/Applications`
3. Force-quit and relaunch iPad app
4. Check `lsof -i :9847` shows `ESTABLISHED` after iPad connects

---

## 🚨 Issue #3: Code Signature Invalid After Copying Binary

### Symptoms
- App crashes on launch
- "App is damaged" error
- Accessibility permissions silently fail

### Root Cause
Copying a new executable into an existing `.app` bundle breaks the code signature.

### Solution

After copying a binary, re-sign the app:

```bash
codesign --force --deep --sign - /path/to/App.app
```

Or better: **use the `build-dmg.sh` script** which handles signing automatically.

---

## 🚨 Issue #4: Multiple ClaudeController Processes

### Symptoms
- Confusing behavior
- Port already in use errors
- Multiple menu bar icons

### Diagnostic

```bash
ps aux | grep -i ClaudeController
```

### Solution

Kill all instances and start fresh:

```bash
pkill -f ClaudeController
open /Applications/ClaudeController.app
```

---

## Build Commands Reference

### macOS App (Recommended)

```bash
cd /Users/paulhayes/automations/claude-controller/macOS/ClaudeController
./build-dmg.sh
# Then install from DMG to /Applications
```

### macOS App (Debug)

```bash
cd /Users/paulhayes/automations/claude-controller/macOS/ClaudeController
swift build
swift run  # Needs separate Accessibility permissions!
```

### iPad App

Use Xcode or the MCP tools:
```
mcp__xcodebuildmcp__build_device
mcp__xcodebuildmcp__install_app_device
mcp__xcodebuildmcp__launch_app_device
```

---

## Quick Health Check

Run these to verify everything is working:

```bash
# 1. macOS app running?
ps aux | grep -i "[C]laudeController"

# 2. Listening on port?
lsof -i :9847

# 3. Bonjour advertising?
dns-sd -B _claudecontrol._tcp local.

# 4. iPad connected? (should show ESTABLISHED)
lsof -i :9847 | grep ESTABLISHED
```

---

## Key Files

| File | Purpose |
|------|---------|
| `macOS/ClaudeController/build-dmg.sh` | Creates installable DMG |
| `macOS/ClaudeController/Sources/Core/InputInjector.swift` | Injects mouse/keyboard (needs Accessibility) |
| `iPadApp/Sources/Network/ConnectionManager.swift` | Handles Bonjour + TCP |

---

## Summary: The Golden Rule

**For reliable operation:**
1. Build macOS app with `./build-dmg.sh`
2. Install to `/Applications`
3. Run from `/Applications`
4. Grant Accessibility permissions ONCE
5. Rebuild DMG when code changes, reinstall to `/Applications`

This keeps the app identity stable and permissions persist.
