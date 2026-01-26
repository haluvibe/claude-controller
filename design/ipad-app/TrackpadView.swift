// TrackpadView.swift
// iPad Trackpad App - Main Trackpad Surface View
// iOS 18+

import SwiftUI
import Combine

// MARK: - Main Trackpad View

struct TrackpadView: View {
    @StateObject private var viewModel = TrackpadViewModel()
    @State private var showSettings = false
    @State private var showKeyboard = false
    @State private var currentHint: GestureHintOverlay.GestureHint? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                TrackpadBackground()

                // Main trackpad surface
                TrackpadSurface(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Touch indicators overlay
                TouchIndicatorsOverlay(viewModel: viewModel)

                // Gesture hint (when learning mode enabled)
                if let hint = currentHint {
                    GestureHintOverlay(
                        isVisible: .constant(true),
                        gesture: hint
                    )
                    .transition(.opacity)
                }

                // Bottom toolbar
                VStack {
                    Spacer()
                    BottomToolbar(
                        showKeyboard: $showKeyboard,
                        showSettings: $showSettings,
                        viewModel: viewModel
                    )
                }

                // Status bar overlay
                VStack {
                    StatusBarOverlay(viewModel: viewModel, showSettings: $showSettings)
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showSettings) {
            SettingsView(configuration: $viewModel.configuration)
        }
        .sheet(isPresented: $showKeyboard) {
            KeyboardView(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Trackpad Background

struct TrackpadBackground: View {
    var body: some View {
        // Subtle gradient mimicking Apple trackpad appearance
        LinearGradient(
            colors: [
                Color(.systemGray6),
                Color(.systemGray5)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            // Subtle texture pattern
            GeometryReader { geo in
                Canvas { context, size in
                    // Draw subtle dot pattern
                    let spacing: CGFloat = 20
                    for x in stride(from: 0, to: size.width, by: spacing) {
                        for y in stride(from: 0, to: size.height, by: spacing) {
                            let rect = CGRect(x: x, y: y, width: 1, height: 1)
                            context.fill(
                                Path(ellipseIn: rect),
                                with: .color(.gray.opacity(0.1))
                            )
                        }
                    }
                }
            }
        )
    }
}

// MARK: - Trackpad Surface (Gesture Handler)

struct TrackpadSurface: UIViewRepresentable {
    @ObservedObject var viewModel: TrackpadViewModel

    func makeUIView(context: Context) -> TrackpadGestureView {
        let view = TrackpadGestureView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true
        return view
    }

    func updateUIView(_ uiView: TrackpadGestureView, context: Context) {
        uiView.configuration = viewModel.configuration
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, TrackpadGestureViewDelegate {
        let viewModel: TrackpadViewModel

        init(viewModel: TrackpadViewModel) {
            self.viewModel = viewModel
        }

        func didMove(delta: CGPoint) {
            viewModel.handleCursorMove(delta: delta)
        }

        func didTap(at point: CGPoint, tapCount: Int) {
            viewModel.handleTap(at: point, count: tapCount)
        }

        func didTwoFingerTap(at point: CGPoint) {
            viewModel.handleRightClick(at: point)
        }

        func didScroll(delta: CGPoint, phase: ScrollPhase) {
            viewModel.handleScroll(delta: delta, phase: phase)
        }

        func didPinch(scale: CGFloat, phase: GesturePhase) {
            viewModel.handlePinch(scale: scale, phase: phase)
        }

        func didThreeFingerSwipe(direction: SwipeDirection) {
            viewModel.handleThreeFingerSwipe(direction: direction)
        }

        func didStartDrag(at point: CGPoint) {
            viewModel.handleDragStart(at: point)
        }

        func didContinueDrag(delta: CGPoint) {
            viewModel.handleDragContinue(delta: delta)
        }

        func didEndDrag(at point: CGPoint) {
            viewModel.handleDragEnd(at: point)
        }

        func touchesBegan(count: Int, positions: [CGPoint]) {
            viewModel.updateTouchState(count: count, positions: positions, isActive: true)
        }

        func touchesEnded() {
            viewModel.updateTouchState(count: 0, positions: [], isActive: false)
        }
    }
}

// MARK: - Touch Indicators Overlay

struct TouchIndicatorsOverlay: View {
    @ObservedObject var viewModel: TrackpadViewModel

    var body: some View {
        ZStack {
            // Show touch indicators at each touch point
            ForEach(Array(viewModel.activeTouches.enumerated()), id: \.offset) { index, position in
                TouchIndicatorView(
                    isActive: viewModel.isTouching,
                    touchType: touchType(for: viewModel.activeTouches.count),
                    position: position
                )
            }

            // Ripple effect for taps
            if let tapPosition = viewModel.lastTapPosition {
                RippleEffect(
                    trigger: viewModel.showTapRipple,
                    position: tapPosition
                )
            }

            // Scroll indicator
            if viewModel.isScrolling {
                ScrollIndicatorView(
                    direction: viewModel.scrollDirection,
                    intensity: viewModel.scrollIntensity,
                    isActive: true
                )
                .position(x: UIScreen.main.bounds.width - 50, y: UIScreen.main.bounds.height / 2)
            }
        }
        .allowsHitTesting(false) // Pass through touches
    }

    private func touchType(for count: Int) -> TouchIndicatorView.TouchType {
        switch count {
        case 1: return .single
        case 2: return .twoFinger
        case 3: return .threeFinger
        default: return .single
        }
    }
}

// MARK: - Status Bar Overlay

struct StatusBarOverlay: View {
    @ObservedObject var viewModel: TrackpadViewModel
    @Binding var showSettings: Bool

    var body: some View {
        HStack {
            // Connection status
            ConnectionStatusIndicator(
                status: viewModel.connectionStatus,
                latency: viewModel.latency
            )

            Spacer()

            // Mac name (when connected)
            if case .connected = viewModel.connectionStatus {
                Text(viewModel.connectedMacName ?? "Mac")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Settings button
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
            }
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground).opacity(0.95),
                    Color(.systemBackground).opacity(0.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
        )
    }
}

// MARK: - Bottom Toolbar

struct BottomToolbar: View {
    @Binding var showKeyboard: Bool
    @Binding var showSettings: Bool
    @ObservedObject var viewModel: TrackpadViewModel

    var body: some View {
        HStack(spacing: 24) {
            // Keyboard toggle
            ToolbarButton(
                icon: "keyboard",
                label: "Keyboard",
                isActive: showKeyboard
            ) {
                showKeyboard.toggle()
            }

            // Click mode toggle
            ToolbarButton(
                icon: viewModel.clickMode == .tapToClick ? "hand.tap" : "cursorarrow.click",
                label: viewModel.clickMode == .tapToClick ? "Tap Click" : "Press Click",
                isActive: false
            ) {
                viewModel.toggleClickMode()
            }

            // Scroll lock
            ToolbarButton(
                icon: viewModel.scrollLocked ? "lock.fill" : "lock.open",
                label: viewModel.scrollLocked ? "Scroll Off" : "Scroll On",
                isActive: viewModel.scrollLocked
            ) {
                viewModel.scrollLocked.toggle()
            }

            // Drag mode
            ToolbarButton(
                icon: "hand.point.up.left.and.text",
                label: viewModel.isDragging ? "Dragging" : "Drag",
                isActive: viewModel.isDragging
            ) {
                viewModel.toggleDragMode()
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground).opacity(0.9))
                .shadow(color: .black.opacity(0.15), radius: 8, y: -2)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
}

struct ToolbarButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isActive ? .blue : .primary)

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isActive ? .blue : .secondary)
            }
            .frame(minWidth: 60)
        }
    }
}

// MARK: - Supporting Types

enum ScrollPhase {
    case began
    case changed
    case ended
}

enum GesturePhase {
    case began
    case changed
    case ended
}

enum SwipeDirection {
    case up
    case down
    case left
    case right
}

enum ClickMode {
    case tapToClick
    case pressToClick
}

// MARK: - Gesture View Delegate Protocol

protocol TrackpadGestureViewDelegate: AnyObject {
    func didMove(delta: CGPoint)
    func didTap(at point: CGPoint, tapCount: Int)
    func didTwoFingerTap(at point: CGPoint)
    func didScroll(delta: CGPoint, phase: ScrollPhase)
    func didPinch(scale: CGFloat, phase: GesturePhase)
    func didThreeFingerSwipe(direction: SwipeDirection)
    func didStartDrag(at point: CGPoint)
    func didContinueDrag(delta: CGPoint)
    func didEndDrag(at point: CGPoint)
    func touchesBegan(count: Int, positions: [CGPoint])
    func touchesEnded()
}

// MARK: - Preview

#Preview {
    TrackpadView()
}
