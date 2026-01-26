// KeyboardView.swift
// iPad Trackpad App - Virtual Keyboard for Mac Control
// iOS 18+

import SwiftUI

struct KeyboardView: View {
    @ObservedObject var viewModel: TrackpadViewModel
    @State private var showFunctionRow = true
    @State private var isShiftActive = false
    @State private var isCommandActive = false
    @State private var isOptionActive = false
    @State private var isControlActive = false
    @State private var isCapsLockActive = false

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator area
            Rectangle()
                .fill(Color.clear)
                .frame(height: 20)

            // Function row (optional)
            if showFunctionRow {
                FunctionRowView(viewModel: viewModel)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)
            }

            // Main keyboard
            VStack(spacing: 6) {
                // Number row
                KeyboardRow(
                    keys: numberRowKeys,
                    viewModel: viewModel,
                    isShiftActive: isShiftActive,
                    modifiers: currentModifiers
                )

                // QWERTY rows
                KeyboardRow(
                    keys: qwertyRow,
                    viewModel: viewModel,
                    isShiftActive: isShiftActive,
                    modifiers: currentModifiers
                )

                KeyboardRow(
                    keys: asdfRow,
                    viewModel: viewModel,
                    isShiftActive: isShiftActive,
                    modifiers: currentModifiers
                )

                KeyboardRow(
                    keys: zxcvRow,
                    viewModel: viewModel,
                    isShiftActive: isShiftActive,
                    modifiers: currentModifiers
                )

                // Bottom row with modifiers and space
                BottomKeyboardRow(
                    viewModel: viewModel,
                    isShiftActive: $isShiftActive,
                    isCommandActive: $isCommandActive,
                    isOptionActive: $isOptionActive,
                    isControlActive: $isControlActive,
                    isCapsLockActive: $isCapsLockActive
                )
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 16)
        }
        .background(Color(.systemGray6))
    }

    private var currentModifiers: KeyModifiers {
        var modifiers: KeyModifiers = []
        if isCommandActive { modifiers.insert(.command) }
        if isShiftActive { modifiers.insert(.shift) }
        if isOptionActive { modifiers.insert(.option) }
        if isControlActive { modifiers.insert(.control) }
        return modifiers
    }

    // MARK: - Key Definitions

    private var numberRowKeys: [KeyDefinition] {
        [
            KeyDefinition(primary: "`", shifted: "~", keyCode: .escape),
            KeyDefinition(primary: "1", shifted: "!", keyCode: .a),
            KeyDefinition(primary: "2", shifted: "@", keyCode: .s),
            KeyDefinition(primary: "3", shifted: "#", keyCode: .d),
            KeyDefinition(primary: "4", shifted: "$", keyCode: .f),
            KeyDefinition(primary: "5", shifted: "%", keyCode: .g),
            KeyDefinition(primary: "6", shifted: "^", keyCode: .h),
            KeyDefinition(primary: "7", shifted: "&", keyCode: .j),
            KeyDefinition(primary: "8", shifted: "*", keyCode: .k),
            KeyDefinition(primary: "9", shifted: "(", keyCode: .l),
            KeyDefinition(primary: "0", shifted: ")", keyCode: .a),
            KeyDefinition(primary: "-", shifted: "_", keyCode: .s),
            KeyDefinition(primary: "=", shifted: "+", keyCode: .d),
            KeyDefinition(primary: "Delete", shifted: "Delete", keyCode: .delete, width: 1.5, isSpecial: true)
        ]
    }

    private var qwertyRow: [KeyDefinition] {
        [
            KeyDefinition(primary: "Tab", shifted: "Tab", keyCode: .tab, width: 1.5, isSpecial: true),
            KeyDefinition(primary: "Q", shifted: "Q", keyCode: .a),
            KeyDefinition(primary: "W", shifted: "W", keyCode: .s),
            KeyDefinition(primary: "E", shifted: "E", keyCode: .d),
            KeyDefinition(primary: "R", shifted: "R", keyCode: .f),
            KeyDefinition(primary: "T", shifted: "T", keyCode: .g),
            KeyDefinition(primary: "Y", shifted: "Y", keyCode: .h),
            KeyDefinition(primary: "U", shifted: "U", keyCode: .j),
            KeyDefinition(primary: "I", shifted: "I", keyCode: .k),
            KeyDefinition(primary: "O", shifted: "O", keyCode: .l),
            KeyDefinition(primary: "P", shifted: "P", keyCode: .a),
            KeyDefinition(primary: "[", shifted: "{", keyCode: .s),
            KeyDefinition(primary: "]", shifted: "}", keyCode: .d),
            KeyDefinition(primary: "\\", shifted: "|", keyCode: .f, width: 1.0)
        ]
    }

    private var asdfRow: [KeyDefinition] {
        [
            KeyDefinition(primary: "Caps", shifted: "Caps", keyCode: .capsLock, width: 1.75, isSpecial: true),
            KeyDefinition(primary: "A", shifted: "A", keyCode: .a),
            KeyDefinition(primary: "S", shifted: "S", keyCode: .s),
            KeyDefinition(primary: "D", shifted: "D", keyCode: .d),
            KeyDefinition(primary: "F", shifted: "F", keyCode: .f),
            KeyDefinition(primary: "G", shifted: "G", keyCode: .g),
            KeyDefinition(primary: "H", shifted: "H", keyCode: .h),
            KeyDefinition(primary: "J", shifted: "J", keyCode: .j),
            KeyDefinition(primary: "K", shifted: "K", keyCode: .k),
            KeyDefinition(primary: "L", shifted: "L", keyCode: .l),
            KeyDefinition(primary: ";", shifted: ":", keyCode: .a),
            KeyDefinition(primary: "'", shifted: "\"", keyCode: .s),
            KeyDefinition(primary: "Return", shifted: "Return", keyCode: .enter, width: 1.75, isSpecial: true)
        ]
    }

    private var zxcvRow: [KeyDefinition] {
        [
            KeyDefinition(primary: "Shift", shifted: "Shift", keyCode: .shift, width: 2.25, isSpecial: true),
            KeyDefinition(primary: "Z", shifted: "Z", keyCode: .a),
            KeyDefinition(primary: "X", shifted: "X", keyCode: .s),
            KeyDefinition(primary: "C", shifted: "C", keyCode: .d),
            KeyDefinition(primary: "V", shifted: "V", keyCode: .f),
            KeyDefinition(primary: "B", shifted: "B", keyCode: .g),
            KeyDefinition(primary: "N", shifted: "N", keyCode: .h),
            KeyDefinition(primary: "M", shifted: "M", keyCode: .j),
            KeyDefinition(primary: ",", shifted: "<", keyCode: .k),
            KeyDefinition(primary: ".", shifted: ">", keyCode: .l),
            KeyDefinition(primary: "/", shifted: "?", keyCode: .a),
            KeyDefinition(primary: "Shift", shifted: "Shift", keyCode: .shift, width: 2.25, isSpecial: true)
        ]
    }
}

// MARK: - Key Definition

struct KeyDefinition: Identifiable {
    let id = UUID()
    let primary: String
    let shifted: String
    let keyCode: KeyCode
    var width: CGFloat = 1.0
    var isSpecial: Bool = false
}

// MARK: - Function Row

struct FunctionRowView: View {
    @ObservedObject var viewModel: TrackpadViewModel

    private let functionKeys: [(String, String, KeyCode)] = [
        ("esc", "Escape", .escape),
        ("F1", "Brightness Down", .f1),
        ("F2", "Brightness Up", .f2),
        ("F3", "Mission Control", .f3),
        ("F4", "Launchpad", .f4),
        ("F5", "Keyboard Light", .f5),
        ("F6", "Dictation", .f6),
        ("F7", "Rewind", .f7),
        ("F8", "Play/Pause", .f8),
        ("F9", "Fast Forward", .f9),
        ("F10", "Mute", .f10),
        ("F11", "Volume Down", .f11),
        ("F12", "Volume Up", .f12)
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(functionKeys.enumerated()), id: \.offset) { _, key in
                FunctionKeyButton(
                    label: key.0,
                    sublabel: key.1,
                    keyCode: key.2,
                    viewModel: viewModel
                )
            }
        }
    }
}

struct FunctionKeyButton: View {
    let label: String
    let sublabel: String
    let keyCode: KeyCode
    @ObservedObject var viewModel: TrackpadViewModel

    var body: some View {
        Button(action: {
            viewModel.sendKeyPress(key: keyCode, modifiers: .function)
            HapticFeedbackManager.shared.tap(intensity: 1)
        }) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(Color(.systemGray5))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Keyboard Row

struct KeyboardRow: View {
    let keys: [KeyDefinition]
    @ObservedObject var viewModel: TrackpadViewModel
    let isShiftActive: Bool
    let modifiers: KeyModifiers

    var body: some View {
        HStack(spacing: 4) {
            ForEach(keys) { key in
                KeyButton(
                    definition: key,
                    isShiftActive: isShiftActive,
                    modifiers: modifiers,
                    viewModel: viewModel
                )
            }
        }
    }
}

// MARK: - Key Button

struct KeyButton: View {
    let definition: KeyDefinition
    let isShiftActive: Bool
    let modifiers: KeyModifiers
    @ObservedObject var viewModel: TrackpadViewModel

    private var displayText: String {
        if definition.isSpecial {
            return definition.primary
        }
        return isShiftActive ? definition.shifted : definition.primary.lowercased()
    }

    var body: some View {
        Button(action: {
            if definition.primary.count == 1 {
                let text = isShiftActive ? definition.shifted : definition.primary.lowercased()
                viewModel.sendText(text)
            } else {
                viewModel.sendKeyPress(key: definition.keyCode, modifiers: modifiers)
            }
            HapticFeedbackManager.shared.tap(intensity: 1)
        }) {
            Text(displayText)
                .font(.system(size: definition.isSpecial ? 12 : 18, weight: .regular))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(definition.isSpecial ? Color(.systemGray5) : Color(.systemGray4))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .frame(width: baseWidth * definition.width + (definition.width - 1) * 4)
    }

    private var baseWidth: CGFloat {
        // Calculate base key width based on screen size
        let screenWidth = UIScreen.main.bounds.width
        let totalKeys: CGFloat = 14.5 // Approximate total width units
        let spacing: CGFloat = 4 * 13 // Spacing between keys
        let padding: CGFloat = 16 // Horizontal padding
        return (screenWidth - spacing - padding) / totalKeys
    }
}

// MARK: - Bottom Row with Modifiers

struct BottomKeyboardRow: View {
    @ObservedObject var viewModel: TrackpadViewModel
    @Binding var isShiftActive: Bool
    @Binding var isCommandActive: Bool
    @Binding var isOptionActive: Bool
    @Binding var isControlActive: Bool
    @Binding var isCapsLockActive: Bool

    var body: some View {
        HStack(spacing: 4) {
            // fn key
            ModifierKeyButton(label: "fn", isActive: false) {}

            // Control
            ModifierKeyButton(label: "control", isActive: isControlActive) {
                isControlActive.toggle()
            }

            // Option
            ModifierKeyButton(label: "option", isActive: isOptionActive) {
                isOptionActive.toggle()
            }

            // Command (left)
            ModifierKeyButton(label: "command", isActive: isCommandActive, width: 1.25) {
                isCommandActive.toggle()
            }

            // Space bar
            Button(action: {
                viewModel.sendKeyPress(key: .space)
                HapticFeedbackManager.shared.tap(intensity: 1)
            }) {
                Text("")
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color(.systemGray4))
                    .cornerRadius(6)
            }
            .buttonStyle(.plain)

            // Command (right)
            ModifierKeyButton(label: "command", isActive: isCommandActive, width: 1.25) {
                isCommandActive.toggle()
            }

            // Option
            ModifierKeyButton(label: "option", isActive: isOptionActive) {
                isOptionActive.toggle()
            }

            // Arrow keys cluster
            ArrowKeysView(viewModel: viewModel)
        }
    }
}

struct ModifierKeyButton: View {
    let label: String
    let isActive: Bool
    var width: CGFloat = 1.0
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
            HapticFeedbackManager.shared.tap(intensity: 1)
        }) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isActive ? .white : .primary)
                .frame(minWidth: 50 * width, minHeight: 44)
                .background(isActive ? Color.blue : Color(.systemGray5))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

struct ArrowKeysView: View {
    @ObservedObject var viewModel: TrackpadViewModel

    var body: some View {
        VStack(spacing: 2) {
            // Up arrow
            ArrowKeyButton(direction: .up, viewModel: viewModel)

            HStack(spacing: 2) {
                ArrowKeyButton(direction: .left, viewModel: viewModel)
                ArrowKeyButton(direction: .down, viewModel: viewModel)
                ArrowKeyButton(direction: .right, viewModel: viewModel)
            }
        }
    }
}

struct ArrowKeyButton: View {
    let direction: ArrowDirection
    @ObservedObject var viewModel: TrackpadViewModel

    enum ArrowDirection {
        case up, down, left, right

        var iconName: String {
            switch self {
            case .up: return "chevron.up"
            case .down: return "chevron.down"
            case .left: return "chevron.left"
            case .right: return "chevron.right"
            }
        }

        var keyCode: KeyCode {
            switch self {
            case .up: return .upArrow
            case .down: return .downArrow
            case .left: return .leftArrow
            case .right: return .rightArrow
            }
        }
    }

    var body: some View {
        Button(action: {
            viewModel.sendKeyPress(key: direction.keyCode)
            HapticFeedbackManager.shared.tap(intensity: 1)
        }) {
            Image(systemName: direction.iconName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 32, height: direction == .up || direction == .down ? 20 : 32)
                .background(Color(.systemGray5))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    KeyboardView(viewModel: TrackpadViewModel())
}
