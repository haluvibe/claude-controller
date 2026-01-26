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
        .disabled(dictationManager.isTranscribing)
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

// MARK: - Dictation Status View (optional - shows transcription result)

struct DictationStatusView: View {
    @ObservedObject var dictationManager: DictationManager

    var body: some View {
        VStack(spacing: 4) {
            if dictationManager.isRecording {
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
                Text("Sent: \(text.prefix(30))...")
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
