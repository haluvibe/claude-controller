// AppConfig.swift
// iPad Trackpad Controller - Configuration
// iOS 18+ / iPadOS 18+

import Foundation

/// App configuration including API keys
struct AppConfig {
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
}
