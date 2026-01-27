import SwiftUI
import AppKit

@main
struct ClaudeControllerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var connectionManager: ConnectionManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon (menu bar app only)
        NSApp.setActivationPolicy(.accessory)

        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "hand.point.up.left", accessibilityDescription: "Claude Controller")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 280, height: 200)
        popover?.behavior = .transient

        // Initialize connection manager
        connectionManager = ConnectionManager()

        // Set up popover content
        let contentView = StatusView(connectionManager: connectionManager!)
        popover?.contentViewController = NSHostingController(rootView: contentView)

        // Start listening
        connectionManager?.startListening()

        // Update icon based on connection state
        connectionManager?.onConnectionStateChanged = { [weak self] isConnected in
            Task { @MainActor in
                self?.updateStatusIcon(connected: isConnected)
            }
        }
    }

    func updateStatusIcon(connected: Bool) {
        if let button = statusItem?.button {
            let symbolName = connected ? "hand.point.up.left.fill" : "hand.point.up.left"
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Claude Controller")
            button.contentTintColor = connected ? .systemGreen : .labelColor
        }
    }

    @objc func togglePopover() {
        if let popover = popover, let button = statusItem?.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                NSApp.activate()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        connectionManager?.stopListening()
    }
}

struct StatusView: View {
    @ObservedObject var connectionManager: ConnectionManager

    var body: some View {
        VStack(spacing: 16) {
            // Title
            HStack {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.title2)
                Text("Claude Controller")
                    .font(.headline)
            }
            .padding(.top, 8)

            Divider()

            // Connection status
            VStack(spacing: 8) {
                HStack {
                    Circle()
                        .fill(connectionManager.isConnected ? Color.green : Color.gray)
                        .frame(width: 10, height: 10)
                    Text(connectionManager.isConnected ? "Connected" : "Waiting for iPad...")
                        .foregroundColor(.secondary)
                    Spacer()
                }

                if connectionManager.isConnected {
                    HStack {
                        Image(systemName: "ipad")
                        Text(connectionManager.connectedDeviceName)
                            .font(.caption)
                        Spacer()
                    }
                    .foregroundColor(.secondary)
                }

                HStack {
                    Image(systemName: "network")
                    Text("Port: 9847")
                        .font(.caption)
                    Spacer()
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            Spacer()

            // Stats
            if connectionManager.isConnected {
                HStack {
                    VStack {
                        Text("\(connectionManager.messageCount)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Messages")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)
            }

            Divider()

            // Test macro button (when connected)
            if connectionManager.isConnected {
                Button(action: {
                    connectionManager.sendTestMacroOptions()
                }) {
                    HStack {
                        Image(systemName: "list.number")
                        Text("Test Macro Bar")
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .padding(.bottom, 4)
            }

            // Quit button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit")
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
            .padding(.bottom, 8)
        }
        .frame(width: 280, height: 220)
    }
}
