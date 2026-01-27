# Claude Controller

A working iPad-to-macOS remote control application that transforms an iPad into a wireless trackpad and keyboard for controlling a Mac.

## What It Does

Claude Controller enables seamless control of a Mac computer from an iPad over a local WiFi network. The system consists of two apps:

1. **iPad App** - Captures trackpad/keyboard input and transmits over the network
2. **macOS Server App** - Receives input and injects it into the system as mouse/keyboard events

## Features

### iPad App
- Full-screen trackpad surface with visual feedback
- Virtual keyboard with function/modifier keys
- Multi-finger gesture recognition (1, 2, and 3-finger)
- Bonjour auto-discovery of Mac servers
- 120Hz message batching for smooth cursor movement
- Haptic feedback and Apple Pencil support

### macOS App
- Menu bar status indicator
- CGEvent-based input injection
- Multi-display support
- Automatic reconnection
- Accessibility permission setup wizard

## How It Works

```
iPad Touch → Gesture Recognition → JSON over TCP → macOS Server → CGEvent Injection → System Event
```

1. **Discovery**: macOS advertises via Bonjour (`_claudecontrol._tcp` on port 9847)
2. **Connection**: iPad connects and sends handshake with device info
3. **Input Capture**: Touch events captured and converted to gestures
4. **Transmission**: Messages batched at 120Hz, sent as length-prefixed JSON over TCP
5. **Injection**: macOS uses CGEvent API to post events to the system

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Networking | Apple Network.framework |
| Discovery | Bonjour/mDNS |
| Input Injection | CGEvent API |
| UI | SwiftUI |
| Protocol | JSON over TCP |

## Project Structure

```
claude-controller/
├── iPadApp/           # iPad/iOS 18+ app
├── macOS/             # macOS 15+ menu bar app
├── Shared/            # Protocol definition
├── design/            # UI/UX design docs
└── docs/              # Technical research
```

## Requirements

- **iPad**: iOS 18+, local network permission
- **Mac**: macOS 15+, Accessibility permission (for input injection)

## Performance Targets

| Metric | Target |
|--------|--------|
| Touch-to-cursor latency | <16ms |
| Network round-trip | <10ms |
| Memory (macOS) | <50MB |
| CPU (active) | <5% |
