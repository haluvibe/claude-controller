// AudioRecorder.swift
// iPad Trackpad Controller - Audio Recording for Dictation
// iOS 18+ / iPadOS 18+

import Foundation
import AVFoundation

/// Records audio from the device microphone
@MainActor
class AudioRecorder: NSObject, ObservableObject {

    @Published private(set) var isRecording = false
    @Published private(set) var recordingTime: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var timer: Timer?

    override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("[AudioRecorder] Failed to setup audio session: \(error)")
        }
    }

    /// Start recording audio
    func startRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setActive(true)

        // Create temporary file URL
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "dictation_\(Date().timeIntervalSince1970).m4a"
        recordingURL = tempDir.appendingPathComponent(fileName)

        guard let url = recordingURL else {
            throw RecorderError.noURL
        }

        // Configure recorder settings for Whisper compatibility
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,  // Whisper optimal sample rate
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.record()

        isRecording = true
        recordingTime = 0

        // Start timer for recording duration
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingTime += 0.1
            }
        }

        print("[AudioRecorder] Started recording to \(url)")
    }

    /// Stop recording and return audio data
    func stopRecording() -> Data? {
        timer?.invalidate()
        timer = nil

        audioRecorder?.stop()
        isRecording = false

        guard let url = recordingURL else { return nil }

        defer {
            // Clean up file after reading
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }

        do {
            let data = try Data(contentsOf: url)
            print("[AudioRecorder] Stopped recording, got \(data.count) bytes")
            return data
        } catch {
            print("[AudioRecorder] Failed to read recording: \(error)")
            return nil
        }
    }

    /// Cancel recording without returning data
    func cancelRecording() {
        timer?.invalidate()
        timer = nil

        audioRecorder?.stop()
        audioRecorder?.deleteRecording()
        isRecording = false
        recordingTime = 0
        recordingURL = nil

        print("[AudioRecorder] Recording cancelled")
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("[AudioRecorder] Recording finished unsuccessfully")
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("[AudioRecorder] Encode error: \(error)")
        }
    }
}

// MARK: - Errors

enum RecorderError: LocalizedError {
    case noURL
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .noURL:
            return "Failed to create recording URL"
        case .permissionDenied:
            return "Microphone permission denied"
        }
    }
}
