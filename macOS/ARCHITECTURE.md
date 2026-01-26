# macOS Companion App Architecture

## Overview

The Claude Controller macOS companion app is a menu bar application that receives touch input from an iPad over the local network and injects corresponding mouse/keyboard events into macOS.

**Target Platform:** macOS 15+ (Sequoia)
**App Type:** Menu Bar App (LSUIElement)
**Distribution:** Direct distribution with notarization (NOT Mac App Store)

## Architecture Decision: Why Not Mac App Store?

### Critical Limitation: App Sandbox

The Mac App Store requires App Sandbox, which is **incompatible** with our core functionality:

1. **CGEvent Input Injection** - Requires direct system access to post synthetic mouse/keyboard events
2. **Accessibility APIs** - AXIsProcessTrusted and event posting require unsandboxed execution
3. **IOKit Display Access** - Multi-monitor configuration queries require unsandboxed access

### Distribution Strategy

| Approach | Pros | Cons |
|----------|------|------|
| **Direct Distribution (Chosen)** | Full CGEvent access, no sandbox restrictions | Manual updates, no App Store discovery |
| Mac App Store | Easy discovery, auto-updates | Cannot inject input events, blocked by sandbox |
| System Extension | Kernel-level access | Complex installation, user trust concerns |

**Recommendation:** Direct distribution with notarization and Sparkle for auto-updates.

## Component Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        ClaudeControllerApp                       │
│                     (SwiftUI App Lifecycle)                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  MenuBarView │  │ SettingsView │  │     SetupView        │  │
│  │  (Primary UI)│  │   (Window)   │  │ (First-run wizard)   │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                         Core Services                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌────────────────┐  │
│  │ ConnectionManager│  │  InputInjector  │  │ DisplayManager │  │
│  │   (Network)      │  │   (CGEvent)     │  │  (Multi-Mon)   │  │
│  └─────────────────┘  └─────────────────┘  └────────────────┘  │
│  ┌─────────────────┐  ┌─────────────────┐                      │
│  │GestureProcessor │  │PermissionManager│                      │
│  │(Touch→Gesture)  │  │   (System)      │                      │
│  └─────────────────┘  └─────────────────┘                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      macOS System Layer                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │   Network   │  │    CGEvent  │  │     Accessibility       │ │
│  │ (Bonjour)   │  │    (Input)  │  │        APIs             │ │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## Key Components

### 1. ClaudeControllerApp (Entry Point)

```swift
@main
struct ClaudeControllerApp: App {
    var body: some Scene {
        MenuBarExtra { MenuBarView() }
        Settings { SettingsView() }
        WindowGroup(id: "setup") { SetupView() }
    }
}
```

- **Type:** SwiftUI App with `@main` entry point
- **UI:** Menu bar extra with popover window
- **Lifecycle:** Handles system sleep/wake, login items

### 2. InputInjector (CGEvent-based)

**Purpose:** Inject mouse and keyboard events system-wide

**Key APIs Used:**
```swift
// Event creation
CGEvent(mouseEventSource:mouseType:mouseCursorPosition:mouseButton:)
CGEvent(keyboardEventSource:virtualKey:keyDown:)
CGEvent(scrollWheelEvent2Source:units:wheelCount:wheel1:wheel2:wheel3:)

// Event posting
event.post(tap: .cghidEventTap)
```

**Event Types Supported:**
- Mouse movement (relative and absolute)
- Mouse buttons (left, right, middle)
- Click counting (single, double, triple)
- Scroll (pixel and line-based)
- Pinch (zoom gestures)
- Rotation gestures
- Keyboard keys with modifiers

**Security Considerations:**
- Requires Accessibility permission
- Detects and respects secure input mode (password fields)
- Uses `hidSystemState` event source for hardware-like events

### 3. GestureProcessor

**Purpose:** Translate raw touch points to macOS gestures

**Input:** Array of `TouchPoint` from iPad
**Output:** `ProcessedGesture` ready for InputInjector

**Gesture Recognition:**
| Fingers | Action | macOS Equivalent |
|---------|--------|------------------|
| 1 | Tap | Left click |
| 1 | Double tap | Double click |
| 1 | Drag | Click and drag |
| 2 | Tap | Right click |
| 2 | Scroll | Two-finger scroll |
| 2 | Pinch | Zoom |
| 2 | Rotate | Rotation |
| 3 | Tap | Middle click |
| 3 | Swipe up | Mission Control |
| 3 | Swipe down | App Expose |
| 4 | Swipe left/right | Desktop switch |

### 4. ConnectionManager

**Purpose:** Bonjour service advertisement and connection handling

**Network Protocol:**
- Transport: TCP with keep-alive
- Discovery: Bonjour/mDNS (`_claudecontrol._tcp`)
- Port: 9847 (configurable)
- Encryption: Optional TLS

**Message Format:**
```
[1 byte: message type][1 byte: payload length][N bytes: payload]
```

**Message Types:**
| Code | Type | Direction |
|------|------|-----------|
| 0x01 | Handshake | Both |
| 0x02 | Handshake ACK | Mac→iPad |
| 0x10 | Touch Data | iPad→Mac |
| 0x11 | Gesture Data | iPad→Mac |
| 0x20 | Disconnect | Both |
| 0x30 | Ping | Mac→iPad |
| 0x31 | Pong | iPad→Mac |
| 0x40 | Configuration | Both |

**Connection Features:**
- Auto-reconnection with exponential backoff
- Latency monitoring via ping/pong
- Multiple iPad support (up to 4)
- Sleep/wake handling

### 5. DisplayManager

**Purpose:** Handle multi-monitor configurations

**Capabilities:**
- Display enumeration and configuration caching
- Screen edge detection for cursor transitions
- Coordinate space conversions
- Cursor acceleration matching
- Hot-plug display detection

### 6. PermissionManager

**Purpose:** Manage required system permissions

**Required Permissions:**
| Permission | API | Purpose |
|------------|-----|---------|
| Accessibility | AXIsProcessTrusted | Input injection |
| Local Network | Automatic | Bonjour discovery |

**Optional Permissions:**
| Permission | API | Purpose |
|------------|-----|---------|
| Automation | AppleScript | System gestures |

## Data Flow

```
iPad Touch Event
      │
      ▼
┌─────────────────┐
│ ConnectionManager│ ──── Receive TCP message
└─────────────────┘
      │
      │ TouchPoint[]
      ▼
┌─────────────────┐
│ GestureProcessor│ ──── Recognize gesture
└─────────────────┘
      │
      │ ProcessedGesture
      ▼
┌─────────────────┐
│  InputInjector  │ ──── Create CGEvent
└─────────────────┘
      │
      │ CGEvent
      ▼
┌─────────────────┐
│   macOS HID     │ ──── Post to system
└─────────────────┘
      │
      ▼
  Cursor moves / Click registered
```

## Permission Handling Strategy

### Accessibility Permission

```swift
// Check status
let trusted = AXIsProcessTrusted()

// Request with system dialog
let options = [kAXTrustedCheckOptionPrompt: true]
AXIsProcessTrustedWithOptions(options as CFDictionary)

// Open System Settings directly
let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
NSWorkspace.shared.open(url)
```

**User Flow:**
1. App detects accessibility not granted
2. Shows explanation in setup wizard
3. User clicks "Grant Permission"
4. System dialog appears with "Open System Settings"
5. User navigates to Privacy & Security → Accessibility
6. User toggles "Claude Controller" on
7. App detects permission granted (polling every 2 seconds)

### Local Network Permission

**Trigger:** Automatically prompted when Bonjour service starts
**No direct API** to check status - detected via connection success/failure

### Launch at Login

```swift
// macOS 13+ ServiceManagement
import ServiceManagement

try SMAppService.mainApp.register()   // Enable
try SMAppService.mainApp.unregister() // Disable
let status = SMAppService.mainApp.status // Check
```

## Distribution Requirements

### Notarization Checklist

1. **Code Signing**
   - Developer ID Application certificate
   - Hardened Runtime enabled
   - All frameworks signed

2. **Entitlements**
   - No sandbox (required for CGEvent)
   - Hardened runtime with minimum exceptions
   - Network entitlements documented

3. **Submission**
   - Upload to Apple notarization service
   - Wait for approval (usually < 1 hour)
   - Staple notarization ticket to app

### Build Commands

```bash
# Archive
xcodebuild archive \
  -scheme ClaudeController \
  -archivePath build/ClaudeController.xcarchive

# Export
xcodebuild -exportArchive \
  -archivePath build/ClaudeController.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist

# Notarize
xcrun notarytool submit build/export/ClaudeController.app \
  --apple-id "$APPLE_ID" \
  --password "$APP_PASSWORD" \
  --team-id "$TEAM_ID" \
  --wait

# Staple
xcrun stapler staple build/export/ClaudeController.app

# Create DMG
hdiutil create -volname "Claude Controller" \
  -srcfolder build/export/ClaudeController.app \
  -ov -format UDZO \
  ClaudeController.dmg
```

## Performance Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Touch-to-cursor latency | <16ms | One frame at 60Hz |
| Network round-trip | <10ms | Local network |
| Event injection | <1ms | CGEvent posting |
| Memory usage | <50MB | Menu bar app |
| CPU (idle) | <1% | When not in use |
| CPU (active) | <5% | During heavy gestures |

## File Structure

```
macOS/ClaudeController/
├── Package.swift
├── Sources/
│   ├── App/
│   │   └── ClaudeControllerApp.swift    # Entry point
│   ├── Core/
│   │   ├── InputInjector.swift          # CGEvent handling
│   │   ├── GestureProcessor.swift       # Touch→Gesture
│   │   └── DisplayManager.swift         # Multi-monitor
│   ├── Network/
│   │   └── ConnectionManager.swift      # Bonjour + connections
│   ├── Permissions/
│   │   └── PermissionManager.swift      # System permissions
│   ├── UI/
│   │   ├── MenuBarView.swift            # Menu bar popover
│   │   ├── SettingsView.swift           # Preferences
│   │   └── SetupView.swift              # First-run wizard
│   └── Extensions/
│       └── (utility extensions)
├── Resources/
│   ├── Info.plist                       # App configuration
│   └── ClaudeController.entitlements    # Permissions
└── Tests/
    └── ClaudeControllerTests/
```

## Security Considerations

1. **Secure Input Detection**
   - Check `IsSecureEventInputEnabled()` before injection
   - Refuse to type into password fields

2. **Network Security**
   - Local network only (no internet)
   - Optional TLS encryption
   - Device authentication via handshake

3. **Permission Boundaries**
   - Only inject events when permission granted
   - Clear user consent flow
   - No background data collection

4. **Code Signing**
   - Hardened runtime prevents tampering
   - Notarization verifies no malware
   - Gatekeeper protects users
