// LocalWhisperService.swift
// iPad Trackpad Controller - On-Device WhisperKit Transcription
// iOS 18+ / iPadOS 18+

import Foundation
import WhisperKit

/// Service for on-device transcription using WhisperKit
@MainActor
final class LocalWhisperService: ObservableObject {

    // MARK: - Published State

    @Published private(set) var modelState: ModelState = .notLoaded
    @Published private(set) var downloadProgress: Double = 0.0
    @Published private(set) var loadProgress: Double = 0.0

    // MARK: - Properties

    private var whisperKit: WhisperKit?
    private let modelName = "distil-whisper_distil-large-v3"

    // MARK: - Model State

    enum ModelState: Equatable {
        case notLoaded
        case downloading(progress: Double)
        case loading(progress: Double)
        case ready
        case error(String)

        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }

        var isLoading: Bool {
            switch self {
            case .downloading, .loading:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Initialization

    init() {
        // Model is loaded on-demand via loadModel()
    }

    /// Load the WhisperKit model asynchronously
    /// Call this during app launch or before first transcription
    func loadModel() async {
        guard !modelState.isReady && !modelState.isLoading else { return }

        modelState = .downloading(progress: 0)
        downloadProgress = 0
        loadProgress = 0

        do {
            print("[LocalWhisperService] Starting download for model: \(modelName)")

            // Step 1: Download model with progress tracking
            let modelFolder = try await WhisperKit.download(
                variant: modelName,
                progressCallback: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        let fraction = progress.fractionCompleted
                        self.downloadProgress = fraction
                        self.modelState = .downloading(progress: fraction)
                        print("[LocalWhisperService] Download progress: \(Int(fraction * 100))%")
                    }
                }
            )

            print("[LocalWhisperService] Download complete, loading model...")
            modelState = .loading(progress: 0)
            loadProgress = 0

            // Step 2: Initialize WhisperKit with downloaded model
            let config = WhisperKitConfig(
                model: modelName,
                modelFolder: modelFolder.path,
                computeOptions: modelComputeOptions(),
                verbose: true,
                logLevel: .info,
                prewarm: true,
                load: true,
                download: false  // Already downloaded
            )

            whisperKit = try await WhisperKit(config)

            loadProgress = 1.0
            modelState = .ready
            print("[LocalWhisperService] Model loaded successfully")

        } catch {
            let errorMessage = error.localizedDescription
            modelState = .error(errorMessage)
            print("[LocalWhisperService] Failed to load model: \(error)")
        }
    }

    /// Transcribe audio data using on-device WhisperKit
    /// - Parameter audioData: Audio data in m4a format at 16kHz
    /// - Returns: Transcribed text
    func transcribe(audioData: Data) async throws -> String {
        guard let whisperKit = whisperKit else {
            throw LocalWhisperError.modelNotLoaded
        }

        guard modelState.isReady else {
            throw LocalWhisperError.modelNotReady(state: modelState)
        }

        // Write audio data to temporary file for WhisperKit
        let tempURL = try writeToTemporaryFile(audioData: audioData)
        defer {
            try? FileManager.default.removeItem(at: tempURL)
        }

        print("[LocalWhisperService] Transcribing audio file: \(tempURL.lastPathComponent)")

        // Configure transcription options
        let options = DecodingOptions(
            verbose: false,
            task: .transcribe,
            language: "en",
            temperature: 0.0,
            temperatureFallbackCount: 3,
            sampleLength: 224,
            usePrefillPrompt: true,
            usePrefillCache: true,
            skipSpecialTokens: true,
            withoutTimestamps: true,
            clipTimestamps: [],
            suppressBlank: true,
            supressTokens: nil,
            compressionRatioThreshold: 2.4,
            logProbThreshold: -1.0,
            firstTokenLogProbThreshold: nil,
            noSpeechThreshold: 0.6,
            concurrentWorkerCount: 4,
            chunkingStrategy: nil
        )

        // Perform transcription
        let results = try await whisperKit.transcribe(
            audioPath: tempURL.path,
            decodeOptions: options
        )

        // Combine all segments into final text
        let transcription = results
            .compactMap { $0.text }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        print("[LocalWhisperService] Transcription complete: \(transcription.prefix(50))...")

        return transcription
    }

    /// Transcribe audio from a file URL
    /// - Parameter url: URL to the audio file
    /// - Returns: Transcribed text
    func transcribe(audioURL url: URL) async throws -> String {
        let data = try Data(contentsOf: url)
        return try await transcribe(audioData: data)
    }

    /// Unload the model to free memory
    func unloadModel() {
        whisperKit = nil
        modelState = .notLoaded
        downloadProgress = 0
        loadProgress = 0
        print("[LocalWhisperService] Model unloaded")
    }

    // MARK: - Private Methods

    private func modelComputeOptions() -> ModelComputeOptions {
        // Use GPU/ANE for optimal performance on Apple Silicon
        return ModelComputeOptions(
            audioEncoderCompute: .cpuAndGPU,
            textDecoderCompute: .cpuAndGPU
        )
    }

    private func writeToTemporaryFile(audioData: Data) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "whisper_\(UUID().uuidString).m4a"
        let fileURL = tempDir.appendingPathComponent(fileName)

        try audioData.write(to: fileURL)

        return fileURL
    }
}

// MARK: - Errors

enum LocalWhisperError: LocalizedError {
    case modelNotLoaded
    case modelNotReady(state: LocalWhisperService.ModelState)
    case transcriptionFailed(String)
    case invalidAudioData
    case fileWriteFailed

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "WhisperKit model has not been loaded. Call loadModel() first."
        case .modelNotReady(let state):
            return "Model is not ready for transcription. Current state: \(state)"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        case .invalidAudioData:
            return "Invalid or corrupt audio data"
        case .fileWriteFailed:
            return "Failed to write audio data to temporary file"
        }
    }
}

