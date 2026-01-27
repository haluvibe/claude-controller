// TrackpadView.swift
// iPad Trackpad Controller - Main Trackpad Interface
// iOS 18+ / iPadOS 18+

import SwiftUI

struct TrackpadView: View {
    @EnvironmentObject var connectionManager: ConnectionManager
    @State private var showKeyboard = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dark background
                Color(white: 0.15)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Status bar at top
                    StatusBar(connectionManager: connectionManager)
                        .frame(height: 44)
                        .background(Color(white: 0.1))

                    // Main trackpad area
                    TrackpadTouchArea(connectionManager: connectionManager)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Keyboard (shown/hidden)
                    if showKeyboard {
                        KeyboardView(connectionManager: connectionManager, onDismiss: {
                            showKeyboard = false
                        })
                            .frame(height: 300)
                            .transition(.move(edge: .bottom))
                    }

                    // Bottom toolbar
                    ToolbarView(showKeyboard: $showKeyboard, connectionManager: connectionManager)
                        .frame(height: 80)
                        .background(Color(white: 0.1))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showKeyboard)
    }
}

// MARK: - Status Bar

struct StatusBar: View {
    @ObservedObject var connectionManager: ConnectionManager

    var body: some View {
        HStack {
            // Connection indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(connectionManager.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)

                Text(statusText)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.leading, 16)

            Spacer()

            // Version and connected Mac name
            HStack(spacing: 8) {
                Text("v1.2")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.orange)

                if let macName = connectionManager.connectedMacName {
                    Text(macName)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            .padding(.trailing, 16)
        }
    }

    private var statusText: String {
        switch connectionManager.connectionState {
        case .disconnected:
            return "Searching..."
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

// MARK: - Trackpad Touch Area (SwiftUI wrapper for UIKit gesture handling)

struct TrackpadTouchArea: UIViewRepresentable {
    let connectionManager: ConnectionManager

    func makeUIView(context: Context) -> GestureHandlerView {
        let view = GestureHandlerView()
        view.onMove = { deltaX, deltaY in
            connectionManager.sendMouseMove(deltaX: deltaX, deltaY: deltaY)
        }
        view.onClick = {
            connectionManager.sendClick()
        }
        view.onRightClick = {
            connectionManager.sendRightClick()
        }
        view.onScroll = { deltaX, deltaY in
            connectionManager.sendScroll(deltaX: deltaX, deltaY: deltaY)
        }
        view.onThreeFingerSwipe = { direction in
            connectionManager.sendThreeFingerSwipe(direction: direction.rawValue)
        }
        return view
    }

    func updateUIView(_ uiView: GestureHandlerView, context: Context) {
        // Update callbacks if needed
    }
}

// MARK: - Bottom Toolbar

struct ToolbarView: View {
    @Binding var showKeyboard: Bool
    let connectionManager: ConnectionManager
    @StateObject private var dictationManager: DictationManager

    init(showKeyboard: Binding<Bool>, connectionManager: ConnectionManager) {
        self._showKeyboard = showKeyboard
        self.connectionManager = connectionManager
        self._dictationManager = StateObject(wrappedValue: DictationManager(
            connectionManager: connectionManager,
            apiKey: AppConfig.whisperAPIKey
        ))
    }

    var body: some View {
        VStack(spacing: 4) {
            // Dictation status (shows when active)
            DictationStatusView(dictationManager: dictationManager)
                .frame(height: 16)

            HStack(spacing: 16) {
                // Gesture buttons (left side)
                HStack(spacing: 8) {
                    // Left arrow - Previous space
                    GestureButton(icon: "chevron.left", action: {
                        connectionManager.sendThreeFingerSwipe(direction: "right")
                    })

                    // Vertical stack for up/down
                    VStack(spacing: 4) {
                        // Up arrow - Mission Control
                        GestureButton(icon: "chevron.up", action: {
                            connectionManager.sendThreeFingerSwipe(direction: "up")
                        })

                        // Down arrow - App Exposé
                        GestureButton(icon: "chevron.down", action: {
                            connectionManager.sendThreeFingerSwipe(direction: "down")
                        })
                    }

                    // Right arrow - Next space
                    GestureButton(icon: "chevron.right", action: {
                        connectionManager.sendThreeFingerSwipe(direction: "left")
                    })
                }

                Spacer()

                // Mode toggle (API/Local)
                TranscriptionModeToggle(dictationManager: dictationManager)

                // Dictation button (microphone)
                DictationButton(dictationManager: dictationManager)

                // Keyboard toggle button
                Button(action: {
                    showKeyboard.toggle()
                }) {
                    Image(systemName: showKeyboard ? "keyboard.chevron.compact.down" : "keyboard")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 44)
                        .background(showKeyboard ? Color.blue : Color(white: 0.25))
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Gesture Button

struct GestureButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color(white: 0.25))
                .cornerRadius(8)
        }
    }
}

// MARK: - Preview

#Preview {
    TrackpadView()
        .environmentObject(ConnectionManager())
}
