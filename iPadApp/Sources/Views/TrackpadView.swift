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
                        KeyboardView(connectionManager: connectionManager)
                            .frame(height: 280)
                            .transition(.move(edge: .bottom))
                    }

                    // Bottom toolbar
                    ToolbarView(showKeyboard: $showKeyboard)
                        .frame(height: 60)
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

            // Connected Mac name
            if let macName = connectionManager.connectedMacName {
                Text(macName)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .padding(.trailing, 16)
            }
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
        return view
    }

    func updateUIView(_ uiView: GestureHandlerView, context: Context) {
        // Update callbacks if needed
    }
}

// MARK: - Bottom Toolbar

struct ToolbarView: View {
    @Binding var showKeyboard: Bool

    var body: some View {
        HStack {
            Spacer()

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

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview

#Preview {
    TrackpadView()
        .environmentObject(ConnectionManager())
}
