// DictationManager.swift
// iPad Trackpad Controller - Dictation Orchestration
// iOS 18+ / iPadOS 18+

import Foundation
import AVFoundation

/// Orchestrates audio recording and Whisper transcription
@MainActor
class DictationManager: ObservableObject {

    @Published private(set) var isRecording = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var recordingTime: TimeInterval = 0
    @Published private(set) var lastError: String?
    @Published private(set) var lastTranscription: String?

    private let audioRecorder = AudioRecorder()
    private let whisperService: WhisperService
    private let connectionManager: ConnectionManager

    init(connectionManager: ConnectionManager, apiKey: String) {
        self.connectionManager = connectionManager
        self.whisperService = WhisperService(apiKey: apiKey)

        // Observe recorder state
        Task {
            for await isRec in audioRecorder.$isRecording.values {
                self.isRecording = isRec
            }
        }
        Task {
            for await time in audioRecorder.$recordingTime.values {
                self.recordingTime = time
            }
        }
    }

    /// Request microphone permission
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Start recording audio
    func startRecording() {
        lastError = nil
        lastTranscription = nil

        do {
            try audioRecorder.startRecording()
        } catch {
            lastError = error.localizedDescription
            print("[DictationManager] Failed to start recording: \(error)")
        }
    }

    /// Stop recording, transcribe, and send to Mac
    func stopRecordingAndSend() async {
        guard let audioData = audioRecorder.stopRecording() else {
            lastError = "No audio recorded"
            return
        }

        isTranscribing = true
        defer { isTranscribing = false }

        do {
            print("[DictationManager] Sending \(audioData.count) bytes to Whisper API...")
            let text = try await whisperService.transcribe(audioData: audioData)

            guard !text.isEmpty else {
                lastError = "No speech detected"
                return
            }

            lastTranscription = text
            print("[DictationManager] Transcribed: \(text)")

            // Send to Mac for typing
            connectionManager.sendTextToType(text)

        } catch {
            lastError = error.localizedDescription
            print("[DictationManager] Transcription failed: \(error)")
        }
    }

    /// Cancel recording without sending
    func cancelRecording() {
        audioRecorder.cancelRecording()
        lastError = nil
    }
}
