// WhisperService.swift
// iPad Trackpad Controller - OpenAI Whisper API Integration
// iOS 18+ / iPadOS 18+

import Foundation

/// Service for transcribing audio using OpenAI Whisper API
class WhisperService {

    private let apiKey: String
    private let endpoint = "https://api.openai.com/v1/audio/transcriptions"

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    /// Transcribe audio data using OpenAI Whisper
    /// - Parameter audioData: Audio data in supported format (m4a, mp3, wav, etc.)
    /// - Returns: Transcribed text
    func transcribe(audioData: Data, format: String = "m4a") async throws -> String {
        let boundary = UUID().uuidString

        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add model field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)

        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.\(format)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/\(format)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add language hint (optional, improves accuracy)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("en\r\n".data(using: .utf8)!)

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WhisperError.apiError(statusCode: httpResponse.statusCode, message: errorText)
        }

        let result = try JSONDecoder().decode(WhisperResponse.self, from: data)
        return result.text
    }
}

// MARK: - Response Models

struct WhisperResponse: Codable {
    let text: String
}

// MARK: - Errors

enum WhisperError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Whisper API"
        case .apiError(let statusCode, let message):
            return "Whisper API error (\(statusCode)): \(message)"
        }
    }
}
