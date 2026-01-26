// TrackpadViewModel.swift
// iPad Trackpad App - View Model for Trackpad State Management
// iOS 18+

import SwiftUI
import Combine

@MainActor
class TrackpadViewModel: ObservableObject {

    // MARK: - Published Properties

    // Configuration
    @Published var configuration = TrackpadConfiguration() {
        didSet {
            saveConfiguration()
        }
    }

    // Connection state
    @Published var connectionStatus: ConnectionStatusIndicator.ConnectionStatus = .disconnected
    @Published var connectedMacName: String?
    @Published var latency: Int?

    // Touch state
    @Published var activeTouches: [CGPoint] = []
    @Published var isTouching = false
    @Published var lastTapPosition: CGPoint?
    @Published var showTapRipple = false

    // Gesture state
    @Published var isScrolling = false
    @Published var scrollDirection: ScrollIndicatorView.ScrollDirection = .down
    @Published var scrollIntensity: CGFloat = 0
    @Published var isDragging = false
    @Published var clickMode: ClickMode = .tapToClick
    @Published var scrollLocked = false

    // MARK: - Private Properties

    private var connectionManager: ConnectionManager?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        loadConfiguration()
        setupConnectionManager()
    }

    // MARK: - Configuration Persistence

    private func loadConfiguration() {
        if let data = UserDefaults.standard.data(forKey: "TrackpadConfiguration"),
           let config = try? JSONDecoder().decode(TrackpadConfiguration.self, from: data) {
            configuration = config
        }
    }

    private func saveConfiguration() {
        if let data = try? JSONEncoder().encode(configuration) {
            UserDefaults.standard.set(data, forKey: "TrackpadConfiguration")
        }
    }

    // MARK: - Connection Management

    private func setupConnectionManager() {
        connectionManager = ConnectionManager()

        connectionManager?.statusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.connectionStatus = status
            }
            .store(in: &cancellables)

        connectionManager?.latencyPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] latency in
                self?.latency = latency
            }
            .store(in: &cancellables)
    }

    func connect(to mac: DiscoveredMac) {
        connectionStatus = .connecting
        connectionManager?.connect(to: mac.hostname)
    }

    func disconnect() {
        connectionManager?.disconnect()
        connectionStatus = .disconnected
        connectedMacName = nil
    }

    // MARK: - Touch State Updates

    func updateTouchState(count: Int, positions: [CGPoint], isActive: Bool) {
        activeTouches = positions
        isTouching = isActive
    }

    // MARK: - Cursor Movement

    func handleCursorMove(delta: CGPoint) {
        guard case .connected = connectionStatus else { return }

        connectionManager?.sendMouseMove(deltaX: delta.x, deltaY: delta.y)
    }

    // MARK: - Click Handling

    func handleTap(at point: CGPoint, count: Int) {
        guard case .connected = connectionStatus else { return }

        lastTapPosition = point
        showTapRipple = true

        // Reset ripple after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.showTapRipple = false
        }

        // Haptic feedback
        if configuration.hapticIntensity > 0 {
            HapticFeedbackManager.shared.tap(intensity: configuration.hapticIntensity)
        }

        // Send click to Mac
        if count == 1 {
            connectionManager?.sendLeftClick()
        } else if count == 2 {
            connectionManager?.sendDoubleClick()
        }
    }

    func handleRightClick(at point: CGPoint) {
        guard case .connected = connectionStatus else { return }

        lastTapPosition = point

        if configuration.hapticIntensity > 0 {
            HapticFeedbackManager.shared.rightClick()
        }

        connectionManager?.sendRightClick()
    }

    // MARK: - Scroll Handling

    func handleScroll(delta: CGPoint, phase: ScrollPhase) {
        guard case .connected = connectionStatus,
              !scrollLocked else { return }

        switch phase {
        case .began:
            isScrolling = true
        case .changed:
            // Update scroll direction indicator
            if abs(delta.y) > abs(delta.x) {
                scrollDirection = delta.y > 0 ? .down : .up
            } else {
                scrollDirection = delta.x > 0 ? .right : .left
            }
            scrollIntensity = min(1.0, hypot(delta.x, delta.y) / 50.0)

            // Send scroll to Mac
            connectionManager?.sendScroll(deltaX: delta.x, deltaY: delta.y)

            // Subtle haptic for scroll "clicks"
            if configuration.hapticIntensity > 0 && Int(hypot(delta.x, delta.y)) % 20 == 0 {
                HapticFeedbackManager.shared.scroll()
            }

        case .ended:
            isScrolling = false
            scrollIntensity = 0
        }
    }

    // MARK: - Pinch/Zoom Handling

    func handlePinch(scale: CGFloat, phase: GesturePhase) {
        guard case .connected = connectionStatus else { return }

        switch phase {
        case .began:
            connectionManager?.sendPinchStart()
        case .changed:
            connectionManager?.sendPinchUpdate(scale: scale)
        case .ended:
            connectionManager?.sendPinchEnd()
        }
    }

    // MARK: - Three-Finger Gestures

    func handleThreeFingerSwipe(direction: SwipeDirection) {
        guard case .connected = connectionStatus else { return }

        if configuration.hapticIntensity > 0 {
            HapticFeedbackManager.shared.tap(intensity: 3)
        }

        switch direction {
        case .up:
            // Mission Control
            connectionManager?.sendSystemGesture(.missionControl)
        case .down:
            // App Expose
            connectionManager?.sendSystemGesture(.appExpose)
        case .left:
            // Switch to right space
            connectionManager?.sendSystemGesture(.spaceRight)
        case .right:
            // Switch to left space
            connectionManager?.sendSystemGesture(.spaceLeft)
        }
    }

    // MARK: - Drag and Drop

    func handleDragStart(at point: CGPoint) {
        guard case .connected = connectionStatus else { return }

        isDragging = true
        connectionManager?.sendDragStart()
    }

    func handleDragContinue(delta: CGPoint) {
        guard case .connected = connectionStatus else { return }

        connectionManager?.sendDragMove(deltaX: delta.x, deltaY: delta.y)
    }

    func handleDragEnd(at point: CGPoint) {
        guard case .connected = connectionStatus else { return }

        isDragging = false
        connectionManager?.sendDragEnd()
    }

    // MARK: - Mode Toggles

    func toggleClickMode() {
        clickMode = clickMode == .tapToClick ? .pressToClick : .tapToClick
    }

    func toggleDragMode() {
        if isDragging {
            // End current drag
            connectionManager?.sendDragEnd()
            isDragging = false
        } else {
            // Start drag lock
            connectionManager?.sendDragStart()
            isDragging = true
        }
    }

    // MARK: - Keyboard Input

    func sendKeyPress(key: KeyCode, modifiers: KeyModifiers = []) {
        guard case .connected = connectionStatus else { return }

        connectionManager?.sendKeyPress(key: key, modifiers: modifiers)
    }

    func sendText(_ text: String) {
        guard case .connected = connectionStatus else { return }

        connectionManager?.sendText(text)
    }
}

// MARK: - Supporting Types

enum SystemGesture: String {
    case missionControl
    case appExpose
    case spaceLeft
    case spaceRight
    case launchpad
    case showDesktop
}

enum KeyCode: UInt16 {
    // Letters
    case a = 0, s = 1, d = 2, f = 3, g = 5, h = 4, j = 38, k = 40, l = 37

    // Special keys
    case escape = 53
    case tab = 48
    case space = 49
    case delete = 51
    case enter = 36
    case command = 55
    case shift = 56
    case capsLock = 57
    case option = 58
    case control = 59

    // Arrows
    case leftArrow = 123
    case rightArrow = 124
    case downArrow = 125
    case upArrow = 126

    // Function keys
    case f1 = 122, f2 = 120, f3 = 99, f4 = 118, f5 = 96, f6 = 97
    case f7 = 98, f8 = 100, f9 = 101, f10 = 109, f11 = 103, f12 = 111
}

struct KeyModifiers: OptionSet {
    let rawValue: UInt32

    static let command = KeyModifiers(rawValue: 1 << 0)
    static let shift = KeyModifiers(rawValue: 1 << 1)
    static let option = KeyModifiers(rawValue: 1 << 2)
    static let control = KeyModifiers(rawValue: 1 << 3)
    static let function = KeyModifiers(rawValue: 1 << 4)
}

// MARK: - Configuration Codable

extension TrackpadConfiguration: Codable {
    enum CodingKeys: String, CodingKey {
        case scrollEdgeRightWidth
        case scrollEdgeBottomHeight
        case clickZoneHeight
        case cursorSensitivity
        case scrollSensitivity
        case naturalScrolling
        case accelerationEnabled
        case accelerationCurve
        case doubleTapMaxInterval
        case dragThreshold
        case longPressThreshold
        case showTouchIndicators
        case hapticIntensity
        case showGestureHints
    }
}

extension AccelerationCurve: Codable {}
