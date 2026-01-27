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

    /// OpenAI Whisper API key for dictation
    static var whisperAPIKey: String {
        // Try to load from bundle (for release builds)
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let config = NSDictionary(contentsOfFile: path),
           let key = config["OPENAI_WHISPER_KEY"] as? String,
           !key.isEmpty {
            return key
        }

        // Hardcoded key (from .env.local during development)
        // In production, use Config.plist or secure storage
        return "REDACTED_API_KEY"
    }

    private init() {
        // Load saved preference or default to API
        let savedMode = UserDefaults.standard.string(forKey: "transcriptionMode") ?? TranscriptionMode.api.rawValue
        self.transcriptionMode = TranscriptionMode(rawValue: savedMode) ?? .api
    }
}
