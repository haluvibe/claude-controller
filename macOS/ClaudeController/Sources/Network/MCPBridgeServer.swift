// MCPBridgeServer.swift
// ClaudeController - HTTP bridge for MCP server communication
// macOS 14.0+

import Foundation
import Network

/// Pending permission request waiting for iPad response
struct PendingPermission {
    let connection: NWConnection
    let requestId: String
    let timestamp: Date
}

/// HTTP server that receives commands from the Claude Controller MCP server
/// and bridges them to the iPad via ConnectionManager
class MCPBridgeServer {
    private var listener: NWListener?
    private let port: UInt16 = 19847

    /// Pending permission requests waiting for iPad response (requestId -> pending)
    private var pendingPermissions: [String: PendingPermission] = [:]
    private let permissionLock = NSLock()

    // MARK: - Callbacks

    /// Macro options received
    var onMacroOptions: (([[String: Any]], Bool) -> Void)?

    /// Clear macro options
    var onMacroClear: (() -> Void)?

    /// Notification received
    var onNotification: ((String, Bool, Bool) -> Void)?

    /// Get connection status
    var getConnectionStatus: (() -> (connected: Bool, deviceName: String?))?

    /// Permission request received - forward to iPad (requestId, tool, details, options)
    var onPermissionRequest: ((String, String, String, [[String: Any]]) -> Void)?

    init() {}

    func start() {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true

            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)

            listener?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    print("🌐 MCP Bridge server listening on port \(self.port)")
                case .failed(let error):
                    print("❌ MCP Bridge server failed: \(error)")
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: .main)
        } catch {
            print("❌ Failed to start MCP Bridge server: \(error)")
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        print("🌐 MCP Bridge server stopped")
    }

    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.receiveRequest(connection)
            case .failed(let error):
                print("❌ Connection failed: \(error)")
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .main)
    }

    private func receiveRequest(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                self.processHTTPRequest(data, connection: connection)
            }

            if isComplete || error != nil {
                connection.cancel()
            }
        }
    }

    private func processHTTPRequest(_ data: Data, connection: NWConnection) {
        guard let request = String(data: data, encoding: .utf8) else {
            sendResponse(connection, status: "400 Bad Request", body: ["error": "Invalid request"])
            return
        }

        // Parse HTTP request
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            sendResponse(connection, status: "400 Bad Request", body: ["error": "Empty request"])
            return
        }

        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else {
            sendResponse(connection, status: "400 Bad Request", body: ["error": "Malformed request"])
            return
        }

        let method = String(parts[0])
        let path = String(parts[1])

        // Parse body for POST requests
        var json: [String: Any] = [:]
        if method == "POST" {
            if let bodyData = extractBody(from: lines),
               let parsed = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
                json = parsed
            }
        }

        // Route request
        routeRequest(method: method, path: path, json: json, connection: connection)
    }

    private func extractBody(from lines: [String]) -> Data? {
        var bodyStartIndex: Int?
        for (index, line) in lines.enumerated() {
            if line.isEmpty && index + 1 < lines.count {
                bodyStartIndex = index + 1
                break
            }
        }

        guard let startIndex = bodyStartIndex else { return nil }
        let body = lines[startIndex...].joined(separator: "\r\n")
        return body.data(using: .utf8)
    }

    // MARK: - Routing

    private func routeRequest(method: String, path: String, json: [String: Any], connection: NWConnection) {
        switch (method, path) {

        // ============ MACRO OPTIONS ============
        case ("POST", "/macro-options"):
            guard let options = json["options"] as? [[String: Any]] else {
                sendResponse(connection, status: "400 Bad Request", body: ["error": "Missing options"])
                return
            }
            let needsAttention = json["needsAttention"] as? Bool ?? true

            DispatchQueue.main.async {
                self.onMacroOptions?(options, needsAttention)
            }

            print("📋 MCP: Received \(options.count) macro options")
            sendResponse(connection, status: "200 OK", body: ["success": true])

        case ("POST", "/macro-clear"):
            DispatchQueue.main.async {
                self.onMacroClear?()
            }
            print("📋 MCP: Cleared macro options")
            sendResponse(connection, status: "200 OK", body: ["success": true])

        // ============ NOTIFICATIONS ============
        case ("POST", "/notify"):
            let message = json["message"] as? String ?? ""
            let playSound = json["playSound"] as? Bool ?? true
            let haptic = json["haptic"] as? Bool ?? true

            DispatchQueue.main.async {
                self.onNotification?(message, playSound, haptic)
            }

            print("🔔 MCP: Notification - \(message)")
            sendResponse(connection, status: "200 OK", body: ["success": true])

        // ============ STATUS ============
        case ("POST", "/status"), ("GET", "/status"):
            if let status = getConnectionStatus?() {
                sendResponse(connection, status: "200 OK", body: [
                    "connected": status.connected,
                    "deviceName": status.deviceName ?? NSNull()
                ])
            } else {
                sendResponse(connection, status: "200 OK", body: ["connected": false])
            }

        // ============ HEALTH CHECK ============
        case ("GET", "/health"), ("POST", "/health"):
            sendResponse(connection, status: "200 OK", body: [
                "status": "ok",
                "service": "ClaudeController",
                "version": "1.0.0"
            ])

        // ============ PERMISSION REQUEST (BLOCKING) ============
        case ("POST", "/permission-request"):
            let tool = json["tool"] as? String ?? "Unknown"
            let details = json["details"] as? String ?? ""
            let options = json["options"] as? [[String: Any]] ?? []
            let requestId = UUID().uuidString

            // Store pending request - DON'T respond yet
            permissionLock.lock()
            pendingPermissions[requestId] = PendingPermission(
                connection: connection,
                requestId: requestId,
                timestamp: Date()
            )
            permissionLock.unlock()

            // Forward to iPad via callback
            DispatchQueue.main.async {
                self.onPermissionRequest?(requestId, tool, details, options)
            }

            print("🔐 MCP: Permission request \(requestId) for \(tool) with \(options.count) options - waiting for iPad response...")
            // NOTE: We do NOT call sendResponse here - the connection stays open
            // until resolvePermission() is called with the iPad's decision

        default:
            sendResponse(connection, status: "404 Not Found", body: ["error": "Unknown endpoint: \(path)"])
        }
    }

    // MARK: - Permission Resolution

    /// Resolve a pending permission request with the iPad's decision
    func resolvePermission(requestId: String, decision: String) {
        permissionLock.lock()
        guard let pending = pendingPermissions.removeValue(forKey: requestId) else {
            permissionLock.unlock()
            print("⚠️ Permission request \(requestId) not found or already resolved")
            return
        }
        permissionLock.unlock()

        print("🔐 Resolving permission \(requestId) with decision: \(decision)")
        sendResponse(pending.connection, status: "200 OK", body: ["decision": decision])
    }

    /// Clean up stale pending permissions (older than timeout)
    func cleanupStalePermissions(olderThan timeout: TimeInterval = 300) {
        let cutoff = Date().addingTimeInterval(-timeout)

        permissionLock.lock()
        let staleIds = pendingPermissions.filter { $0.value.timestamp < cutoff }.map { $0.key }
        for id in staleIds {
            if let pending = pendingPermissions.removeValue(forKey: id) {
                print("⚠️ Permission request \(id) timed out")
                sendResponse(pending.connection, status: "200 OK", body: ["decision": "deny", "reason": "timeout"])
            }
        }
        permissionLock.unlock()
    }

    private func sendResponse(_ connection: NWConnection, status: String, body: [String: Any]) {
        let jsonData = (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
        let bodyString = String(data: jsonData, encoding: .utf8) ?? "{}"

        let response = """
        HTTP/1.1 \(status)\r
        Content-Type: application/json\r
        Content-Length: \(bodyString.utf8.count)\r
        Connection: close\r
        \r
        \(bodyString)
        """

        if let data = response.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }
}
