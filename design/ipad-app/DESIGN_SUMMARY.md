# iPad Trackpad/Keyboard App - Design Summary

## Overview

This document summarizes the complete design for an iPad app (iOS 18+) that transforms the iPad into a trackpad and keyboard for controlling a Mac.

---

## 1. UI/UX Design

### Layout Architecture

```
+----------------------------------------------------------+
|  Status Bar: Connection indicator, latency, settings     |
+----------------------------------------------------------+
|                                                          |
|                                                          |
|              FULL-SCREEN TRACKPAD SURFACE                |
|              (90% of screen area)                        |
|                                                          |
|                                                          |
|                               +------------------------+ |
|                               |  Scroll Edge (5%)      | |
+----------------------------------------------------------+
|  [Keyboard] [Click Mode] [Scroll Lock] [Drag] [Settings] |
+----------------------------------------------------------+
```

### Zone Configuration

| Zone | Location | Size | Purpose |
|------|----------|------|---------|
| Main | Center | 90% | Cursor movement |
| Right Edge | Right 5% | 5% width | Vertical scroll |
| Bottom Edge | Bottom 8% | 8% height | Horizontal scroll |
| Click Zone | Bottom 15% | 15% height | Physical click area |

### Visual Feedback

- **Touch Indicators**: Colored circles at touch points (blue=single, green=two-finger, orange=three-finger)
- **Ripple Effects**: Expanding circles on taps
- **Scroll Indicators**: Directional chevrons showing scroll direction/intensity
- **Haptic Feedback**: Configurable (light/medium/strong) for taps, clicks, scrolls

### Color Scheme

- Background: Subtle gradient (systemGray6 to systemGray5)
- Touch indicators: Blue/Green/Orange with 60% opacity
- Status bar: Semi-transparent systemBackground
- Toolbar: systemGray6 with rounded corners

---

## 2. Gesture Support

### Implemented Gestures

| Gesture | Fingers | Action |
|---------|---------|--------|
| Single tap | 1 | Left click |
| Double tap | 1 | Double click |
| Long press + drag | 1 | Drag and drop |
| Two-finger tap | 2 | Right click |
| Two-finger scroll | 2 | Vertical/horizontal scroll |
| Pinch | 2 | Zoom in/out |
| Three-finger up | 3 | Mission Control |
| Three-finger down | 3 | App Expose |
| Three-finger left/right | 3 | Switch Spaces |

### Gesture Detection

- **Movement threshold**: 5 points before considered "moved"
- **Scroll activation**: 8 points of movement
- **Pinch activation**: 15 points of distance change
- **Double-tap interval**: 0.3 seconds (configurable)
- **Long-press threshold**: 0.5 seconds (configurable)

### Acceleration

Four acceleration curves available:
- **None**: Linear 1:1 movement
- **Light**: 1.0 + velocity * 0.3
- **Medium**: 1.0 + velocity * 0.6 (default)
- **Heavy**: 1.0 + velocity * 1.0

---

## 3. Keyboard Integration

### Layout

- **Function row**: F1-F12 with media control icons
- **Number row**: With shifted symbols
- **QWERTY layout**: Standard Mac keyboard arrangement
- **Modifier row**: fn, control, option, command, arrows

### Features

- Shift toggles uppercase/symbols
- Modifier keys (Cmd, Opt, Ctrl) are sticky
- Arrow key cluster in bottom-right
- Haptic feedback on key press
- External keyboard detection (hides virtual keyboard)

### Presentation

- Sheet presentation with detents (medium/large)
- Drag indicator for dismissal
- Transparent background matching trackpad

---

## 4. iOS-Specific Considerations

### Multitasking Support

| Mode | Layout | Features |
|------|--------|----------|
| Full Screen | Full trackpad | All features |
| Split View | Adaptive + optional sidebar | Quick settings sidebar |
| Slide Over | Compact | Minimal toolbar |
| Stage Manager | Resizable window | Window commands |

### Apple Pencil Support

- Precision pointer mode with pressure sensitivity
- Light pressure = slower cursor (precision mode)
- Heavy pressure = normal speed
- Pencil double-tap = right click

### External Keyboard

- Automatic detection of hardware keyboard
- Virtual keyboard hidden when hardware keyboard attached
- Full keyboard shortcut support (Cmd+N, Cmd+K, etc.)

### Scene Restoration

- State persisted across app launches
- Last connected Mac remembered
- Settings preserved per-scene

---

## 5. Network Communication

### Protocol

- **Transport**: TCP with keep-alive
- **Discovery**: Bonjour (_claude-controller._tcp)
- **Port**: 51423
- **Framing**: Length-prefixed JSON messages

### Message Batching

- Messages batched at 120Hz (8ms intervals)
- Reduces network overhead for smooth cursor movement
- Timestamp included for latency calculation

### Message Types

```swift
enum MessageType {
    case ping           // Heartbeat/latency
    case mouseMove      // Cursor movement
    case leftClick      // Left mouse button
    case rightClick     // Right mouse button
    case doubleClick    // Double click
    case scroll         // Scroll wheel
    case pinchStart/Update/End  // Zoom gesture
    case dragStart/Move/End     // Drag operation
    case systemGesture  // Mission Control, etc.
    case keyPress       // Single key
    case text           // Text string
}
```

### Reconnection

- Exponential backoff: 2^attempt seconds
- Maximum 5 reconnection attempts
- Status indicator shows reconnecting state

---

## 6. Required Capabilities

### Info.plist Keys

| Key | Value | Purpose |
|-----|-------|---------|
| NSLocalNetworkUsageDescription | String | Local network access prompt |
| NSBonjourServices | [_claude-controller._tcp] | Service discovery |
| UIBackgroundModes | [processing, fetch] | Background network |
| UIRequiresFullScreen | false | Multitasking support |
| UIApplicationSupportsMultipleScenes | true | Stage Manager |
| UISupportsPencilInput | true | Apple Pencil |

### Entitlements

| Entitlement | Purpose |
|-------------|---------|
| com.apple.developer.networking.multicast | Bonjour discovery |
| keychain-access-groups | Secure credential storage |
| com.apple.developer.associated-domains | Universal Links |
| com.apple.developer.siri | Voice commands |

---

## 7. Configuration Options

### Sensitivity

| Setting | Range | Default |
|---------|-------|---------|
| Cursor sensitivity | 0.5x - 3.0x | 1.0x |
| Scroll sensitivity | 0.5x - 3.0x | 1.0x |
| Acceleration curve | none/light/medium/heavy | medium |

### Timing

| Setting | Range | Default |
|---------|-------|---------|
| Double-tap interval | 0.2s - 0.6s | 0.3s |
| Long-press threshold | 0.3s - 1.0s | 0.5s |
| Drag threshold | 0.05s - 0.3s | 0.15s |

### Feedback

| Setting | Options | Default |
|---------|---------|---------|
| Haptic intensity | off/light/medium/strong | medium |
| Touch indicators | on/off | on |
| Gesture hints | on/off | on (first use) |

### Presets

- **Default**: Balanced settings
- **Precision**: Lower sensitivity, no acceleration
- **Fast**: Higher sensitivity, heavy acceleration
- **Accessibility**: Longer timings, stronger haptics

---

## 8. File Structure

```
design/ipad-app/
├── DESIGN_SUMMARY.md          # This document
├── Info.plist                 # App configuration
├── ClaudeController.entitlements
├── TrackpadView.swift         # Main trackpad UI
├── TrackpadGestureView.swift  # Gesture recognition
├── TrackpadViewModel.swift    # State management
├── TrackpadZoneConfig.swift   # Zone configuration
├── VisualFeedback.swift       # Touch indicators, haptics
├── KeyboardView.swift         # Virtual keyboard
├── SettingsView.swift         # Settings UI
├── ConnectionManager.swift    # Network layer
└── MultitaskingSupport.swift  # iPadOS features
```

---

## 9. Future Enhancements

### Planned

- Handoff integration (seamless Mac/iPad switching)
- Siri Shortcuts support
- Widget for quick connection
- Apple Watch companion (connection status)
- NFC pairing with Mac

### Potential

- Gaming mode (lower latency, raw input)
- Drawing tablet mode (pressure-sensitive input)
- Accessibility mode (voice control, switch control)
- Multi-Mac support (switch between Macs)

---

## 10. Implementation Priority

### Phase 1 (MVP)
1. Basic trackpad surface with cursor movement
2. Single/double tap for clicks
3. Two-finger scroll
4. Basic keyboard
5. Network connection to Mac

### Phase 2 (Enhanced)
1. Right-click (two-finger tap)
2. Drag and drop
3. Pinch to zoom
4. Three-finger gestures
5. Settings UI

### Phase 3 (Polish)
1. Visual feedback system
2. Apple Pencil support
3. Multitasking layouts
4. Scene restoration
5. Presets and advanced settings
