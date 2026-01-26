# Technical Landscape: iPad Trackpad/Keyboard App for macOS

## Executive Summary

This document analyzes the technical approaches for building an iPad app that functions as a trackpad and keyboard input device for macOS. The research covers communication protocols, existing solutions, Apple frameworks, and latency requirements.

---

## 1. Communication Protocols

### 1.1 Bluetooth HID (Human Interface Device)

**Overview:**
The Bluetooth HID Profile defines how devices communicate as input peripherals (keyboards, mice, trackpads).

**Key Specifications:**
- **HID Profile 1.0**: Standard Bluetooth Classic HID
- **HOGP (HID over GATT)**: BLE-based HID using Bluetooth Low Energy
- **Service UUID**: `0x1812` (BLE HID Service)

**Critical Limitation for iOS/iPadOS:**
Apple explicitly blocks iOS apps from registering as BLE HID peripherals. When attempting to add the `0x1812` service via CoreBluetooth:

```
Error Domain=CBErrorDomain Code=8 "The specified UUID is not allowed for this operation."
```

**Implications:**
- iOS cannot present itself as a Bluetooth keyboard/mouse using standard HID profiles
- This is an intentional security restriction by Apple
- Some apps work around this by operating as a "central" connecting to a Mac server app

**Sources:**
- [Apple Developer Forums - iOS HID Support](https://developer.apple.com/forums/thread/725238)
- [Bluetooth HID Profile Specification](https://www.bluetooth.com/specifications/specs/human-interface-device-profile-1-0/)

---

### 1.2 WiFi / Local Network Communication

**Bonjour / mDNS Service Discovery:**

Bonjour is Apple's zero-configuration networking implementation using multicast DNS (mDNS).

**How It Works:**
1. **Service Advertisement**: macOS server app advertises a service (e.g., `_trackpad._tcp`)
2. **Discovery**: iOS app browses for services on local network
3. **Connection**: Establishes direct socket connection for data transfer

**Key APIs:**
```swift
// iOS - Discovering Services
let browser = NWBrowser(for: .bonjour(type: "_trackpad._tcp", domain: nil), using: .tcp)
browser.browseResultsChangedHandler = { results, changes in
    // Handle discovered services
}

// macOS - Advertising Service
let listener = try NWListener(using: .tcp)
listener.service = NWListener.Service(name: "TrackpadServer", type: "_trackpad._tcp")
```

**Privacy Requirements (iOS 14+):**
- Apps must declare Bonjour services in `Info.plist`
- Users see a "Local Network" permission prompt
- `NSLocalNetworkUsageDescription` key required

**Sources:**
- [Apple Bonjour Documentation](https://developer.apple.com/documentation/foundation/bonjour)
- [Network.framework NWListener](https://developer.apple.com/documentation/network/nwlistener)

---

### 1.3 Network.framework (Recommended)

Apple's modern networking API, recommended over MultipeerConnectivity for new development.

**Advantages:**
- Full control over peer-to-peer behavior via `includePeerToPeer` property
- Supports TCP, UDP, QUIC, and WebSocket
- Better latency and throughput than MultipeerConnectivity
- Compatible with Bonjour service discovery

**Protocol Options for Low Latency:**

| Protocol | Reliability | Latency | Use Case |
|----------|-------------|---------|----------|
| UDP | Best-effort | Lowest | Mouse movement, continuous input |
| TCP | Reliable | Higher | Keyboard input, commands |
| QUIC | Configurable | Medium | Hybrid approach |

**UDP Implementation Example:**
```swift
// iOS Client
let connection = NWConnection(
    host: NWEndpoint.Host("192.168.1.100"),
    port: 8080,
    using: .udp
)

// Send mouse movement (no acknowledgment needed)
let data = MouseEvent(dx: 5, dy: -3).encoded()
connection.send(content: data, completion: .idempotent)

// macOS Server
let params = NWParameters.udp
params.includePeerToPeer = true
let listener = try NWListener(using: params, on: 8080)
```

**Critical UDP Consideration:**
- Maximum safe packet size: 1024 bytes
- Cannot cross UDP packet boundaries in receive calls
- Best for frequent, small updates (mouse deltas)

**Sources:**
- [Network.framework WWDC 2018](https://developer.apple.com/videos/play/wwdc2018/715/)
- [Building Server-Client with Network.framework](https://rderik.com/blog/building-a-server-client-aplication-using-apple-s-network-framework/)
- [TN3151 - Choosing the Right Networking API](https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api)

---

### 1.4 MultipeerConnectivity Framework (Legacy)

**Status:** Apple recommends migrating away from this framework.

**Issues:**
- Opinionated symmetric peer model
- Poor throughput despite reasonable latency
- Reliability problems unfixed for years
- Enforces peer-to-peer (no opt-out)

**When to Consider:**
- Quick prototyping
- Apps already using it

**Migration Path:** See Apple's guidance on moving to Network.framework.

**Sources:**
- [Apple Developer Forums - Moving from MPC](https://developer.apple.com/forums/thread/776069)
- [MultipeerConnectivity Documentation](https://developer.apple.com/documentation/multipeerconnectivity)

---

### 1.5 Apple Continuity / Universal Control Architecture

**How Universal Control Works:**

1. **Discovery**: Bluetooth detects nearby devices (within 30 feet)
2. **Connection Trigger**: User drags cursor to screen edge
3. **Transport**: Wi-Fi Direct connection established
4. **Authentication**: Same Apple ID with two-factor authentication

**Technical Requirements:**
- Both devices signed into same Apple ID
- Bluetooth and WiFi enabled
- Handoff enabled in settings
- Within 10 meters proximity

**Key Insight:**
Universal Control does NOT use Ultra Wideband (UWB) for location detection. It uses assumption-based connection (last interacted device) when cursor crosses screen edge.

**Private API Consideration:**
Continuity APIs are private and undocumented. The [furiousMAC/continuity](https://github.com/furiousMAC/continuity) project reverse-engineered the BLE protocol, but using private APIs risks App Store rejection.

**Sources:**
- [MacRumors Universal Control Guide](https://www.macrumors.com/guide/universal-control/)
- [Apple Support - Universal Control](https://support.apple.com/en-us/102459)
- [Continuity Protocol Reverse Engineering](https://github.com/furiousMAC/continuity)

---

## 2. Existing Solutions Analysis

### 2.1 Remote Mouse / Mobile Mouse

**Architecture:** Client-Server over WiFi

**How It Works:**
1. iOS app captures touch input, gestures, gyroscope/accelerometer data
2. Data transmitted over WiFi to desktop server app
3. Server translates to native mouse/keyboard events

**Connection Methods:**
- WiFi (same network)
- Bluetooth
- WiFi-Direct
- USB (some apps)

**macOS Server Requirements:**
- Accessibility permission for input injection
- Runs as background service/menu bar app

**Sources:**
- [Remote Mouse](https://www.remotemouse.net/)
- [Mobile Mouse](https://mobilemouse.com/)

---

### 2.2 Luna Display

**Architecture:** Hardware dongle + proprietary compression

**Technical Approach:**
- USB-C/Mini DisplayPort dongle acts as "headless display"
- Uses DisplayPort Alt Mode for video capture
- **LIQUID** proprietary video compression technology
- Velocity Control adapts to network conditions

**Performance:**
| Connection | Latency |
|------------|---------|
| Wired (Thunderbolt/Ethernet/USB) | 1-4 ms |
| WiFi | 7-25 ms |

**Key Differentiator:**
Hardware provides true GPU acceleration, which software-only solutions lack.

**Sources:**
- [Luna Display](https://astropad.com/product/lunadisplay/)
- [TidBITS Review](https://tidbits.com/2018/12/07/luna-display-turns-an-ipad-into-a-responsive-mac-screen/)

---

### 2.3 Duet Display

**Architecture:** Software-only (with optional hardware acceleration)

**Approach:**
- Pure software solution
- Recent versions added Mac hardware acceleration
- Wired (basic) or wireless (Duet Air tier)

**Comparison:**
Luna Display focuses on hardware-accelerated quality; Duet offers software flexibility at lower cost.

**Sources:**
- [Duet Display](https://www.duetdisplay.com/)
- [Duet vs Luna Comparison](https://www.duetdisplay.com/blog/duet-display-vs-luna-display)

---

## 3. Apple Frameworks (iOS 18+ / macOS 15+)

### 3.1 Network.framework

**Current Status:** Recommended API for networking

**Key Classes:**
- `NWConnection` - Bidirectional connection (TCP/UDP/QUIC)
- `NWListener` - Server listening for connections
- `NWBrowser` - Bonjour service discovery
- `NWPathMonitor` - Network reachability

**Peer-to-Peer Support:**
```swift
let params = NWParameters.udp
params.includePeerToPeer = true  // Enable P2P WiFi
```

**iOS 18 / macOS 15 Notes:**
- Local network privacy changes introduced bugs (FB14321888)
- Permission state can desync after toggling
- Workaround: Toggle permission off/on in Settings

---

### 3.2 CoreBluetooth

**Capability:** BLE Central and Peripheral modes

**Limitation for HID:**
iOS blocks `0x1812` HID service UUID in peripheral mode. Cannot directly emulate keyboard/mouse via BLE.

**Workaround Approach:**
- iPad acts as BLE **Central**
- macOS acts as BLE **Peripheral** (advertising a custom service)
- Custom protocol over BLE characteristics
- macOS server translates to CGEvents

**BLE Latency:**
Adds 8-30ms over Bluetooth transmission alone.

---

### 3.3 macOS Input Injection APIs

**Recommended: CGEvent API**

```swift
import CoreGraphics

// Mouse Movement
let moveEvent = CGEvent(
    mouseEventSource: nil,
    mouseType: .mouseMoved,
    mouseCursorPosition: CGPoint(x: 500, y: 300),
    mouseButton: .left
)
moveEvent?.post(tap: .cghidEventTap)

// Keyboard Event
let keyDown = CGEvent(
    keyboardEventSource: nil,
    virtualKey: CGKeyCode(0),  // 'a' key
    keyDown: true
)
keyDown?.post(tap: .cghidEventTap)
```

**Required Permissions:**
1. **Accessibility**: System Settings > Privacy & Security > Accessibility
2. **Input Monitoring**: For event taps (listening)

**Permission Check APIs:**
```swift
// Check if permission granted
let hasAccess = CGPreflightPostEventAccess()

// Request permission
CGRequestPostEventAccess()
```

**Sandboxing:**
- CGEvent posting is NOT allowed from sandboxed apps
- Must distribute outside App Store OR use helper tool

**Alternative: IOHIDPostEvent**
- Lower level, more complex
- Requires console ownership (not just root)
- Not recommended for most use cases

**Sources:**
- [Multi.app - Building macOS Remote Control](https://multi.app/blog/building-a-macos-remote-control-engine)
- [CGEventSupervisor Library](https://github.com/stephancasas/CGEventSupervisor)

---

### 3.4 Handoff Framework

**Purpose:** Activity continuation between devices

**Relevance:** Limited for input streaming. Handoff is designed for document/activity state transfer, not real-time input.

**Better for:**
- Transferring clipboard content
- Opening URLs across devices
- Continuing documents

**Sources:**
- [Apple Handoff Documentation](https://developer.apple.com/handoff/)

---

## 4. Latency Requirements

### 4.1 Human Perception Thresholds

| Latency | Perception |
|---------|------------|
| < 2 ms | Imperceptible to humans |
| 10-15 ms | Unnoticeable for most users |
| 20-30 ms | Threshold of noticeable lag |
| 30-60 ms | Perceptible but tolerable |
| > 60 ms | Clearly noticeable, affects experience |

### 4.2 Input Device Benchmarks

| Device Type | Typical Latency |
|-------------|-----------------|
| Gaming keyboards | < 5 ms |
| Mechanical keyboards | 5-15 ms |
| Standard keyboards | 15-30 ms |
| Wireless Bluetooth | +8-30 ms overhead |

### 4.3 Recommended Targets for Trackpad/Keyboard App

| Input Type | Target Latency | Rationale |
|------------|----------------|-----------|
| Mouse movement | < 16 ms | Match 60fps refresh |
| Click events | < 20 ms | Below perception threshold |
| Keyboard input | < 30 ms | Typing tolerance higher |
| Gestures | < 25 ms | Smooth animation feel |

### 4.4 Achieving Low Latency

**Network Layer:**
- Use UDP for continuous input (mouse movement)
- Use TCP/reliable for discrete events (keystrokes)
- Stay on same WiFi network (avoid internet routing)
- Consider WiFi 6 (802.11ax) for lower latency

**Processing Layer:**
- Minimize serialization overhead (binary protocols)
- Process events on dedicated high-priority thread
- Batch small updates when appropriate

**Existing Solution Benchmarks:**
- Luna Display WiFi: 7-25 ms
- Luna Display Wired: 1-4 ms
- Remote Mouse WiFi: ~15-40 ms (estimated)

**Sources:**
- [Keyboard Latency Analysis - Dan Luu](https://danluu.com/keyboard-latency/)
- [RTINGS Keyboard Latency Tests](https://www.rtings.com/keyboard/tests/latency)

---

## 5. Recommended Technical Architecture

### 5.1 High-Level Architecture

```
+-------------------+                    +-------------------+
|                   |                    |                   |
|    iPad App       |    WiFi/Bonjour   |   macOS Server    |
|                   | <---------------> |                   |
|  - Touch capture  |    UDP + TCP      |  - Input injection|
|  - Gesture engine |                   |  - CGEvent API    |
|  - UI rendering   |                   |  - Menu bar app   |
|                   |                   |                   |
+-------------------+                    +-------------------+
```

### 5.2 Protocol Design

**Hybrid Protocol Approach:**

1. **Discovery**: Bonjour/mDNS (`_trackpad._tcp`)
2. **Control Channel**: TCP for commands, settings, keyboard
3. **Input Channel**: UDP for mouse/trackpad deltas

**Message Format (Binary, Little-Endian):**
```
[1 byte: message type]
[2 bytes: payload length]
[N bytes: payload]
```

**Message Types:**
| Type | Value | Protocol | Description |
|------|-------|----------|-------------|
| MouseMove | 0x01 | UDP | dx, dy (int16 each) |
| MouseClick | 0x02 | TCP | button, state |
| Scroll | 0x03 | UDP | dx, dy (int16 each) |
| KeyDown | 0x10 | TCP | keycode, modifiers |
| KeyUp | 0x11 | TCP | keycode, modifiers |
| Gesture | 0x20 | TCP | type, fingers, params |

### 5.3 Technology Choices

| Component | Technology | Rationale |
|-----------|------------|-----------|
| Networking | Network.framework | Modern, low-level control |
| Discovery | NWBrowser + NWListener | Built-in Bonjour |
| Input Injection | CGEvent API | Standard, permission-based |
| Serialization | Custom binary | Minimal overhead |
| Transport | UDP (movement) + TCP (keys) | Latency vs reliability |

### 5.4 Permissions Required

**iOS App:**
- Local Network Access (`NSLocalNetworkUsageDescription`)
- Bonjour Services (`NSBonjourServices`)

**macOS Server:**
- Accessibility (input injection)
- Local Network (if sandboxed, but sandboxing not recommended)

---

## 6. Challenges and Mitigations

### 6.1 iOS BLE HID Restriction

**Challenge:** Cannot use standard Bluetooth HID protocol.

**Mitigation:** WiFi-based client-server architecture with companion macOS app.

### 6.2 App Store Distribution

**Challenge:** CGEvent posting incompatible with App Sandbox.

**Options:**
1. Distribute outside App Store (direct download)
2. Use XPC helper tool for privileged operations
3. Request entitlement exception from Apple (unlikely)

### 6.3 Network Latency Variability

**Challenge:** WiFi latency can spike.

**Mitigations:**
- Implement input prediction/interpolation
- Use 5GHz WiFi band
- Support wired connection option
- Display latency indicator to user

### 6.4 Battery Drain on iPad

**Challenge:** Continuous networking and touch processing.

**Mitigations:**
- Implement power-efficient networking patterns
- Reduce update rate when idle
- Optimize touch sampling rate

---

## 7. Summary of Key Technical Decisions

| Decision | Recommendation | Alternative |
|----------|---------------|-------------|
| Communication | Network.framework over WiFi | BLE (higher latency) |
| Discovery | Bonjour/mDNS | Manual IP entry |
| Transport | UDP for movement, TCP for keys | QUIC |
| Input Injection | CGEvent API | IOKit (complex) |
| Distribution | Direct download | TestFlight/Enterprise |
| Protocol | Custom binary | JSON (higher overhead) |

---

## References

### Apple Documentation
- [Network.framework](https://developer.apple.com/documentation/network)
- [CGEvent Reference](https://developer.apple.com/documentation/coregraphics/cgevent)
- [Bonjour Overview](https://developer.apple.com/documentation/foundation/bonjour)
- [TN3151 - Networking API Guide](https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api)

### Technical Articles
- [Building macOS Remote Control - Multi.app](https://multi.app/blog/building-a-macos-remote-control-engine)
- [Keyboard Latency Analysis - Dan Luu](https://danluu.com/keyboard-latency/)
- [Network.framework Server Tutorial](https://rderik.com/blog/building-a-server-client-aplication-using-apple-s-network-framework/)

### Existing Solutions
- [Luna Display](https://astropad.com/product/lunadisplay/)
- [Duet Display](https://www.duetdisplay.com/)
- [Remote Mouse](https://www.remotemouse.net/)
- [Mobile Mouse](https://mobilemouse.com/)

### Research
- [Continuity Protocol Reverse Engineering](https://github.com/furiousMAC/continuity)
- [Apple BLE Continuity Analysis (PETS 2019)](https://petsymposium.org/popets/2019/popets-2019-0057.pdf)
