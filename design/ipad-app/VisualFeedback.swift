// VisualFeedback.swift
// iPad Trackpad App - Visual Feedback Components
// iOS 18+

import SwiftUI
import UIKit

// MARK: - Touch Indicator View

/// Visual indicator that appears at touch points
struct TouchIndicatorView: View {
    let isActive: Bool
    let touchType: TouchType
    let position: CGPoint

    enum TouchType {
        case single
        case twoFinger
        case threeFinger
        case drag

        var color: Color {
            switch self {
            case .single: return .blue.opacity(0.6)
            case .twoFinger: return .green.opacity(0.6)
            case .threeFinger: return .orange.opacity(0.6)
            case .drag: return .purple.opacity(0.6)
            }
        }

        var size: CGFloat {
            switch self {
            case .single: return 60
            case .twoFinger: return 50
            case .threeFinger: return 45
            case .drag: return 70
            }
        }
    }

    var body: some View {
        Circle()
            .fill(touchType.color)
            .frame(width: touchType.size, height: touchType.size)
            .overlay(
                Circle()
                    .stroke(touchType.color.opacity(0.8), lineWidth: 2)
            )
            .scaleEffect(isActive ? 1.0 : 0.8)
            .opacity(isActive ? 1.0 : 0.0)
            .position(position)
            .animation(.easeOut(duration: 0.15), value: isActive)
    }
}

// MARK: - Ripple Effect

/// Ripple animation for tap feedback
struct RippleEffect: View {
    let trigger: Bool
    let position: CGPoint

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.8

    var body: some View {
        Circle()
            .fill(Color.blue.opacity(0.3))
            .frame(width: 100, height: 100)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(position)
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    withAnimation(.easeOut(duration: 0.4)) {
                        scale = 1.5
                        opacity = 0.0
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        scale = 0.5
                        opacity = 0.8
                    }
                }
            }
    }
}

// MARK: - Scroll Indicator

/// Visual indicator for scroll direction and intensity
struct ScrollIndicatorView: View {
    let direction: ScrollDirection
    let intensity: CGFloat // 0.0 - 1.0
    let isActive: Bool

    enum ScrollDirection {
        case up, down, left, right

        var rotation: Angle {
            switch self {
            case .up: return .degrees(0)
            case .down: return .degrees(180)
            case .left: return .degrees(-90)
            case .right: return .degrees(90)
            }
        }
    }

    var body: some View {
        Image(systemName: "chevron.up")
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.white.opacity(0.8))
            .padding(12)
            .background(
                Circle()
                    .fill(Color.gray.opacity(0.5))
            )
            .rotationEffect(direction.rotation)
            .scaleEffect(0.8 + (intensity * 0.4))
            .opacity(isActive ? 0.9 : 0.0)
            .animation(.easeOut(duration: 0.2), value: isActive)
    }
}

// MARK: - Gesture Hint Overlay

/// Educational overlay showing gesture hints
struct GestureHintOverlay: View {
    @Binding var isVisible: Bool
    let gesture: GestureHint

    enum GestureHint: CaseIterable {
        case tap
        case twoFingerTap
        case scroll
        case pinch
        case threeFinger
        case drag

        var title: String {
            switch self {
            case .tap: return "Tap"
            case .twoFingerTap: return "Two-Finger Tap"
            case .scroll: return "Scroll"
            case .pinch: return "Pinch"
            case .threeFinger: return "Three Fingers"
            case .drag: return "Drag"
            }
        }

        var description: String {
            switch self {
            case .tap: return "Tap once for left click, double-tap to double-click"
            case .twoFingerTap: return "Tap with two fingers for right-click"
            case .scroll: return "Slide two fingers to scroll"
            case .pinch: return "Pinch to zoom in/out"
            case .threeFinger: return "Three fingers up for Mission Control"
            case .drag: return "Tap and hold, then drag to move items"
            }
        }

        var iconName: String {
            switch self {
            case .tap: return "hand.tap"
            case .twoFingerTap: return "hand.tap"
            case .scroll: return "hand.draw"
            case .pinch: return "arrow.up.left.and.arrow.down.right"
            case .threeFinger: return "hand.raised"
            case .drag: return "hand.point.up.left.and.text"
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: gesture.iconName)
                .font(.system(size: 48))
                .foregroundColor(.white)

            Text(gesture.title)
                .font(.headline)
                .foregroundColor(.white)

            Text(gesture.description)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.75))
        )
        .opacity(isVisible ? 1.0 : 0.0)
        .scaleEffect(isVisible ? 1.0 : 0.9)
        .animation(.easeOut(duration: 0.3), value: isVisible)
    }
}

// MARK: - Connection Status Indicator

/// Compact connection status shown in status bar area
struct ConnectionStatusIndicator: View {
    let status: ConnectionStatus
    let latency: Int? // milliseconds

    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case reconnecting
        case error(String)

        var color: Color {
            switch self {
            case .disconnected: return .gray
            case .connecting: return .yellow
            case .connected: return .green
            case .reconnecting: return .orange
            case .error: return .red
            }
        }

        var icon: String {
            switch self {
            case .disconnected: return "wifi.slash"
            case .connecting: return "wifi"
            case .connected: return "wifi"
            case .reconnecting: return "wifi.exclamationmark"
            case .error: return "wifi.slash"
            }
        }

        var label: String {
            switch self {
            case .disconnected: return "Disconnected"
            case .connecting: return "Connecting..."
            case .connected: return "Connected"
            case .reconnecting: return "Reconnecting..."
            case .error(let msg): return msg
            }
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            // Status icon with animation
            Image(systemName: status.icon)
                .foregroundColor(status.color)
                .font(.system(size: 14, weight: .medium))
                .symbolEffect(.pulse, isActive: status == .connecting || status == .reconnecting)

            // Status text
            Text(status.label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)

            // Latency indicator (when connected)
            if case .connected = status, let latency = latency {
                Text("\(latency)ms")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(latencyColor(latency))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(latencyColor(latency).opacity(0.2))
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color(.systemBackground).opacity(0.9))
                .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
        )
    }

    private func latencyColor(_ ms: Int) -> Color {
        switch ms {
        case 0..<20: return .green
        case 20..<50: return .yellow
        case 50..<100: return .orange
        default: return .red
        }
    }
}

// MARK: - Zone Highlight

/// Subtle highlight showing active zones
struct ZoneHighlightView: View {
    let zone: TrackpadZone
    let isActive: Bool

    var body: some View {
        GeometryReader { geometry in
            let rect = zoneRect(for: zone, in: geometry.size)

            Rectangle()
                .fill(zoneColor.opacity(0.1))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .overlay(
                    Rectangle()
                        .stroke(zoneColor.opacity(0.3), lineWidth: 1)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                )
                .opacity(isActive ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.2), value: isActive)
        }
    }

    private var zoneColor: Color {
        switch zone {
        case .main: return .blue
        case .scrollEdgeRight: return .green
        case .scrollEdgeBottom: return .green
        case .clickZone: return .purple
        }
    }

    private func zoneRect(for zone: TrackpadZone, in size: CGSize) -> CGRect {
        switch zone {
        case .main:
            return CGRect(x: 0, y: 0, width: size.width * 0.95, height: size.height * 0.85)
        case .scrollEdgeRight:
            return CGRect(x: size.width * 0.95, y: 0, width: size.width * 0.05, height: size.height)
        case .scrollEdgeBottom:
            return CGRect(x: 0, y: size.height * 0.92, width: size.width, height: size.height * 0.08)
        case .clickZone:
            return CGRect(x: 0, y: size.height * 0.85, width: size.width, height: size.height * 0.15)
        }
    }
}

// MARK: - Haptic Feedback Manager

class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()

    private init() {
        prepareAll()
    }

    func prepareAll() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }

    func tap(intensity: Int) {
        switch intensity {
        case 1: lightImpact.impactOccurred()
        case 2: mediumImpact.impactOccurred()
        case 3: heavyImpact.impactOccurred()
        default: break
        }
    }

    func scroll() {
        selectionFeedback.selectionChanged()
    }

    func click() {
        mediumImpact.impactOccurred(intensity: 0.8)
    }

    func rightClick() {
        heavyImpact.impactOccurred(intensity: 0.6)
    }

    func error() {
        notificationFeedback.notificationOccurred(.error)
    }

    func success() {
        notificationFeedback.notificationOccurred(.success)
    }
}
