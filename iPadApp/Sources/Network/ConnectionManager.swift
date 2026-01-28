// ConnectionManager.swift
// iPad Trackpad Controller - Bonjour + TCP Client
// iOS 18+ / iPadOS 18+

import Foundation
import Network
import Combine
import UIKit

/// Connection state for UI updates
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)
}

/// Manages network connection to the Mac helper app via Bonjour
@MainActor
class ConnectionManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var isConnected: Bool = false
    @Published private(set) var connectedMacName: String?

    // MARK: - Macro Manager (set by TrackpadView)
    weak var macroManager: MacroManager?

    // MARK: - Private Properties

    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var discoveredEndpoint: NWEndpoint?

    private let serviceType = "_claudecontrol._tcp"
    private let queue = DispatchQueue(label: "com.claudecontroller.ipad.network", qos: .userInteractive)

    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var reconnectTask: Task<Void, Never>?

    // Message batching
    private var pendingMessages: [ControlMessage] = []
    private var batchTimer: Timer?
    private let batchInterval: TimeInterval = 0.008 // ~120Hz for smooth cursor

    // MARK: - Initialization

    init() {
        startBrowsing()
        setupBatchTimer()
    }

    deinit {
        batchTimer?.invalidate()
        browser?.cancel()
        connection?.cancel()
    }

    // MARK: - Service Discovery

    private func startBrowsing() {
        connectionState = .disconnected

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: serviceType, domain: "local."), using: parameters)

        browser?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleBrowserStateChange(state)
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, changes in
            Task { @MainActor in
                self?.handleBrowseResults(results)
            }
        }

        browser?.start(queue: queue)
        print("[ConnectionManager] Started browsing for \(serviceType)")
    }

    private func handleBrowserStateChange(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            print("[ConnectionManager] Browser ready")
        case .failed(let error):
            print("[ConnectionManager] Browser failed: \(error)")
            connectionState = .error("Discovery failed")
        case .cancelled:
            print("[ConnectionManager] Browser cancelled")
        default:
            break
        }
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        print("[ConnectionManager] Found \(results.count) services")

        // Connect to first discovered service
        if let result = results.first {
            if case .service(let name, _, _, _) = result.endpoint {
                print("[ConnectionManager] Discovered Mac: \(name)")
                connectedMacName = name
            }

            // Only connect if not already connected
            if connection == nil || connectionState != .connected {
                discoveredEndpoint = result.endpoint
                connect(to: result.endpoint)
            }
        }
    }

    // MARK: - Connection Management

    private func connect(to endpoint: NWEndpoint) {
        connectionState = .connecting

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.enableKeepalive = true
        tcpOptions.keepaliveInterval = 30
        tcpOptions.keepaliveCount = 3
        tcpOptions.noDelay = true  // Low latency

        let parameters = NWParameters(tls: nil, tcp: tcpOptions)
        parameters.includePeerToPeer = true

        connection = NWConnection(to: endpoint, using: parameters)

        connection?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                self?.handleConnectionStateChange(state)
            }
        }

        connection?.start(queue: queue)
    }

    private func handleConnectionStateChange(_ state: NWConnection.State) {
        switch state {
        case .ready:
            print("[ConnectionManager] Connected!")
            connectionState = .connected
            isConnected = true
            reconnectAttempts = 0
            startReceiving()
            sendHandshake()

        case .waiting(let error):
            print("[ConnectionManager] Waiting: \(error)")
            connectionState = .connecting

        case .failed(let error):
            print("[ConnectionManager] Failed: \(error)")
            isConnected = false
            handleConnectionFailure()

        case .cancelled:
            print("[ConnectionManager] Cancelled")
            isConnected = false
            connectionState = .disconnected

        default:
            break
        }
    }

    private func handleConnectionFailure() {
        guard reconnectAttempts < maxReconnectAttempts else {
            connectionState = .error("Connection failed")
            return
        }

        reconnectAttempts += 1
        connectionState = .connecting

        // Exponential backoff
        let delay = pow(2.0, Double(reconnectAttempts))

        reconnectTask?.cancel()
        reconnectTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            if let endpoint = discoveredEndpoint {
                connect(to: endpoint)
            } else {
                // Restart browsing
                startBrowsing()
            }
        }
    }

    func disconnect() {
        reconnectTask?.cancel()
        connection?.cancel()
        connection = nil
        isConnected = false
        connectionState = .disconnected
    }

    // MARK: - Receiving

    private var receiveBuffer = Data()

    private func startReceiving() {
        receiveNextMessage()
    }

    private func receiveNextMessage() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            Task { @MainActor in
                if let data = content {
                    self?.receiveBuffer.append(data)
                    self?.processReceiveBuffer()
                }

                if let error = error {
                    print("[ConnectionManager] Receive error: \(error)")
                    return
                }

                if !isComplete {
                    self?.receiveNextMessage()
                }
            }
        }
    }

    private func processReceiveBuffer() {
        // Protocol: 4-byte length prefix (big endian) + JSON data
        while receiveBuffer.count >= 4 {
            let byte0 = receiveBuffer[receiveBuffer.startIndex]
            let byte1 = receiveBuffer[receiveBuffer.index(receiveBuffer.startIndex, offsetBy: 1)]
            let byte2 = receiveBuffer[receiveBuffer.index(receiveBuffer.startIndex, offsetBy: 2)]
            let byte3 = receiveBuffer[receiveBuffer.index(receiveBuffer.startIndex, offsetBy: 3)]

            let length = Int(byte0) << 24 | Int(byte1) << 16 | Int(byte2) << 8 | Int(byte3)

            guard length > 0 && length < 65536 else {
                print("[ConnectionManager] Invalid message length: \(length), clearing buffer")
                receiveBuffer.removeAll()
                return
            }

            let totalLength = 4 + length
            guard receiveBuffer.count >= totalLength else {
                // Wait for more data
                break
            }

            // Extract JSON message (skip 4-byte prefix)
            let messageData = Data(receiveBuffer.dropFirst(4).prefix(length))
            receiveBuffer.removeFirst(totalLength)

            // Process the message
            handleReceivedData(messageData)
        }
    }

    private func handleReceivedData(_ data: Data) {
        // Debug: print raw message
        if let str = String(data: data, encoding: .utf8) {
            print("[ConnectionManager] Received: \(str.prefix(200))")
        }

        // Handle server responses (ack, config, macro options, etc.)
        if let response = try? JSONDecoder().decode(ServerResponse.self, from: data) {
            switch response.type {
            case "handshake_ack":
                print("[ConnectionManager] Handshake acknowledged")
            case "pong":
                print("[ConnectionManager] Pong received")
            case "macroOptions":
                // Try to decode as MacroOptionsMessage
                handleMacroOptionsData(data)
            case "macroClear":
                print("[ConnectionManager] Macro clear received")
                macroManager?.clearOptions()
            case "notification":
                handleNotificationData(data)
            case "permissionRequest":
                handlePermissionRequestData(data)
            default:
                print("[ConnectionManager] Unknown message type: \(response.type)")
            }
        }
    }

    private func handlePermissionRequestData(_ data: Data) {
        do {
            let request = try JSONDecoder().decode(PermissionRequestMessage.self, from: data)
            print("[ConnectionManager] 🔐 Permission request: \(request.tool) - \(request.details.prefix(50)) with \(request.options.count) options")

            // Convert message options to PermissionOption
            let options = request.options.map { opt in
                PermissionOption(number: opt.number, text: opt.text, decision: opt.decision)
            }

            macroManager?.showPermissionRequest(
                requestId: request.requestId,
                tool: request.tool,
                details: request.details,
                options: options
            )
        } catch {
            print("[ConnectionManager] Failed to decode permission request: \(error)")
        }
    }

    private func handleMacroOptionsData(_ data: Data) {
        do {
            let message = try JSONDecoder().decode(MacroOptionsMessage.self, from: data)
            print("[ConnectionManager] Received \(message.options.count) macro options, attention: \(message.needsAttention)")
            macroManager?.updateOptions(message.options, needsAttention: message.needsAttention)
        } catch {
            print("[ConnectionManager] Failed to decode macro options: \(error)")
        }
    }

    private func handleNotificationData(_ data: Data) {
        do {
            let notification = try JSONDecoder().decode(NotificationMessage.self, from: data)
            print("[ConnectionManager] Notification: \(notification.message)")
            macroManager?.showNotification(
                message: notification.message,
                playSound: notification.playSound,
                haptic: notification.haptic
            )
        } catch {
            print("[ConnectionManager] Failed to decode notification: \(error)")
        }
    }

    // MARK: - Sending

    private func sendHandshake() {
        let deviceName = UIDevice.current.name
        let handshake: [String: Any] = [
            "type": "handshake",
            "name": deviceName,
            "version": "1.0.0"
        ]

        if let data = try? JSONSerialization.data(withJSONObject: handshake) {
            sendRaw(data)
        }
    }

    private func setupBatchTimer() {
        batchTimer = Timer.scheduledTimer(withTimeInterval: batchInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.flushPendingMessages()
            }
        }
    }

    private func flushPendingMessages() {
        guard !pendingMessages.isEmpty, connection?.state == .ready else { return }

        let messages = pendingMessages
        pendingMessages.removeAll()

        // Batch encode and send
        let batch = MessageBatch(messages: messages, timestamp: Date().timeIntervalSince1970)

        if let data = try? JSONEncoder().encode(batch) {
            sendRaw(data)
        }
    }

    private func sendRaw(_ data: Data) {
        // Add length prefix for framing
        var length = UInt32(data.count).bigEndian
        var framedData = Data(bytes: &length, count: 4)
        framedData.append(data)

        connection?.send(content: framedData, completion: .contentProcessed { error in
            if let error = error {
                print("[ConnectionManager] Send error: \(error)")
            }
        })
    }

    private func queueMessage(_ message: ControlMessage) {
        pendingMessages.append(message)
    }

    // MARK: - Public API - Mouse Control

    func sendMouseMove(deltaX: CGFloat, deltaY: CGFloat) {
        queueMessage(ControlMessage(
            type: .mouseMove,
            deltaX: Double(deltaX),
            deltaY: Double(deltaY)
        ))
    }

    func sendClick() {
        queueMessage(ControlMessage(type: .leftClick))
    }

    func sendRightClick() {
        queueMessage(ControlMessage(type: .rightClick))
    }

    func sendDoubleClick() {
        queueMessage(ControlMessage(type: .doubleClick))
    }

    func sendScroll(deltaX: CGFloat, deltaY: CGFloat) {
        queueMessage(ControlMessage(
            type: .scroll,
            deltaX: Double(deltaX),
            deltaY: Double(deltaY)
        ))
    }

    // MARK: - Public API - Keyboard

    func sendKeyDown(keyCode: UInt16, modifiers: UInt32 = 0) {
        queueMessage(ControlMessage(
            type: .keyDown,
            keyCode: keyCode,
            modifiers: modifiers
        ))
    }

    func sendKeyUp(keyCode: UInt16, modifiers: UInt32 = 0) {
        queueMessage(ControlMessage(
            type: .keyUp,
            keyCode: keyCode,
            modifiers: modifiers
        ))
    }

    func sendKeyPress(keyCode: UInt16, modifiers: UInt32 = 0) {
        queueMessage(ControlMessage(
            type: .keyPress,
            keyCode: keyCode,
            modifiers: modifiers
        ))
    }

    func sendThreeFingerSwipe(direction: String) {
        var message = ControlMessage(type: .threeFingerSwipe)
        message.swipeDirection = direction
        queueMessage(message)
    }

    // MARK: - Public API - Text Input (Dictation)

    /// Send text to be typed on Mac (for dictation feature)
    func sendTextToType(_ text: String) {
        var message = ControlMessage(type: .textToType)
        message.text = text
        queueMessage(message)
        print("[ConnectionManager] Sent text to type: \(text.prefix(50))...")
    }

    // MARK: - Public API - Macro Selection

    /// Send macro selection to Mac (types the number + Enter)
    func sendMacroSelect(optionNumber: Int) {
        var message = ControlMessage(type: .macroSelect)
        message.optionNumber = optionNumber
        message.includeEnter = true
        queueMessage(message)
        print("[ConnectionManager] Sent macro selection: \(optionNumber)")
    }

    /// Send macro selection without Enter (for "Other" button - allows custom text entry)
    func sendMacroSelectWithoutEnter(optionNumber: Int) {
        var message = ControlMessage(type: .macroSelect)
        message.optionNumber = optionNumber
        message.includeEnter = false
        queueMessage(message)
        print("[ConnectionManager] Sent macro selection (no Enter): \(optionNumber)")
    }

    // MARK: - Public API - Permission Response

    /// Send permission decision back to Mac
    func sendPermissionResponse(requestId: String, decision: String) {
        var message = ControlMessage(type: .permissionResponse)
        message.permissionRequestId = requestId
        message.permissionDecision = decision
        queueMessage(message)
        print("[ConnectionManager] 🔐 Sent permission response: \(requestId) -> \(decision)")
    }
}

// MARK: - Message Types

struct ControlMessage: Codable {
    let type: MessageType
    var deltaX: Double?
    var deltaY: Double?
    var keyCode: UInt16?
    var modifiers: UInt32?
    var text: String?
    var optionNumber: Int?
    var includeEnter: Bool?  // For macroSelect: whether to press Enter after number

    enum MessageType: String, Codable {
        case mouseMove
        case leftClick
        case rightClick
        case doubleClick
        case scroll
        case keyDown
        case keyUp
        case keyPress
        case text
        case threeFingerSwipe
        case textToType  // For dictation - types text into focused Mac app
        case macroSelect // For macro keyboard - types selected option number + Enter
        case permissionResponse // Send permission decision back to Mac
    }

    var swipeDirection: String?

    // Permission response fields
    var permissionRequestId: String?
    var permissionDecision: String?  // "allow" or "deny"
}

struct MessageBatch: Codable {
    let messages: [ControlMessage]
    let timestamp: Double
}

struct ServerResponse: Codable {
    let type: String
    var message: String?
}

/// Message from macOS with parsed macro options
struct MacroOptionsMessage: Codable {
    let type: String
    let options: [MacroOption]
    let needsAttention: Bool
    let timestamp: Double
}

struct NotificationMessage: Codable {
    let type: String
    let message: String
    let playSound: Bool
    let haptic: Bool
}

/// Message from macOS requesting permission (Allow/Deny)
struct PermissionRequestMessage: Codable {
    let type: String
    let requestId: String
    let tool: String
    let details: String
    let options: [PermissionOptionMessage]
    let timestamp: Double
}

/// Permission option in the message
struct PermissionOptionMessage: Codable {
    let number: Int
    let text: String
    let decision: String
}

/// Represents a parsed option from Claude's terminal output
struct MacroOption: Identifiable, Codable, Equatable {
    let id: UUID
    let number: Int
    let text: String

    init(number: Int, text: String) {
        self.id = UUID()
        self.number = number
        self.text = text
    }

    enum CodingKeys: String, CodingKey {
        case id, number, text
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // ID might not be in the JSON, generate one
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.number = try container.decode(Int.self, forKey: .number)
        self.text = try container.decode(String.self, forKey: .text)
    }
}
