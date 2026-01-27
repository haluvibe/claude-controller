// MacroBarView.swift
// iPad Trackpad Controller - Macro Option Buttons
// iOS 18+ / iPadOS 18+

import SwiftUI

/// Displays macro option buttons - always shows Accept button, plus any Claude options
struct MacroBarView: View {
    @ObservedObject var macroManager: MacroManager
    let connectionManager: ConnectionManager

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Accept Suggestion button (Right Arrow + Enter for CLI autocomplete)
                // Always shown as the first option
                AcceptSuggestionButton(connectionManager: connectionManager)

                // Claude's numbered options (when available)
                ForEach(macroManager.options) { option in
                    MacroButton(option: option) {
                        let number = macroManager.selectOption(option)
                        connectionManager.sendMacroSelect(optionNumber: number)
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

                Text("Accept")
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
