# ClaudeController Build & Deploy Guide

You (Claude) are reading this because you need to rebuild and deploy the ClaudeController system. This is a two-app setup: a macOS menu bar app and an iPad app that communicate over local network via Bonjour/TCP.

## Architecture Recap

- **macOS app** (`ClaudeController`): Menu bar app that runs a Bonjour service (`_claudecontrol._tcp.` on port 9847), a TCP server for iPad connections, and an HTTP MCP bridge server on port 19847.
- **iPad app** (`TrackpadController`): Turns the iPad into a wireless trackpad/keyboard. Discovers the Mac via Bonjour and connects over TCP.
- **MCP server** (`mcp-server/`): Node.js stdio server that Claude Code uses to send commands to the macOS app via HTTP bridge. Separate from the Swift apps -- you don't need to rebuild it unless its source changed.

## Prerequisites

- Xcode must be installed
- The iPad must be on the same local network as the Mac
- The iPad must have Developer Mode enabled
- The workspace is at `/Users/paulhayes/automations/claude-controller/ClaudeController.xcworkspace`

## Step-by-Step Build & Deploy

### 1. Build the macOS app

```
session-set-defaults:
  workspacePath: /Users/paulhayes/automations/claude-controller/ClaudeController.xcworkspace
  scheme: ClaudeController
  configuration: Debug
  suppressWarnings: true

Then call: build_macos(preferXcodebuild: true)
```

Use the xcodebuild MCP tools, not `swift build`. The macOS app has its own Xcode project at `macOS/ClaudeController/ClaudeController.xcodeproj` inside the workspace. It is NOT just a Swift package anymore -- there's a real .xcodeproj with entitlements, Info.plist, and manual code signing (`Developer ID Application`, team `V3C26N4FFD`).

### 2. Launch the macOS app

```
get_mac_app_path() -> gives you the .app path in DerivedData
launch_mac_app(appPath: <that path>)
```

This starts the Bonjour service automatically. You do NOT need to start Bonjour separately -- `ConnectionManager.startListening()` is called from `applicationDidFinishLaunching` and it calls `startBonjourService()` internally.

### 3. Build the iPad app

Switch the session defaults:

```
session-set-defaults:
  scheme: TrackpadController
  deviceId: <get from list_devices()>
```

The iPad device ID for Paul's iPad has been `665FE5B8-5887-5958-9AAF-0E272E370FF6` but always verify with `list_devices()` first in case it changes.

```
build_device(preferXcodebuild: true)
```

The iPad app depends on WhisperKit (SPM remote package). First build may take longer while it resolves the package.

### 4. Install and launch on iPad

```
get_device_app_path() -> gives you the .app path
install_app_device(appPath: <that path>)
launch_app_device(bundleId: "com.personal.TrackpadController")
```

### 5. Verify connection

After both apps are running, the iPad should auto-discover the Mac via Bonjour and connect. The macOS menu bar icon changes from an outline hand to a filled green hand when connected.

You can also verify via the MCP bridge:
```bash
curl http://localhost:19847/status
```
Should return `{"connected": true, "deviceName": "iPad"}` (or Paul's iPad).

## Key Details to Remember

| Item | Value |
|------|-------|
| Workspace | `ClaudeController.xcworkspace` |
| macOS scheme | `ClaudeController` |
| iPad scheme | `TrackpadController` |
| macOS bundle ID | `com.paulhayes.ClaudeController` |
| iPad bundle ID | `com.personal.TrackpadController` |
| Dev team | `V3C26N4FFD` |
| Bonjour service | `_claudecontrol._tcp.` port 9847 |
| MCP bridge port | 19847 |
| macOS signing | Manual, Developer ID Application |
| iPad signing | Automatic |
| iPad deployment target | iOS 18.0 |
| macOS deployment target | macOS 15.0 |

## Source file locations

- macOS sources: `macOS/ClaudeController/Sources/` (App, Core, Network subdirs)
- iPad sources: `iPadApp/Sources/` (App, Audio, Config, Input, Managers, Network, Views subdirs)
- macOS Xcode project: `macOS/ClaudeController/ClaudeController.xcodeproj`
- iPad Xcode project: `iPadApp/TrackpadController.xcodeproj`
- macOS entitlements: `macOS/ClaudeController/Resources/ClaudeController.entitlements`
- macOS Info.plist: `macOS/ClaudeController/Resources/Info.plist`
- iPad Info.plist: `iPadApp/Info.plist`
- iPad build config: `iPadApp/Config.xcconfig`

## The macOS project only has 4 source files in the Xcode project

The Xcode project references exactly these files:
1. `Sources/App/ClaudeControllerApp.swift` - Entry point, AppDelegate, StatusView
2. `Sources/Core/InputInjector.swift` - CGEvent input injection
3. `Sources/Network/ConnectionManager.swift` - Bonjour + TCP server
4. `Sources/Network/MCPBridgeServer.swift` - HTTP bridge for MCP commands

There is also a `Package.swift` in the same directory but the Xcode project is what you should build, not the Swift package. The Package.swift is an older artifact.

## Troubleshooting

- **macOS app won't inject input**: Needs Accessibility permission. The user must grant it in System Settings > Privacy & Security > Accessibility. Rebuilding the app resets this permission because it changes the code signature.
- **iPad can't find Mac**: Both must be on the same WiFi network. Check that the macOS app is actually running (look for the hand icon in the menu bar).
- **Build fails with signing error**: macOS uses manual signing with "Developer ID Application". If the certificate isn't in the keychain, switch to automatic signing temporarily for debug builds.
- **WhisperKit build takes forever**: First build resolves the SPM package. Subsequent builds use the cache.
- **Port 9847 already in use**: An old instance of ClaudeController may still be running. Kill it with `pkill -f ClaudeController` or use `stop_mac_app(appName: "ClaudeController")`.
