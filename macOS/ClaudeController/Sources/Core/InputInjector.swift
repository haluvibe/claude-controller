import Foundation
import CoreGraphics
import AppKit

enum MouseButton: Int, Sendable {
    case left = 0
    case right = 1
    case middle = 2
}

@MainActor
final class InputInjector {
    static let shared = InputInjector()

    private let eventSource: CGEventSource?
    private var currentPosition: CGPoint

    private init() {
        eventSource = CGEventSource(stateID: .hidSystemState)
        currentPosition = NSEvent.mouseLocation
        // Convert from bottom-left to top-left coordinate system
        if let screen = NSScreen.main {
            currentPosition.y = screen.frame.height - currentPosition.y
        }
    }

    // MARK: - Mouse Movement

    func moveCursor(dx: Float, dy: Float) {
        guard let screen = NSScreen.main else { return }

        // Update position with delta
        currentPosition.x += CGFloat(dx)
        currentPosition.y += CGFloat(dy) // Y is already inverted in protocol

        // Clamp to screen bounds
        currentPosition.x = max(0, min(currentPosition.x, screen.frame.width - 1))
        currentPosition.y = max(0, min(currentPosition.y, screen.frame.height - 1))

        // Create and post mouse move event
        if let event = CGEvent(mouseEventSource: eventSource,
                               mouseType: .mouseMoved,
                               mouseCursorPosition: currentPosition,
                               mouseButton: .left) {
            event.post(tap: .cghidEventTap)
        }
    }

    func setCursorPosition(x: Float, y: Float) {
        currentPosition = CGPoint(x: CGFloat(x), y: CGFloat(y))

        if let event = CGEvent(mouseEventSource: eventSource,
                               mouseType: .mouseMoved,
                               mouseCursorPosition: currentPosition,
                               mouseButton: .left) {
            event.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Mouse Clicks

    func click(button: MouseButton, count: Int = 1) {
        let (downType, upType, cgButton) = mouseEventTypes(for: button)

        for i in 0..<count {
            // Mouse down
            if let downEvent = CGEvent(mouseEventSource: eventSource,
                                       mouseType: downType,
                                       mouseCursorPosition: currentPosition,
                                       mouseButton: cgButton) {
                downEvent.setIntegerValueField(.mouseEventClickState, value: Int64(i + 1))
                downEvent.post(tap: .cghidEventTap)
            }

            // Mouse up
            if let upEvent = CGEvent(mouseEventSource: eventSource,
                                     mouseType: upType,
                                     mouseCursorPosition: currentPosition,
                                     mouseButton: cgButton) {
                upEvent.setIntegerValueField(.mouseEventClickState, value: Int64(i + 1))
                upEvent.post(tap: .cghidEventTap)
            }
        }
    }

    func mouseDown(button: MouseButton) {
        let (downType, _, cgButton) = mouseEventTypes(for: button)

        if let event = CGEvent(mouseEventSource: eventSource,
                               mouseType: downType,
                               mouseCursorPosition: currentPosition,
                               mouseButton: cgButton) {
            event.post(tap: .cghidEventTap)
        }
    }

    func mouseUp(button: MouseButton) {
        let (_, upType, cgButton) = mouseEventTypes(for: button)

        if let event = CGEvent(mouseEventSource: eventSource,
                               mouseType: upType,
                               mouseCursorPosition: currentPosition,
                               mouseButton: cgButton) {
            event.post(tap: .cghidEventTap)
        }
    }

    func drag(dx: Float, dy: Float, button: MouseButton = .left) {
        guard let screen = NSScreen.main else { return }

        currentPosition.x += CGFloat(dx)
        currentPosition.y += CGFloat(dy)

        currentPosition.x = max(0, min(currentPosition.x, screen.frame.width - 1))
        currentPosition.y = max(0, min(currentPosition.y, screen.frame.height - 1))

        let dragType: CGEventType = button == .left ? .leftMouseDragged : .rightMouseDragged
        let cgButton: CGMouseButton = button == .left ? .left : .right

        if let event = CGEvent(mouseEventSource: eventSource,
                               mouseType: dragType,
                               mouseCursorPosition: currentPosition,
                               mouseButton: cgButton) {
            event.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Scrolling

    func scroll(dx: Float, dy: Float) {
        if let event = CGEvent(scrollWheelEvent2Source: eventSource,
                               units: .pixel,
                               wheelCount: 2,
                               wheel1: Int32(dy),
                               wheel2: Int32(dx),
                               wheel3: 0) {
            event.post(tap: .cghidEventTap)
        }
    }

    // MARK: - Keyboard

    func keyDown(keyCode: UInt16, modifiers: UInt32 = 0) {
        if let event = CGEvent(keyboardEventSource: eventSource,
                               virtualKey: CGKeyCode(keyCode),
                               keyDown: true) {
            event.flags = CGEventFlags(rawValue: UInt64(modifiers))
            event.post(tap: .cghidEventTap)
        }
    }

    func keyUp(keyCode: UInt16) {
        if let event = CGEvent(keyboardEventSource: eventSource,
                               virtualKey: CGKeyCode(keyCode),
                               keyDown: false) {
            event.post(tap: .cghidEventTap)
        }
    }

    func keyPress(keyCode: UInt16, modifiers: UInt32 = 0) {
        keyDown(keyCode: keyCode, modifiers: modifiers)
        keyUp(keyCode: keyCode)
    }

    func typeText(_ text: String) {
        for char in text {
            if let keyCode = keyCodeForCharacter(char) {
                let needsShift = char.isUppercase || "~!@#$%^&*()_+{}|:\"<>?".contains(char)
                let modifiers: UInt32 = needsShift ? UInt32(CGEventFlags.maskShift.rawValue) : 0
                keyPress(keyCode: keyCode, modifiers: modifiers)
            }
        }
    }

    // MARK: - Three-Finger Swipe Gestures

    func threeFingerSwipe(direction: String) {
        // Use keyboard shortcuts to trigger system gestures
        // These match the default macOS trackpad gestures:
        // - Left/Right: Switch spaces (Control + Arrow)
        // - Up: Mission Control (Control + Up)
        // - Down: App Exposé (Control + Down)

        // Arrow keys need both Control (0x40000) and NumericPad (0x800000) flags
        // macOS expects modifiers = 0x840000 = 8650752 for arrow key shortcuts
        let controlModifier = UInt32(CGEventFlags.maskControl.rawValue)
        let numericPadFlag: UInt32 = 0x800000  // Numeric pad indicator for arrow keys
        let arrowKeyModifiers = controlModifier | numericPadFlag

        switch direction {
        case "left":
            // Swipe left = move to right space (Control + Right Arrow)
            keyPress(keyCode: 124, modifiers: arrowKeyModifiers)

        case "right":
            // Swipe right = move to left space (Control + Left Arrow)
            keyPress(keyCode: 123, modifiers: arrowKeyModifiers)

        case "up":
            // Swipe up = Mission Control (Control + Up Arrow)
            keyPress(keyCode: 126, modifiers: arrowKeyModifiers)

        case "down":
            // Swipe down = App Exposé (Control + Down Arrow)
            keyPress(keyCode: 125, modifiers: arrowKeyModifiers)

        default:
            print("⚠️ Unknown swipe direction: \(direction)")
        }
    }

    // MARK: - Helpers

    private func mouseEventTypes(for button: MouseButton) -> (CGEventType, CGEventType, CGMouseButton) {
        switch button {
        case .left:
            return (.leftMouseDown, .leftMouseUp, .left)
        case .right:
            return (.rightMouseDown, .rightMouseUp, .right)
        case .middle:
            return (.otherMouseDown, .otherMouseUp, .center)
        }
    }

    private func keyCodeForCharacter(_ char: Character) -> UInt16? {
        let keyMap: [Character: UInt16] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
            "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
            "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
            "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
            "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "l": 37,
            "j": 38, "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
            "n": 45, "m": 46, ".": 47, "`": 50, " ": 49, "\n": 36, "\t": 48
        ]

        return keyMap[char.lowercased().first ?? char]
    }
}
