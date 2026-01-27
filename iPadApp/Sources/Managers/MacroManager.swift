// MacroManager.swift
// iPad Trackpad Controller - Macro Options Management
// iOS 18+ / iPadOS 18+

import Foundation
import AVFoundation
import UIKit

// Note: MacroOption and MacroOptionsMessage are defined in ConnectionManager.swift

/// Manages macro options state and alerts
@MainActor
class MacroManager: ObservableObject {
    // MARK: - Published Properties

    @Published var options: [MacroOption] = []
    @Published var needsAttention: Bool = false
    @Published var isBarVisible: Bool = false

    // MARK: - Connection Manager (set after init)
    weak var connectionManager: ConnectionManager?

    // MARK: - Private Properties

    private var audioPlayer: AVAudioPlayer?
    private var feedbackGenerator: UINotificationFeedbackGenerator?
    private var attentionTimestamp: Date?

    // MARK: - Initialization

    init() {
        setupFeedback()
        setupChimeSound()
    }

    // MARK: - Setup

    private func setupFeedback() {
        feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator?.prepare()
    }

    private func setupChimeSound() {
        // Create a sparkle/chime sound using AudioServicesPlaySystemSound
        // or synthesize it. For now, we'll synthesize a pleasant chime.
        generateChimeSound()
    }

    /// Generate a sparkly chime sound programmatically
    private func generateChimeSound() {
        let sampleRate: Double = 44100
        let duration: Double = 0.6
        let frameCount = Int(sampleRate * duration)

        var audioData = [Float](repeating: 0, count: frameCount)

        // Create a sparkly chime with multiple harmonics
        // Frequencies for a pleasant sparkle (C major arpeggio with shimmer)
        let frequencies: [(freq: Double, amp: Float, decay: Double)] = [
            (1318.5, 0.25, 4.0),   // E6 - bright
            (1568.0, 0.20, 5.0),   // G6
            (2093.0, 0.15, 6.0),   // C7 - shimmer
            (2637.0, 0.10, 8.0),   // E7 - sparkle
            (3136.0, 0.08, 10.0),  // G7 - twinkle
        ]

        for i in 0..<frameCount {
            let t = Double(i) / sampleRate
            var sample: Float = 0

            for (freq, amp, decay) in frequencies {
                let envelope = Float(exp(-decay * t))
                let wave = sin(2.0 * .pi * freq * t)
                sample += amp * envelope * Float(wave)
            }

            // Add slight attack
            let attack = min(1.0, Float(i) / Float(sampleRate * 0.01))
            audioData[i] = sample * attack
        }

        // Create audio buffer
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)) else {
            return
        }

        buffer.frameLength = AVAudioFrameCount(frameCount)

        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<frameCount {
                channelData[i] = audioData[i]
            }
        }

        // Convert to Data and save temporarily
        do {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("chime.wav")

            // Write WAV file
            let audioFile = try AVAudioFile(forWriting: tempURL, settings: format.settings)
            try audioFile.write(from: buffer)

            // Create player
            audioPlayer = try AVAudioPlayer(contentsOf: tempURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 0.5
        } catch {
            print("[MacroManager] Failed to create chime sound: \(error)")
        }
    }

    // MARK: - Public API

    /// Update options from macOS message
    func updateOptions(_ newOptions: [MacroOption], needsAttention: Bool) {
        let hadOptions = !options.isEmpty
        let isNewAttention = needsAttention && !self.needsAttention

        options = newOptions
        self.needsAttention = needsAttention

        // Show bar when options arrive
        if !newOptions.isEmpty {
            isBarVisible = true
        }

        // Play alerts when attention is newly needed
        if isNewAttention && !hadOptions {
            playAttentionAlerts()
            attentionTimestamp = Date()
        }
    }

    /// Clear all options
    func clearOptions() {
        options = []
        needsAttention = false
        isBarVisible = false
        attentionTimestamp = nil
    }

    /// User selected an option - returns the option number
    func selectOption(_ option: MacroOption) -> Int {
        // Haptic feedback for selection
        feedbackGenerator?.notificationOccurred(.success)
        feedbackGenerator?.prepare()

        // Auto-hide bar after selection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.clearOptions()
        }

        return option.number
    }

    // MARK: - Alert Methods

    private func playAttentionAlerts() {
        // 1. Haptic feedback
        feedbackGenerator?.notificationOccurred(.warning)
        feedbackGenerator?.prepare()

        // 2. Chime sound
        playChime()
    }

    private func playChime() {
        // Configure audio session for playback alongside other audio
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[MacroManager] Audio session error: \(error)")
        }

        audioPlayer?.currentTime = 0
        audioPlayer?.play()
    }
}
