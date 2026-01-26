//
//  Protocol.swift
//  ClaudeController Shared Protocol
//
//  Shared message types for iPad-to-macOS communication.
//  Personal use only - minimal security complexity.
//

import Foundation

// MARK: - Protocol Version

let kProtocolVersion: Int = 1

// MARK: - Mouse Button

enum MouseButton: Int, Codable {
    case left = 0
    case right = 1
    case middle = 2
}

// MARK: - Message Types

enum ControlMessage: Codable {
    case handshake(deviceName: String, protocolVersion: Int)
    case handshakeAck(success: Bool, serverName: String)
    case move(dx: Float, dy: Float)
    case click(button: MouseButton, clickCount: Int)
    case keyDown(keyCode: UInt16, modifiers: UInt32)
    case keyUp(keyCode: UInt16)
    case disconnect

    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case type
        case payload
    }

    private enum MessageType: String, Codable {
        case handshake
        case handshakeAck
        case move
        case click
        case keyDown
        case keyUp
        case disconnect
    }

    // MARK: - Payload Types

    private struct HandshakePayload: Codable {
        let deviceName: String
        let protocolVersion: Int
    }

    private struct HandshakeAckPayload: Codable {
        let success: Bool
        let serverName: String
    }

    private struct MovePayload: Codable {
        let dx: Float
        let dy: Float
    }

    private struct ClickPayload: Codable {
        let button: MouseButton
        let clickCount: Int
    }

    private struct KeyDownPayload: Codable {
        let keyCode: UInt16
        let modifiers: UInt32
    }

    private struct KeyUpPayload: Codable {
        let keyCode: UInt16
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageType.self, forKey: .type)

        switch type {
        case .handshake:
            let payload = try container.decode(HandshakePayload.self, forKey: .payload)
            self = .handshake(deviceName: payload.deviceName, protocolVersion: payload.protocolVersion)
        case .handshakeAck:
            let payload = try container.decode(HandshakeAckPayload.self, forKey: .payload)
            self = .handshakeAck(success: payload.success, serverName: payload.serverName)
        case .move:
            let payload = try container.decode(MovePayload.self, forKey: .payload)
            self = .move(dx: payload.dx, dy: payload.dy)
        case .click:
            let payload = try container.decode(ClickPayload.self, forKey: .payload)
            self = .click(button: payload.button, clickCount: payload.clickCount)
        case .keyDown:
            let payload = try container.decode(KeyDownPayload.self, forKey: .payload)
            self = .keyDown(keyCode: payload.keyCode, modifiers: payload.modifiers)
        case .keyUp:
            let payload = try container.decode(KeyUpPayload.self, forKey: .payload)
            self = .keyUp(keyCode: payload.keyCode)
        case .disconnect:
            self = .disconnect
        }
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .handshake(let deviceName, let protocolVersion):
            try container.encode(MessageType.handshake, forKey: .type)
            try container.encode(HandshakePayload(deviceName: deviceName, protocolVersion: protocolVersion), forKey: .payload)
        case .handshakeAck(let success, let serverName):
            try container.encode(MessageType.handshakeAck, forKey: .type)
            try container.encode(HandshakeAckPayload(success: success, serverName: serverName), forKey: .payload)
        case .move(let dx, let dy):
            try container.encode(MessageType.move, forKey: .type)
            try container.encode(MovePayload(dx: dx, dy: dy), forKey: .payload)
        case .click(let button, let clickCount):
            try container.encode(MessageType.click, forKey: .type)
            try container.encode(ClickPayload(button: button, clickCount: clickCount), forKey: .payload)
        case .keyDown(let keyCode, let modifiers):
            try container.encode(MessageType.keyDown, forKey: .type)
            try container.encode(KeyDownPayload(keyCode: keyCode, modifiers: modifiers), forKey: .payload)
        case .keyUp(let keyCode):
            try container.encode(MessageType.keyUp, forKey: .type)
            try container.encode(KeyUpPayload(keyCode: keyCode), forKey: .payload)
        case .disconnect:
            try container.encode(MessageType.disconnect, forKey: .type)
        }
    }
}

// MARK: - Message Encoding/Decoding Helpers

struct MessageCoder {

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [] // Compact JSON for network efficiency
        return encoder
    }()

    private static let decoder = JSONDecoder()

    /// Encode a message to Data for network transmission
    static func encode(_ message: ControlMessage) throws -> Data {
        return try encoder.encode(message)
    }

    /// Decode a message from received Data
    static func decode(_ data: Data) throws -> ControlMessage {
        return try decoder.decode(ControlMessage.self, from: data)
    }

    /// Encode a message with a length prefix (4-byte big-endian UInt32)
    /// This helps with TCP stream framing
    static func encodeWithLengthPrefix(_ message: ControlMessage) throws -> Data {
        let jsonData = try encode(message)
        var length = UInt32(jsonData.count).bigEndian
        var result = Data(bytes: &length, count: 4)
        result.append(jsonData)
        return result
    }

    /// Read the length prefix from data (returns nil if not enough data)
    static func readLengthPrefix(from data: Data) -> UInt32? {
        guard data.count >= 4 else { return nil }
        let lengthData = data.prefix(4)
        let length = lengthData.withUnsafeBytes { $0.load(as: UInt32.self) }.bigEndian
        return length
    }
}

// MARK: - Common Key Modifiers (for reference)

struct KeyModifiers {
    static let capsLock: UInt32   = 1 << 16
    static let shift: UInt32      = 1 << 17
    static let control: UInt32    = 1 << 18
    static let option: UInt32     = 1 << 19
    static let command: UInt32    = 1 << 20
    static let numericPad: UInt32 = 1 << 21
    static let function: UInt32   = 1 << 23
}

// MARK: - Common Key Codes (subset for quick reference)

struct KeyCodes {
    // Letters (lowercase key codes)
    static let a: UInt16 = 0x00
    static let s: UInt16 = 0x01
    static let d: UInt16 = 0x02
    static let f: UInt16 = 0x03
    static let h: UInt16 = 0x04
    static let g: UInt16 = 0x05
    static let z: UInt16 = 0x06
    static let x: UInt16 = 0x07
    static let c: UInt16 = 0x08
    static let v: UInt16 = 0x09
    static let b: UInt16 = 0x0B
    static let q: UInt16 = 0x0C
    static let w: UInt16 = 0x0D
    static let e: UInt16 = 0x0E
    static let r: UInt16 = 0x0F
    static let y: UInt16 = 0x10
    static let t: UInt16 = 0x11

    // Special keys
    static let returnKey: UInt16 = 0x24
    static let tab: UInt16 = 0x30
    static let space: UInt16 = 0x31
    static let delete: UInt16 = 0x33
    static let escape: UInt16 = 0x35

    // Arrow keys
    static let leftArrow: UInt16 = 0x7B
    static let rightArrow: UInt16 = 0x7C
    static let downArrow: UInt16 = 0x7D
    static let upArrow: UInt16 = 0x7E
}
