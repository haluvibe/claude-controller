// KeyboardView.swift
// iPad Trackpad Controller - Simple On-Screen Keyboard
// iOS 18+ / iPadOS 18+

import SwiftUI

struct KeyboardView: View {
    @ObservedObject var connectionManager: ConnectionManager

    // Modifier state
    @State private var isShiftActive = false
    @State private var isCommandActive = false
    @State private var isOptionActive = false
    @State private var isControlActive = false

    var body: some View {
        VStack(spacing: 6) {
            // Row 1: Numbers
            KeyRow(keys: row1Keys, connectionManager: connectionManager, isShiftActive: isShiftActive, modifiers: currentModifiers)

            // Row 2: QWERTY
            KeyRow(keys: row2Keys, connectionManager: connectionManager, isShiftActive: isShiftActive, modifiers: currentModifiers)

            // Row 3: ASDF
            KeyRow(keys: row3Keys, connectionManager: connectionManager, isShiftActive: isShiftActive, modifiers: currentModifiers)

            // Row 4: ZXCV
            KeyRow(keys: row4Keys, connectionManager: connectionManager, isShiftActive: isShiftActive, modifiers: currentModifiers)

            // Row 5: Modifiers + Space
            ModifierRow(
                connectionManager: connectionManager,
                isShiftActive: $isShiftActive,
                isCommandActive: $isCommandActive,
                isOptionActive: $isOptionActive,
                isControlActive: $isControlActive
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(Color(white: 0.12))
    }

    private var currentModifiers: UInt32 {
        var mods: UInt32 = 0
        if isShiftActive { mods |= 0x020000 }      // kCGEventFlagMaskShift
        if isControlActive { mods |= 0x040000 }    // kCGEventFlagMaskControl
        if isOptionActive { mods |= 0x080000 }     // kCGEventFlagMaskAlternate
        if isCommandActive { mods |= 0x100000 }    // kCGEventFlagMaskCommand
        return mods
    }

    // MARK: - Key Definitions

    private var row1Keys: [KeyDef] {
        [
            KeyDef(label: "1", shifted: "!", code: 0x12),
            KeyDef(label: "2", shifted: "@", code: 0x13),
            KeyDef(label: "3", shifted: "#", code: 0x14),
            KeyDef(label: "4", shifted: "$", code: 0x15),
            KeyDef(label: "5", shifted: "%", code: 0x17),
            KeyDef(label: "6", shifted: "^", code: 0x16),
            KeyDef(label: "7", shifted: "&", code: 0x1A),
            KeyDef(label: "8", shifted: "*", code: 0x1C),
            KeyDef(label: "9", shifted: "(", code: 0x19),
            KeyDef(label: "0", shifted: ")", code: 0x1D),
            KeyDef(label: "Del", shifted: "Del", code: 0x33, width: 1.5),
        ]
    }

    private var row2Keys: [KeyDef] {
        [
            KeyDef(label: "Q", shifted: "Q", code: 0x0C),
            KeyDef(label: "W", shifted: "W", code: 0x0D),
            KeyDef(label: "E", shifted: "E", code: 0x0E),
            KeyDef(label: "R", shifted: "R", code: 0x0F),
            KeyDef(label: "T", shifted: "T", code: 0x11),
            KeyDef(label: "Y", shifted: "Y", code: 0x10),
            KeyDef(label: "U", shifted: "U", code: 0x20),
            KeyDef(label: "I", shifted: "I", code: 0x22),
            KeyDef(label: "O", shifted: "O", code: 0x1F),
            KeyDef(label: "P", shifted: "P", code: 0x23),
        ]
    }

    private var row3Keys: [KeyDef] {
        [
            KeyDef(label: "A", shifted: "A", code: 0x00),
            KeyDef(label: "S", shifted: "S", code: 0x01),
            KeyDef(label: "D", shifted: "D", code: 0x02),
            KeyDef(label: "F", shifted: "F", code: 0x03),
            KeyDef(label: "G", shifted: "G", code: 0x05),
            KeyDef(label: "H", shifted: "H", code: 0x04),
            KeyDef(label: "J", shifted: "J", code: 0x26),
            KeyDef(label: "K", shifted: "K", code: 0x28),
            KeyDef(label: "L", shifted: "L", code: 0x25),
            KeyDef(label: "Return", shifted: "Return", code: 0x24, width: 1.5),
        ]
    }

    private var row4Keys: [KeyDef] {
        [
            KeyDef(label: "Z", shifted: "Z", code: 0x06),
            KeyDef(label: "X", shifted: "X", code: 0x07),
            KeyDef(label: "C", shifted: "C", code: 0x08),
            KeyDef(label: "V", shifted: "V", code: 0x09),
            KeyDef(label: "B", shifted: "B", code: 0x0B),
            KeyDef(label: "N", shifted: "N", code: 0x2D),
            KeyDef(label: "M", shifted: "M", code: 0x2E),
            KeyDef(label: ",", shifted: "<", code: 0x2B),
            KeyDef(label: ".", shifted: ">", code: 0x2F),
            KeyDef(label: "/", shifted: "?", code: 0x2C),
        ]
    }
}

// MARK: - Key Definition

struct KeyDef: Identifiable {
    let id = UUID()
    let label: String
    let shifted: String
    let code: UInt16
    var width: CGFloat = 1.0
}

// MARK: - Key Row

struct KeyRow: View {
    let keys: [KeyDef]
    let connectionManager: ConnectionManager
    let isShiftActive: Bool
    let modifiers: UInt32

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys) { key in
                KeyButton(
                    key: key,
                    isShiftActive: isShiftActive,
                    modifiers: modifiers,
                    connectionManager: connectionManager
                )
            }
        }
    }
}

// MARK: - Key Button

struct KeyButton: View {
    let key: KeyDef
    let isShiftActive: Bool
    let modifiers: UInt32
    let connectionManager: ConnectionManager

    private var displayLabel: String {
        if key.label.count == 1 {
            return isShiftActive ? key.shifted : key.label.lowercased()
        }
        return key.label
    }

    var body: some View {
        Button(action: {
            connectionManager.sendKeyPress(keyCode: key.code, modifiers: modifiers)
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }) {
            Text(displayLabel)
                .font(.system(size: key.label.count > 1 ? 12 : 18, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color(white: 0.25))
                .cornerRadius(6)
        }
        .frame(width: baseKeyWidth * key.width + (key.width - 1) * 4)
    }

    private var baseKeyWidth: CGFloat {
        // Calculate based on screen width
        let screenWidth = UIScreen.main.bounds.width
        let totalKeys: CGFloat = 10.5
        let spacing: CGFloat = 4 * 10
        let padding: CGFloat = 16
        return (screenWidth - spacing - padding) / totalKeys
    }
}

// MARK: - Modifier Row

struct ModifierRow: View {
    let connectionManager: ConnectionManager
    @Binding var isShiftActive: Bool
    @Binding var isCommandActive: Bool
    @Binding var isOptionActive: Bool
    @Binding var isControlActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            // Shift
            ModifierButton(label: "Shift", isActive: $isShiftActive)

            // Control
            ModifierButton(label: "Ctrl", isActive: $isControlActive)

            // Option
            ModifierButton(label: "Opt", isActive: $isOptionActive)

            // Command
            ModifierButton(label: "Cmd", isActive: $isCommandActive)

            // Space bar
            Button(action: {
                let mods = buildModifiers()
                connectionManager.sendKeyPress(keyCode: 0x31, modifiers: mods)
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }) {
                Text("")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color(white: 0.3))
                    .cornerRadius(6)
            }

            // Arrow keys
            HStack(spacing: 2) {
                ArrowButton(direction: .left, connectionManager: connectionManager)
                VStack(spacing: 2) {
                    ArrowButton(direction: .up, connectionManager: connectionManager)
                    ArrowButton(direction: .down, connectionManager: connectionManager)
                }
                ArrowButton(direction: .right, connectionManager: connectionManager)
            }
        }
    }

    private func buildModifiers() -> UInt32 {
        var mods: UInt32 = 0
        if isShiftActive { mods |= 0x020000 }
        if isControlActive { mods |= 0x040000 }
        if isOptionActive { mods |= 0x080000 }
        if isCommandActive { mods |= 0x100000 }
        return mods
    }
}

// MARK: - Modifier Button

struct ModifierButton: View {
    let label: String
    @Binding var isActive: Bool

    var body: some View {
        Button(action: {
            isActive.toggle()
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isActive ? .white : .gray)
                .frame(minWidth: 50, minHeight: 44)
                .background(isActive ? Color.blue : Color(white: 0.2))
                .cornerRadius(6)
        }
    }
}

// MARK: - Arrow Button

struct ArrowButton: View {
    enum Direction {
        case up, down, left, right

        var iconName: String {
            switch self {
            case .up: return "chevron.up"
            case .down: return "chevron.down"
            case .left: return "chevron.left"
            case .right: return "chevron.right"
            }
        }

        var keyCode: UInt16 {
            switch self {
            case .up: return 0x7E
            case .down: return 0x7D
            case .left: return 0x7B
            case .right: return 0x7C
            }
        }
    }

    let direction: Direction
    let connectionManager: ConnectionManager

    var body: some View {
        Button(action: {
            connectionManager.sendKeyPress(keyCode: direction.keyCode)
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        }) {
            Image(systemName: direction.iconName)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: direction == .up || direction == .down ? 20 : 36)
                .background(Color(white: 0.25))
                .cornerRadius(4)
        }
    }
}

// MARK: - Preview

#Preview {
    KeyboardView(connectionManager: ConnectionManager())
        .background(Color.black)
}
