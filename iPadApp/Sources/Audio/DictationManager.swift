// DictationManager.swift
// iPad Trackpad Controller - Dictation Orchestration
// iOS 18+ / iPadOS 18+

import Foundation
import AVFoundation
import Combine

/// Orchestrates audio recording and transcription (API or Local)
@MainActor
class DictationManager: ObservableObject {

    @Published private(set) var isRecording = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var recordingTime: TimeInterval = 0
    @Published private(set) var lastError: String?
    @Published private(set) var lastTranscription: String?

    // Local model state
    @Published private(set) var localModelState: LocalWhisperService.ModelState = .notLoaded
    @Published private(set) var modelDownloadProgress: Double = 0
    @Published private(set) var modelLoadProgress: Double = 0

    private let audioRecorder = AudioRecorder()
    private let whisperService: WhisperService
    private let localWhisperService = LocalWhisperService()
    private let connectionManager: ConnectionManager
    private let appConfig = AppConfig.shared

    private var cancellables = Set<AnyCancellable>()

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

        // Observe local model state
        localWhisperService.$modelState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.localModelState = state
            }
            .store(in: &cancellables)

        localWhisperService.$downloadProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.modelDownloadProgress = progress
            }
            .store(in: &cancellables)

        localWhisperService.$loadProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.modelLoadProgress = progress
            }
            .store(in: &cancellables)
    }

    /// Current transcription mode
    var transcriptionMode: TranscriptionMode {
        appConfig.transcriptionMode
    }

    /// Whether local model is ready
    var isLocalModelReady: Bool {
        localModelState.isReady
    }

    /// Whether local model is currently loading
    var isLocalModelLoading: Bool {
        localModelState.isLoading
    }

    /// Request microphone permission
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Load the local whisper model (call this when switching to local mode)
    func loadLocalModel() async {
        await localWhisperService.loadModel()
    }

    /// Unload the local model to free memory
    func unloadLocalModel() {
        localWhisperService.unloadModel()
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
            let text: String

            switch appConfig.transcriptionMode {
            case .api:
                print("[DictationManager] Using API transcription...")
                text = try await whisperService.transcribe(audioData: audioData)

            case .local:
                print("[DictationManager] Using local transcription...")
                // Ensure model is loaded
                if !localModelState.isReady {
                    print("[DictationManager] Local model not ready, loading...")
                    await loadLocalModel()

                    // Check if model loaded successfully
                    if case .error(let errorMsg) = localModelState {
                        throw NSError(domain: "LocalWhisper", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Model failed to load: \(errorMsg)"])
                    }

                    // Still not ready after loading attempt
                    if !localModelState.isReady {
                        throw NSError(domain: "LocalWhisper", code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "Model is still loading. Please wait and try again."])
                    }
                }
                text = try await localWhisperService.transcribe(audioData: audioData)
            }

            guard !text.isEmpty else {
                lastError = "No speech detected"
                return
            }

            lastTranscription = text
            print("[DictationManager] Transcribed (\(appConfig.transcriptionMode.rawValue)): \(text)")

            // Send to Mac for typing
            connectionManager.sendTextToType(text)

            // Auto-enter: send Return key if enabled
            if appConfig.autoEnter {
                // Longer delay to ensure text is fully typed first
                // Text typing can be slow depending on text length
                let delayMs = max(300, text.count * 10) // At least 300ms, plus 10ms per character
                try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
                connectionManager.sendKeyPress(keyCode: 36) // Return key
                print("[DictationManager] Auto-enter: sent Return key after \(delayMs)ms delay")
            }

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

    /// Send Return key to Mac
    func sendReturn() {
        connectionManager.sendKeyPress(keyCode: 36) // Return key
    }
}
