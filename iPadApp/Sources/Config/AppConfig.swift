// AppConfig.swift
// iPad Trackpad Controller - Configuration
// iOS 18+ / iPadOS 18+

import Foundation
import SwiftUI

/// Transcription mode - API vs Local
enum TranscriptionMode: String, CaseIterable {
    case api = "API"
    case local = "Local"

    var displayName: String {
        switch self {
        case .api: return "Cloud (API)"
        case .local: return "On-Device"
        }
    }

    var icon: String {
        switch self {
        case .api: return "cloud"
        case .local: return "cpu"
        }
    }
}

/// App configuration including API keys and settings
class AppConfig: ObservableObject {
    static let shared = AppConfig()

    /// Current transcription mode
    @Published var transcriptionMode: TranscriptionMode {
        didSet {
            UserDefaults.standard.set(transcriptionMode.rawValue, forKey: "transcriptionMode")
        }
    }

    /// Auto-enter mode - automatically send Return after dictation
    @Published var autoEnter: Bool {
        didSet {
            UserDefaults.standard.set(autoEnter, forKey: "autoEnter")
        }
    }

    /// OpenAI Whisper API key for dictation
    /// IMPORTANT: Never hardcode API keys. Use Config.xcconfig (gitignored) instead.
    static var whisperAPIKey: String {
        // Load from Info.plist (injected from Config.xcconfig at build time)
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_WHISPER_KEY") as? String,
           !key.isEmpty,
           key != "$(OPENAI_WHISPER_KEY)" {  // Check it was actually substituted
            return key
        }

        // No key found - API mode won't work, but local mode will
        // To use API mode, create Config.xcconfig from Config.xcconfig.example
        print("[AppConfig] Warning: No API key found. Copy Config.xcconfig.example to Config.xcconfig and add your key.")
        return ""
    }

    private init() {
        // Load saved preference or default to API
        let savedMode = UserDefaults.standard.string(forKey: "transcriptionMode") ?? TranscriptionMode.api.rawValue
        self.transcriptionMode = TranscriptionMode(rawValue: savedMode) ?? .api

        // Load auto-enter preference (default to true for convenience)
        self.autoEnter = UserDefaults.standard.object(forKey: "autoEnter") as? Bool ?? true
    }
}
