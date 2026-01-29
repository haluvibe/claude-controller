// MacroBarView.swift
// iPad Trackpad Controller - Macro Option Buttons
// iOS 18+ / iPadOS 18+

import SwiftUI

/// Displays macro option buttons - always shows Accept button, plus any Claude options
/// Also shows permission prompts when Claude Code needs Allow/Deny
struct MacroBarView: View {
    @ObservedObject var macroManager: MacroManager
    let connectionManager: ConnectionManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Permission request options (takes priority)
                if let permission = macroManager.pendingPermission {
                    // Show permission context label
                    PermissionLabel(tool: permission.tool)

                    // Show permission options as regular numbered buttons
                    ForEach(permission.options) { option in
                        PermissionButton(option: option) {
                            macroManager.selectPermissionOption(option)
                        }
                    }
                } else {
                    // Utility buttons - always available
                    EscapeButton(connectionManager: connectionManager)
                    CopyButton(connectionManager: connectionManager)
                    PasteButton(connectionManager: connectionManager)

                    // Accept Suggestion button (Right Arrow + Enter for CLI autocomplete)
                    AcceptSuggestionButton(connectionManager: connectionManager)

                    // Claude's numbered options (when available)
                    ForEach(macroManager.options) { option in
                        MacroButton(option: option) {
                            let number = macroManager.selectOption(option)
                            connectionManager.sendMacroSelect(optionNumber: number)
                        }
                    }

                    // "Other" button - shown when there are options, sends next number to focus text input
                    if !macroManager.options.isEmpty {
                        OtherButton(
                            nextNumber: macroManager.options.count + 1,
                            connectionManager: connectionManager,
                            macroManager: macroManager
                        )
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.12))
                .shadow(color: .black.opacity(0.3), radius: 4, y: -2)
        )
    }
}

/// Label showing the tool requesting permission
struct PermissionLabel: View {
    let tool: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.shield")
                .font(.system(size: 12, weight: .semibold))
            Text(tool)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.2))
        )
    }
}

/// Permission option button - styled like macro buttons
struct PermissionButton: View {
    let option: PermissionOption
    let action: () -> Void

    @State private var isPressed = false

    // Color based on decision type
    private var buttonColor: Color {
        if option.decision.contains("deny") {
            return Color.red.opacity(0.7)
        } else if option.decision.contains("always") || option.decision.contains("session") {
            return Color.green.opacity(0.7)
        } else {
            return Color.blue.opacity(0.7)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Number badge
                Text("\(option.number)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white))

                // Option text
                Text(truncatedText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPressed ? buttonColor.opacity(1.0) : buttonColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(MacroButtonStyle(isPressed: $isPressed))
    }

    private var truncatedText: String {
        let maxLength = 30
        if option.text.count > maxLength {
            return String(option.text.prefix(maxLength - 1)) + "…"
        }
        return option.text
    }
}


/// Escape button - sends Escape key (keyCode 53)
struct EscapeButton: View {
    let connectionManager: ConnectionManager
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            connectionManager.sendKeyPress(keyCode: 53, modifiers: 0)
        }) {
            HStack(spacing: 6) {
                Image(systemName: "escape")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Text("Esc")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPressed ? Color.gray.opacity(0.9) : Color.gray.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(MacroButtonStyle(isPressed: $isPressed))
    }
}

/// Copy button - sends Cmd+C (keyCode 8 + Command modifier)
struct CopyButton: View {
    let connectionManager: ConnectionManager
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            connectionManager.sendKeyPress(keyCode: 8, modifiers: 0x100000)
        }) {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Text("Copy")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPressed ? Color.gray.opacity(0.9) : Color.gray.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(MacroButtonStyle(isPressed: $isPressed))
    }
}

/// Paste button - sends Cmd+V (keyCode 9 + Command modifier)
struct PasteButton: View {
    let connectionManager: ConnectionManager
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            connectionManager.sendKeyPress(keyCode: 9, modifiers: 0x100000)
        }) {
            HStack(spacing: 6) {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Text("Paste")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPressed ? Color.gray.opacity(0.9) : Color.gray.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(MacroButtonStyle(isPressed: $isPressed))
    }
}

/// Accept Suggestion button - sends Right Arrow + Enter for CLI autocomplete
struct AcceptSuggestionButton: View {
    let connectionManager: ConnectionManager
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            // Send Right Arrow (keyCode 124) then Return (keyCode 36)
            connectionManager.sendKeyPress(keyCode: 124, modifiers: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                connectionManager.sendKeyPress(keyCode: 36, modifiers: 0)
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Text("Accept Suggestion")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPressed ? Color.green.opacity(0.9) : Color.green.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(MacroButtonStyle(isPressed: $isPressed))
    }
}

/// "Other" button - sends the next number WITHOUT Enter to allow custom text entry
struct OtherButton: View {
    let nextNumber: Int
    let connectionManager: ConnectionManager
    let macroManager: MacroManager
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            // Send the next number WITHOUT Enter - user will type custom response then press Enter
            connectionManager.sendMacroSelectWithoutEnter(optionNumber: nextNumber)
            // Clear options so user can type their custom text
            macroManager.clearOptions()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "text.cursor")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)

                Text("Other")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPressed ? Color.orange.opacity(0.9) : Color.orange.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(MacroButtonStyle(isPressed: $isPressed))
    }
}

/// Individual macro option button
struct MacroButton: View {
    let option: MacroOption
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // Number badge
                Text("\(option.number)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.white))

                // Option text (truncated)
                Text(truncatedText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPressed ? Color.blue.opacity(0.8) : Color(white: 0.22))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(MacroButtonStyle(isPressed: $isPressed))
    }

    private var truncatedText: String {
        let maxLength = 25
        if option.text.count > maxLength {
            return String(option.text.prefix(maxLength - 1)) + "…"
        }
        return option.text
    }
}

/// Custom button style for press animation
struct MacroButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(white: 0.15)
            .ignoresSafeArea()

        VStack {
            Spacer()

            MacroBarView(
                macroManager: {
                    let manager = MacroManager()
                    manager.updateOptions([
                        MacroOption(number: 1, text: "Yes, proceed"),
                        MacroOption(number: 2, text: "No, cancel"),
                        MacroOption(number: 3, text: "Skip this step"),
                        MacroOption(number: 4, text: "Show more options")
                    ], needsAttention: true)
                    return manager
                }(),
                connectionManager: ConnectionManager()
            )
            .padding(.bottom, 100)
        }
    }
}
