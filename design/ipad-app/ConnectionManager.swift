// ConnectionManager.swift
// iPad Trackpad App - Network Communication with Mac
// iOS 18+

import Foundation
import Network
import Combine

/// Manages network connection to the Mac helper app
class ConnectionManager: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var isConnected = false
    @Published private(set) var currentMac: String?

    // Publishers for view model
    let statusPublisher = PassthroughSubject<ConnectionStatusIndicator.ConnectionStatus, Never>()
    let latencyPublisher = PassthroughSubject<Int, Never>()

    // MARK: - Private Properties

    private var connection: NWConnection?
    private var browser: NWBrowser?
    private var listener: NWListener?

    private let queue = DispatchQueue(label: "com.claudecontroller.connection", qos: .userInteractive)
    private var heartbeatTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5

    // Message batching for performance
    private var pendingMessages: [ControlMessage] = []
    private var batchTimer: Timer?
    private let batchInterval: TimeInterval = 0.008 // ~120Hz update rate

    // Latency tracking
    private var pingStartTime: Date?
    private var latencyHistory: [Int] = []
    private let latencyHistorySize = 10

    // MARK: - Connection Parameters

    private let serviceType = "_claude-controller._tcp"
    private let serviceDomain = "local"
    private let port: NWEndpoint.Port = 51423

    // MARK: - Initialization

    init() {
        setupBatchTimer()
    }

    deinit {
        disconnect()
        batchTimer?.invalidate()
    }

    // MARK: - Service Discovery

    func startDiscovery() -> AnyPublisher<[DiscoveredMac], Never> {
        let subject = CurrentValueSubject<[DiscoveredMac], Never>([])

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        browser = NWBrowser(for: .bonjour(type: serviceType, domain: serviceDomain), using: parameters)

        browser?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Browser ready")
            case .failed(let error):
                print("Browser failed: \(error)")
            default:
                break
            }
        }

        browser?.browseResultsChangedHandler = { results, changes in
            let macs = results.compactMap { result -> DiscoveredMac? in
                guard case .service(let name, _, _, _) = result.endpoint else { return nil }
                return DiscoveredMac(name: name, hostname: "\(name).\(self.serviceDomain)")
            }
            subject.send(macs)
        }

        browser?.start(queue: queue)

        return subject.eraseToAnyPublisher()
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
    }

    // MARK: - Connection Management

    func connect(to hostname: String) {
        disconnect()

        statusPublisher.send(.connecting)

        let host = NWEndpoint.Host(hostname)
        let parameters = NWParameters.tcp
        parameters.multipathServiceType = .handover

        // Enable keep-alive
        if let tcpOptions = parameters.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcpOptions.enableKeepalive = true
            tcpOptions.keepaliveIdle = 10
            tcpOptions.keepaliveCount = 3
            tcpOptions.keepaliveInterval = 5
        }

        connection = NWConnection(host: host, port: port, using: parameters)

        connection?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self.isConnected = true
                    self.currentMac = hostname
                    self.statusPublisher.send(.connected)
                    self.reconnectAttempts = 0
                    self.startHeartbeat()
                    self.startReceiving()

                case .waiting(let error):
                    print("Connection waiting: \(error)")
                    self.statusPublisher.send(.reconnecting)

                case .failed(let error):
                    print("Connection failed: \(error)")
                    self.handleConnectionFailure()

                case .cancelled:
                    self.isConnected = false
                    self.statusPublisher.send(.disconnected)

                default:
                    break
                }
            }
        }

        connection?.start(queue: queue)
    }

    func disconnect() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        connection?.cancel()
        connection = nil
        isConnected = false
        currentMac = nil
        statusPublisher.send(.disconnected)
    }

    private func handleConnectionFailure() {
        guard reconnectAttempts < maxReconnectAttempts else {
            statusPublisher.send(.error("Connection failed"))
            disconnect()
            return
        }

        reconnectAttempts += 1
        statusPublisher.send(.reconnecting)

        // Exponential backoff
        let delay = pow(2.0, Double(reconnectAttempts))
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, let mac = self.currentMac else { return }
            self.connect(to: mac)
        }
    }

    // MARK: - Message Sending

    private func send(_ message: ControlMessage) {
        pendingMessages.append(message)
    }

    private func setupBatchTimer() {
        batchTimer = Timer.scheduledTimer(withTimeInterval: batchInterval, repeats: true) { [weak self] _ in
            self?.flushPendingMessages()
        }
    }

    private func flushPendingMessages() {
        guard !pendingMessages.isEmpty, let connection = connection else { return }

        let messages = pendingMessages
        pendingMessages.removeAll()

        // Batch messages into single packet
        let batch = MessageBatch(messages: messages, timestamp: Date().timeIntervalSince1970)

        guard let data = try? JSONEncoder().encode(batch) else { return }

        // Add length prefix for framing
        var length = UInt32(data.count).bigEndian
        var framedData = Data(bytes: &length, count: 4)
        framedData.append(data)

        connection.send(content: framedData, completion: .contentProcessed { error in
            if let error = error {
                print("Send error: \(error)")
            }
        })
    }

    // MARK: - Receiving

    private func startReceiving() {
        receiveMessage()
    }

    private func receiveMessage() {
        connection?.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] content, _, isComplete, error in
            guard let self = self else { return }

            if let error = error {
                print("Receive error: \(error)")
                return
            }

            guard let lengthData = content, lengthData.count == 4 else {
                if !isComplete {
                    self.receiveMessage()
                }
                return
            }

            let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

            self.connection?.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { content, _, isComplete, error in
                if let data = content {
                    self.handleReceivedData(data)
                }

                if !isComplete {
                    self.receiveMessage()
                }
            }
        }
    }

    private func handleReceivedData(_ data: Data) {
        guard let response = try? JSONDecoder().decode(ServerResponse.self, from: data) else { return }

        switch response.type {
        case .pong:
            if let startTime = pingStartTime {
                let latency = Int(Date().timeIntervalSince(startTime) * 1000)
                updateLatency(latency)
            }

        case .ack:
            // Message acknowledged
            break

        case .error:
            print("Server error: \(response.message ?? "Unknown")")

        case .cursorPosition:
            // Mac can send cursor position back for sync if needed
            break
        }
    }

    // MARK: - Heartbeat & Latency

    private func startHeartbeat() {
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }

    private func sendPing() {
        pingStartTime = Date()
        send(ControlMessage(type: .ping))
    }

    private func updateLatency(_ ms: Int) {
        latencyHistory.append(ms)
        if latencyHistory.count > latencyHistorySize {
            latencyHistory.removeFirst()
        }

        let averageLatency = latencyHistory.reduce(0, +) / latencyHistory.count
        DispatchQueue.main.async {
            self.latencyPublisher.send(averageLatency)
        }
    }

    // MARK: - Mouse Control

    func sendMouseMove(deltaX: CGFloat, deltaY: CGFloat) {
        send(ControlMessage(
            type: .mouseMove,
            deltaX: Double(deltaX),
            deltaY: Double(deltaY)
        ))
    }

    func sendLeftClick() {
        send(ControlMessage(type: .leftClick))
    }

    func sendDoubleClick() {
        send(ControlMessage(type: .doubleClick))
    }

    func sendRightClick() {
        send(ControlMessage(type: .rightClick))
    }

    func sendScroll(deltaX: CGFloat, deltaY: CGFloat) {
        send(ControlMessage(
            type: .scroll,
            deltaX: Double(deltaX),
            deltaY: Double(deltaY)
        ))
    }

    // MARK: - Pinch/Zoom

    func sendPinchStart() {
        send(ControlMessage(type: .pinchStart))
    }

    func sendPinchUpdate(scale: CGFloat) {
        send(ControlMessage(type: .pinchUpdate, scale: Double(scale)))
    }

    func sendPinchEnd() {
        send(ControlMessage(type: .pinchEnd))
    }

    // MARK: - Drag and Drop

    func sendDragStart() {
        send(ControlMessage(type: .dragStart))
    }

    func sendDragMove(deltaX: CGFloat, deltaY: CGFloat) {
        send(ControlMessage(
            type: .dragMove,
            deltaX: Double(deltaX),
            deltaY: Double(deltaY)
        ))
    }

    func sendDragEnd() {
        send(ControlMessage(type: .dragEnd))
    }

    // MARK: - System Gestures

    func sendSystemGesture(_ gesture: SystemGesture) {
        send(ControlMessage(type: .systemGesture, gesture: gesture.rawValue))
    }

    // MARK: - Keyboard

    func sendKeyPress(key: KeyCode, modifiers: KeyModifiers = []) {
        send(ControlMessage(
            type: .keyPress,
            keyCode: key.rawValue,
            modifiers: modifiers.rawValue
        ))
    }

    func sendText(_ text: String) {
        send(ControlMessage(type: .text, text: text))
    }
}

// MARK: - Message Types

struct ControlMessage: Codable {
    let type: MessageType
    var deltaX: Double?
    var deltaY: Double?
    var scale: Double?
    var keyCode: UInt16?
    var modifiers: UInt32?
    var text: String?
    var gesture: String?

    enum MessageType: String, Codable {
        case ping
        case mouseMove
        case leftClick
        case doubleClick
        case rightClick
        case scroll
        case pinchStart
        case pinchUpdate
        case pinchEnd
        case dragStart
        case dragMove
        case dragEnd
        case systemGesture
        case keyPress
        case text
    }
}

struct MessageBatch: Codable {
    let messages: [ControlMessage]
    let timestamp: Double
}

struct ServerResponse: Codable {
    let type: ResponseType
    var message: String?
    var cursorX: Double?
    var cursorY: Double?

    enum ResponseType: String, Codable {
        case pong
        case ack
        case error
        case cursorPosition
    }
}
