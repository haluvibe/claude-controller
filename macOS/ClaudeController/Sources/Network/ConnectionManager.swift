import Foundation
import Network
import Combine
import CoreGraphics

// MARK: - Protocol Messages (matches iPad format)

struct MessageBatch: Codable, Sendable {
    let messages: [ControlMessage]
    let timestamp: Double
}

struct ControlMessage: Codable, Sendable {
    let type: MessageType
    var deltaX: Double?
    var deltaY: Double?
    var keyCode: UInt16?
    var modifiers: UInt32?
    var text: String?

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
        case textToType  // For dictation - types text into focused app
        case macroSelect // For macro keyboard - types selected option number + Enter
    }

    var optionNumber: Int?

    var swipeDirection: String?
}

// MARK: - Connection Manager

@MainActor
final class ConnectionManager: ObservableObject {
    @Published var isConnected = false
    @Published var connectedDeviceName = ""
    @Published var messageCount = 0

    var onConnectionStateChanged: (@Sendable (Bool) -> Void)?

    private var listener: NWListener?
    private var connection: NWConnection?
    private var bonjourService: NetService?
    private let port: UInt16 = 9847

    private var receiveBuffer = Data()

    init() {}

    // MARK: - Server Lifecycle

    func startListening() {
        // Start Bonjour advertising
        startBonjourService()

        // Start TCP listener
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

            let portCopy = port
            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("✅ Server listening on port \(portCopy)")
                case .failed(let error):
                    print("❌ Listener failed: \(error)")
                    Task { @MainActor [weak self] in
                        self?.restartListener()
                    }
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] newConnection in
                Task { @MainActor in
                    self?.handleNewConnection(newConnection)
                }
            }

            listener?.start(queue: .main)

        } catch {
            print("❌ Failed to create listener: \(error)")
        }
    }

    func stopListening() {
        connection?.cancel()
        listener?.cancel()
        bonjourService?.stop()

        connection = nil
        listener = nil
        bonjourService = nil
    }

    private func restartListener() {
        stopListening()
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            self?.startListening()
        }
    }

    // MARK: - Bonjour

    private func startBonjourService() {
        bonjourService = NetService(
            domain: "local.",
            type: "_claudecontrol._tcp.",
            name: Host.current().localizedName ?? "Mac",
            port: Int32(port)
        )

        bonjourService?.publish()
        print("📡 Bonjour service published: _claudecontrol._tcp on port \(port)")
    }

    // MARK: - Connection Handling

    private func handleNewConnection(_ newConnection: NWConnection) {
        // Close existing connection if any
        connection?.cancel()

        connection = newConnection

        connection?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.isConnected = true
                    self?.connectedDeviceName = "iPad"
                    self?.onConnectionStateChanged?(true)
                    print("📱 iPad connected!")

                case .failed(let error):
                    print("❌ Connection failed: \(error)")
                    self?.handleDisconnection()

                case .cancelled:
                    self?.handleDisconnection()

                default:
                    break
                }
            }
        }

        connection?.start(queue: .main)
        receiveData()
    }

    private func handleDisconnection() {
        isConnected = false
        connectedDeviceName = ""
        onConnectionStateChanged?(false)
        receiveBuffer.removeAll()
        print("📱 iPad disconnected")
    }

    // MARK: - Data Reception

    private func receiveData() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor in
                if let data = data, !data.isEmpty {
                    self?.receiveBuffer.append(data)
                    self?.processReceivedData()
                }

                if let error = error {
                    print("❌ Receive error: \(error)")
                    return
                }

                if isComplete {
                    self?.handleDisconnection()
                    return
                }

                // Continue receiving
                self?.receiveData()
            }
        }
    }

    private func processReceivedData() {
        // Protocol: 4-byte length prefix (big endian) + JSON data
        while receiveBuffer.count >= 4 {
            // Safely read length prefix using safe array access
            guard receiveBuffer.count >= 4 else { break }

            let byte0 = receiveBuffer[receiveBuffer.startIndex]
            let byte1 = receiveBuffer[receiveBuffer.index(receiveBuffer.startIndex, offsetBy: 1)]
            let byte2 = receiveBuffer[receiveBuffer.index(receiveBuffer.startIndex, offsetBy: 2)]
            let byte3 = receiveBuffer[receiveBuffer.index(receiveBuffer.startIndex, offsetBy: 3)]

            let length = Int(byte0) << 24 | Int(byte1) << 16 | Int(byte2) << 8 | Int(byte3)

            // Sanity check: reject impossibly large or zero messages
            guard length > 0 && length < 65536 else {
                print("⚠️ Invalid message length: \(length), clearing buffer")
                receiveBuffer.removeAll()
                return
            }

            let totalLength = 4 + length

            guard receiveBuffer.count >= totalLength else {
                // Wait for more data
                break
            }

            // Extract message safely using dropFirst/prefix
            let messageData = receiveBuffer.dropFirst(4).prefix(length)
            let jsonData = Data(messageData)

            // Remove processed data
            if receiveBuffer.count >= totalLength {
                receiveBuffer.removeFirst(totalLength)
            } else {
                receiveBuffer.removeAll()
            }

            // Parse and handle
            handleMessage(jsonData)
        }
    }

    // MARK: - Message Handling

    private func handleMessage(_ data: Data) {
        // Try to decode as MessageBatch first (batched messages from iPad)
        if let batch = try? JSONDecoder().decode(MessageBatch.self, from: data) {
            for message in batch.messages {
                messageCount += 1
                processControlMessage(message)
            }
            return
        }

        // Try single message
        if let message = try? JSONDecoder().decode(ControlMessage.self, from: data) {
            messageCount += 1
            processControlMessage(message)
            return
        }

        // Try handshake message
        if let handshake = try? JSONDecoder().decode(HandshakeMessage.self, from: data) {
            print("👋 Handshake from: \(handshake.name ?? "Unknown")")
            connectedDeviceName = handshake.name ?? "iPad"
            sendHandshakeAck()
            return
        }

        // Debug unknown messages
        if let str = String(data: data, encoding: .utf8) {
            print("⚠️ Unknown message format: \(str.prefix(200))")
        }
    }

    private func processControlMessage(_ message: ControlMessage) {
        let injector = InputInjector.shared

        switch message.type {
        case .mouseMove:
            if let dx = message.deltaX, let dy = message.deltaY {
                injector.moveCursor(dx: Float(dx), dy: Float(dy))
            }

        case .leftClick:
            injector.click(button: .left, count: 1)

        case .rightClick:
            injector.click(button: .right, count: 1)

        case .doubleClick:
            injector.click(button: .left, count: 2)

        case .scroll:
            if let dx = message.deltaX, let dy = message.deltaY {
                injector.scroll(dx: Float(dx), dy: Float(dy))
            }

        case .keyDown:
            if let keyCode = message.keyCode {
                let modifiers = message.modifiers ?? 0
                injector.keyDown(keyCode: keyCode, modifiers: modifiers)
            }

        case .keyUp:
            if let keyCode = message.keyCode {
                injector.keyUp(keyCode: keyCode)
            }

        case .keyPress:
            if let keyCode = message.keyCode {
                let modifiers = message.modifiers ?? 0
                injector.keyPress(keyCode: keyCode, modifiers: modifiers)
            }

        case .text:
            if let text = message.text {
                injector.typeText(text)
            }

        case .threeFingerSwipe:
            if let direction = message.swipeDirection {
                injector.threeFingerSwipe(direction: direction)
            }

        case .textToType:
            // Dictation: type the transcribed text into focused app
            if let text = message.text {
                print("🎤 Typing dictated text: \(text.prefix(50))...")
                injector.typeText(text)
            }

        case .macroSelect:
            // Macro keyboard: type the selected option number + Enter
            if let number = message.optionNumber {
                print("🔘 Macro selection: typing \(number) + Enter")
                injector.typeText("\(number)")
                // Small delay then press Enter
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    injector.keyPress(keyCode: 36, modifiers: 0) // Return key
                }
            }
        }
    }

    // MARK: - Send Messages

    private func sendHandshakeAck() {
        let ack: [String: Any] = [
            "type": "handshake_ack",
            "success": true,
            "serverName": Host.current().localizedName ?? "Mac"
        ]
        sendJSON(ack)
    }

    private func sendJSON(_ dict: [String: Any]) {
        guard let connection = connection else { return }

        do {
            let data = try JSONSerialization.data(withJSONObject: dict)
            var length = UInt32(data.count).bigEndian
            var packet = Data(bytes: &length, count: 4)
            packet.append(data)

            connection.send(content: packet, completion: .contentProcessed { error in
                if let error = error {
                    print("❌ Send error: \(error)")
                }
            })
        } catch {
            print("❌ JSON serialization error: \(error)")
        }
    }

    // MARK: - Macro Options

    /// Send macro options to iPad
    func sendMacroOptions(_ options: [[String: Any]], needsAttention: Bool) {
        let message: [String: Any] = [
            "type": "macroOptions",
            "options": options,
            "needsAttention": needsAttention,
            "timestamp": Date().timeIntervalSince1970
        ]
        sendJSON(message)
        print("📋 Sent \(options.count) macro options to iPad")
    }

    /// Clear macro options on iPad
    func sendMacroClear() {
        let message: [String: Any] = [
            "type": "macroClear"
        ]
        sendJSON(message)
        print("📋 Cleared macro options")
    }

    /// Send test macro options (for testing)
    func sendTestMacroOptions() {
        let options: [[String: Any]] = [
            ["number": 1, "text": "Yes, proceed with changes"],
            ["number": 2, "text": "No, cancel"],
            ["number": 3, "text": "Skip this step"]
        ]
        sendMacroOptions(options, needsAttention: true)
    }

    // MARK: - MCP Bridge Methods

    /// Send notification to iPad
    func sendNotification(message: String, playSound: Bool, haptic: Bool) {
        let msg: [String: Any] = [
            "type": "notification",
            "message": message,
            "playSound": playSound,
            "haptic": haptic
        ]
        sendJSON(msg)
        print("🔔 Sent notification to iPad: \(message)")
    }
}

// MARK: - Handshake Message

struct HandshakeMessage: Codable {
    let type: String
    var name: String?
    var version: String?
}
