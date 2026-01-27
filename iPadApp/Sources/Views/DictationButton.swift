// DictationButton.swift
// iPad Trackpad Controller - Voice Dictation UI
// iOS 18+ / iPadOS 18+

import SwiftUI
import AVFoundation

struct DictationButton: View {
    @ObservedObject var dictationManager: DictationManager
    @State private var hasPermission = false
    @State private var showingPermissionAlert = false

    var body: some View {
        Button(action: handleTap) {
            ZStack {
                // Background
                Circle()
                    .fill(buttonColor)
                    .frame(width: 60, height: 60)

                // Icon
                if dictationManager.isTranscribing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: dictationManager.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }

                // Recording indicator ring
                if dictationManager.isRecording {
                    Circle()
                        .stroke(Color.red, lineWidth: 3)
                        .frame(width: 70, height: 70)
                        .opacity(pulseOpacity)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: dictationManager.isRecording)
                }
            }
        }
        .disabled(dictationManager.isTranscribing || (dictationManager.isLocalModelLoading && AppConfig.shared.transcriptionMode == .local))
        .alert("Microphone Access Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable microphone access in Settings to use voice dictation.")
        }
        .task {
            hasPermission = await checkPermission()
        }
    }

    private var buttonColor: Color {
        if dictationManager.isRecording {
            return .red
        } else if dictationManager.isTranscribing {
            return .orange
        } else if dictationManager.isLocalModelLoading && AppConfig.shared.transcriptionMode == .local {
            // Only show purple loading state if in local mode
            return .purple
        } else {
            return .blue
        }
    }

    private var pulseOpacity: Double {
        dictationManager.isRecording ? 1.0 : 0.0
    }

    private func handleTap() {
        if dictationManager.isRecording {
            // Stop and send
            Task {
                await dictationManager.stopRecordingAndSend()
            }
        } else {
            // Start recording
            Task {
                // Check if local mode needs model loaded first
                if AppConfig.shared.transcriptionMode == .local && !dictationManager.isLocalModelReady {
                    // Start loading and wait
                    await dictationManager.loadLocalModel()

                    // If still not ready, don't start recording
                    if !dictationManager.isLocalModelReady {
                        return
                    }
                }

                if !hasPermission {
                    hasPermission = await dictationManager.requestPermission()
                }

                if hasPermission {
                    dictationManager.startRecording()
                } else {
                    showingPermissionAlert = true
                }
            }
        }
    }

    private func checkPermission() async -> Bool {
        AVAudioApplication.shared.recordPermission == .granted
    }
}

// MARK: - Cancel Recording Button

struct CancelRecordingButton: View {
    @ObservedObject var dictationManager: DictationManager

    var body: some View {
        if dictationManager.isRecording {
            Button(action: {
                dictationManager.cancelRecording()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(10)
            }
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Auto-Enter / Return Button

struct AutoEnterButton: View {
    @ObservedObject var appConfig = AppConfig.shared
    @ObservedObject var dictationManager: DictationManager

    var body: some View {
        Button(action: handleTap) {
            Image(systemName: "return")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(appConfig.autoEnter ? Color.green : Color(white: 0.25))
                .cornerRadius(10)
                .overlay(
                    // Auto indicator dot
                    Circle()
                        .fill(appConfig.autoEnter ? Color.white : Color.clear)
                        .frame(width: 8, height: 8)
                        .offset(x: 16, y: -16)
                )
        }
    }

    private func handleTap() {
        // Always toggle auto-enter mode, even during recording
        withAnimation(.easeInOut(duration: 0.2)) {
            appConfig.autoEnter.toggle()
        }
    }
}

// MARK: - Mode Toggle Button

struct TranscriptionModeToggle: View {
    @ObservedObject var appConfig = AppConfig.shared
    @ObservedObject var dictationManager: DictationManager

    var body: some View {
        Button(action: toggleMode) {
            HStack(spacing: 4) {
                Image(systemName: appConfig.transcriptionMode.icon)
                    .font(.system(size: 14, weight: .medium))

                if dictationManager.isLocalModelLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.7)
                }
            }
            .foregroundColor(.white)
            .frame(width: 50, height: 36)
            .background(modeColor)
            .cornerRadius(8)
        }
        .disabled(dictationManager.isRecording || dictationManager.isTranscribing)
    }

    private var modeColor: Color {
        switch appConfig.transcriptionMode {
        case .api:
            return Color.blue.opacity(0.8)
        case .local:
            return dictationManager.isLocalModelReady ? Color.green.opacity(0.8) : Color.purple.opacity(0.8)
        }
    }

    private func toggleMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if appConfig.transcriptionMode == .api {
                appConfig.transcriptionMode = .local
                // Start loading local model if not ready
                if !dictationManager.isLocalModelReady {
                    Task {
                        await dictationManager.loadLocalModel()
                    }
                }
            } else {
                appConfig.transcriptionMode = .api
            }
        }
    }
}

// MARK: - Dictation Status View

struct DictationStatusView: View {
    @ObservedObject var dictationManager: DictationManager
    @ObservedObject var appConfig = AppConfig.shared

    var body: some View {
        HStack(spacing: 8) {
            // Mode indicator
            Text(appConfig.transcriptionMode.displayName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(appConfig.transcriptionMode == .api ? .blue : .green)

            // Status
            if dictationManager.isLocalModelLoading {
                HStack(spacing: 4) {
                    Text("Loading model...")
                        .font(.system(size: 10))
                        .foregroundColor(.purple)
                    Text("\(Int(dictationManager.modelDownloadProgress * 100))%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.purple)
                }
            } else if dictationManager.isRecording {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                    Text(formatTime(dictationManager.recordingTime))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                }
            } else if dictationManager.isTranscribing {
                Text("Transcribing...")
                    .font(.system(size: 12))
                    .foregroundColor(.orange)
            } else if let error = dictationManager.lastError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                    .lineLimit(1)
            } else if let text = dictationManager.lastTranscription {
                Text("Sent: \(text.prefix(25))...")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                    .lineLimit(1)
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        DictationButton(dictationManager: DictationManager(
            connectionManager: ConnectionManager(),
            apiKey: "test-key"
        ))
        DictationStatusView(dictationManager: DictationManager(
            connectionManager: ConnectionManager(),
            apiKey: "test-key"
        ))
    }
    .padding()
    .background(Color.black)
}
