// MultitaskingSupport.swift
// iPad Trackpad App - iPadOS Multitasking and Stage Manager Support
// iOS 18+

import SwiftUI
import UIKit

// MARK: - Scene Configuration

/// App supports all iPad multitasking modes
struct ClaudeControllerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .windowResizability(.contentSize) // Allow window resizing in Stage Manager
        .defaultSize(width: 800, height: 600) // Default window size
        .commands {
            // Add keyboard commands for Stage Manager
            CommandGroup(replacing: .newItem) {
                Button("New Connection") {
                    appState.showConnectionSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandMenu("Trackpad") {
                Button(appState.isKeyboardVisible ? "Hide Keyboard" : "Show Keyboard") {
                    appState.isKeyboardVisible.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)

                Divider()

                Button("Toggle Scroll Lock") {
                    appState.scrollLocked.toggle()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        // Handle claude-controller://connect?mac=hostname
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host else { return }

        if host == "connect", let mac = components.queryItems?.first(where: { $0.name == "mac" })?.value {
            appState.connectToMac(hostname: mac)
        }
    }
}

// MARK: - App State

class AppState: ObservableObject {
    @Published var showConnectionSheet = false
    @Published var isKeyboardVisible = false
    @Published var scrollLocked = false
    @Published var currentWindowSize: CGSize = .zero

    private var connectionManager = ConnectionManager()

    func connectToMac(hostname: String) {
        connectionManager.connect(to: hostname)
    }
}

// MARK: - Adaptive Layout

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        GeometryReader { geometry in
            Group {
                if isCompactMode(geometry: geometry) {
                    CompactTrackpadLayout()
                } else if isSplitViewMode(geometry: geometry) {
                    SplitViewTrackpadLayout()
                } else {
                    FullTrackpadLayout()
                }
            }
            .onChange(of: geometry.size) { _, newSize in
                appState.currentWindowSize = newSize
            }
        }
    }

    private func isCompactMode(geometry: GeometryProxy) -> Bool {
        // Slide Over or compact iPhone-style presentation
        return geometry.size.width < 400
    }

    private func isSplitViewMode(geometry: GeometryProxy) -> Bool {
        // Split View (not full screen)
        let screenWidth = UIScreen.main.bounds.width
        return geometry.size.width < screenWidth * 0.9 && geometry.size.width >= 400
    }
}

// MARK: - Compact Layout (Slide Over)

struct CompactTrackpadLayout: View {
    var body: some View {
        VStack(spacing: 0) {
            // Minimal status bar
            CompactStatusBar()

            // Trackpad takes most of the space
            TrackpadView()
                .frame(maxHeight: .infinity)

            // Compact toolbar
            CompactToolbar()
        }
    }
}

struct CompactStatusBar: View {
    var body: some View {
        HStack {
            ConnectionStatusIndicator(status: .connected, latency: 12)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemBackground).opacity(0.9))
    }
}

struct CompactToolbar: View {
    @State private var showKeyboard = false

    var body: some View {
        HStack(spacing: 16) {
            Button(action: { showKeyboard.toggle() }) {
                Image(systemName: "keyboard")
                    .font(.system(size: 20))
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
    }
}

// MARK: - Split View Layout

struct SplitViewTrackpadLayout: View {
    @State private var showSidebar = false

    var body: some View {
        HStack(spacing: 0) {
            // Trackpad (main area)
            TrackpadView()
                .frame(maxWidth: .infinity)

            // Optional sidebar for settings in wider splits
            if showSidebar {
                SidebarView()
                    .frame(width: 280)
                    .transition(.move(edge: .trailing))
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showSidebar.toggle() }) {
                    Image(systemName: showSidebar ? "sidebar.right" : "sidebar.left")
                }
            }
        }
    }
}

struct SidebarView: View {
    var body: some View {
        List {
            Section("Quick Settings") {
                Toggle("Natural Scrolling", isOn: .constant(true))
                Toggle("Tap to Click", isOn: .constant(true))
            }

            Section("Shortcuts") {
                Button("Mission Control") {}
                Button("Launchpad") {}
                Button("Show Desktop") {}
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Full Layout (Stage Manager or Full Screen)

struct FullTrackpadLayout: View {
    var body: some View {
        TrackpadView()
    }
}

// MARK: - External Keyboard Support

struct ExternalKeyboardHandler: ViewModifier {
    @EnvironmentObject var appState: AppState

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
                handleKeyboardChange(notification, isShowing: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
                handleKeyboardChange(notification, isShowing: false)
            }
    }

    private func handleKeyboardChange(_ notification: Notification, isShowing: Bool) {
        // Check if it's a hardware keyboard (height will be minimal or zero)
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            let isHardwareKeyboard = keyboardFrame.height < 100

            if isHardwareKeyboard {
                // Hardware keyboard attached - hide virtual keyboard option
                appState.isKeyboardVisible = false
            }
        }
    }
}

// MARK: - Apple Pencil Support

/// Apple Pencil can be used as a precision pointer
struct PencilTrackpadView: UIViewRepresentable {
    @ObservedObject var viewModel: TrackpadViewModel

    func makeUIView(context: Context) -> PencilEnabledTrackpadView {
        let view = PencilEnabledTrackpadView()
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: PencilEnabledTrackpadView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    class Coordinator: NSObject, PencilTrackpadDelegate {
        let viewModel: TrackpadViewModel

        init(viewModel: TrackpadViewModel) {
            self.viewModel = viewModel
        }

        func pencilMoved(delta: CGPoint, pressure: CGFloat) {
            // Use pressure for precision - lighter touch = slower cursor
            let sensitivity = 0.5 + (pressure * 0.5) // 0.5x to 1.0x based on pressure
            let adjustedDelta = CGPoint(
                x: delta.x * sensitivity,
                y: delta.y * sensitivity
            )
            viewModel.handleCursorMove(delta: adjustedDelta)
        }

        func pencilTapped(at point: CGPoint) {
            viewModel.handleTap(at: point, count: 1)
        }

        func pencilDoubleTapped(at point: CGPoint) {
            viewModel.handleTap(at: point, count: 2)
        }
    }
}

protocol PencilTrackpadDelegate: AnyObject {
    func pencilMoved(delta: CGPoint, pressure: CGFloat)
    func pencilTapped(at point: CGPoint)
    func pencilDoubleTapped(at point: CGPoint)
}

class PencilEnabledTrackpadView: UIView {
    weak var delegate: PencilTrackpadDelegate?

    private var previousPencilLocation: CGPoint?
    private var pencilTouchStartTime: Date?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPencilInteraction()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPencilInteraction()
    }

    private func setupPencilInteraction() {
        // Enable pencil interaction
        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = self
        addInteraction(pencilInteraction)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, touch.type == .pencil else {
            super.touchesBegan(touches, with: event)
            return
        }

        previousPencilLocation = touch.location(in: self)
        pencilTouchStartTime = Date()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              touch.type == .pencil,
              let previousLocation = previousPencilLocation else {
            super.touchesMoved(touches, with: event)
            return
        }

        let currentLocation = touch.location(in: self)
        let delta = CGPoint(
            x: currentLocation.x - previousLocation.x,
            y: currentLocation.y - previousLocation.y
        )

        delegate?.pencilMoved(delta: delta, pressure: touch.force / touch.maximumPossibleForce)
        previousPencilLocation = currentLocation
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first,
              touch.type == .pencil else {
            super.touchesEnded(touches, with: event)
            return
        }

        // Check if it was a tap (minimal movement, short duration)
        if let startTime = pencilTouchStartTime {
            let duration = Date().timeIntervalSince(startTime)
            if duration < 0.3 {
                delegate?.pencilTapped(at: touch.location(in: self))
            }
        }

        previousPencilLocation = nil
        pencilTouchStartTime = nil
    }
}

extension PencilEnabledTrackpadView: UIPencilInteractionDelegate {
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        // Handle Apple Pencil double-tap (for tool switching, but we can use for right-click)
        if let location = previousPencilLocation {
            delegate?.pencilDoubleTapped(at: location)
        }
    }
}

// MARK: - Scene Restoration

extension AppState {
    func encodeRestorableState() -> Data? {
        let state = RestorableState(
            lastConnectedMac: connectionManager.currentMac,
            scrollLocked: scrollLocked,
            isKeyboardVisible: isKeyboardVisible
        )
        return try? JSONEncoder().encode(state)
    }

    func restoreState(from data: Data) {
        guard let state = try? JSONDecoder().decode(RestorableState.self, from: data) else { return }

        scrollLocked = state.scrollLocked
        isKeyboardVisible = state.isKeyboardVisible

        if let mac = state.lastConnectedMac {
            connectToMac(hostname: mac)
        }
    }

    struct RestorableState: Codable {
        let lastConnectedMac: String?
        let scrollLocked: Bool
        let isKeyboardVisible: Bool
    }
}
