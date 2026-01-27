// ProviderFormView.swift
// iPad Trackpad Controller - Add/Edit Provider Form
// iOS 18+ / iPadOS 18+

import SwiftUI

struct ProviderFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var providerManager: ProviderManager

    let existingProvider: TranscriptionProvider?

    @State private var providerType: ProviderType = .openai
    @State private var name: String = ""
    @State private var modelId: String = ""
    @State private var apiKey: String = ""
    @State private var isEnabled: Bool = true
    @State private var isTesting: Bool = false
    @State private var testResult: TestResult?

    private var isEditing: Bool { existingProvider != nil }

    init(providerManager: ProviderManager, existingProvider: TranscriptionProvider? = nil) {
        self.providerManager = providerManager
        self.existingProvider = existingProvider

        if let provider = existingProvider {
            _providerType = State(initialValue: provider.providerType)
            _name = State(initialValue: provider.name)
            _modelId = State(initialValue: provider.modelId)
            _isEnabled = State(initialValue: provider.isEnabled)
            // API key is loaded separately for security
        } else {
            _modelId = State(initialValue: ProviderType.openai.defaultModel)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Provider Type
                Section {
                    Picker("Provider", selection: $providerType) {
                        ForEach(ProviderType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .disabled(isEditing)

                    TextField("Name (optional)", text: $name)
                        .textContentType(.name)
                } header: {
                    Text("Provider")
                } footer: {
                    Text("Select the transcription service provider.")
                }

                // Model Selection
                Section {
                    Picker("Model", selection: $modelId) {
                        ForEach(providerType.availableModels) { model in
                            VStack(alignment: .leading) {
                                Text(model.name)
                            }
                            .tag(model.id)
                        }
                    }
                } header: {
                    Text("Model")
                } footer: {
                    if let model = providerType.availableModels.first(where: { $0.id == modelId }) {
                        Text(model.description)
                    }
                }

                // API Key
                Section {
                    SecureField("API Key", text: $apiKey)
                        .textContentType(.password)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    if isEditing && apiKey.isEmpty {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("Leave empty to keep existing key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Authentication")
                } footer: {
                    Text(apiKeyHelpText)
                }

                // Test Connection
                Section {
                    Button(action: testConnection) {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "network")
                            }
                            Text(isTesting ? "Testing..." : "Test Connection")
                        }
                    }
                    .disabled(apiKey.isEmpty && existingProvider == nil || isTesting)

                    if let result = testResult {
                        HStack {
                            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result.success ? .green : .red)
                            Text(result.message)
                                .font(.caption)
                                .foregroundColor(result.success ? .green : .red)
                        }
                    }
                } header: {
                    Text("Verify")
                }

                // Settings
                Section {
                    Toggle("Enabled", isOn: $isEnabled)
                } header: {
                    Text("Settings")
                }

                // Endpoint Info
                Section {
                    LabeledContent("Endpoint") {
                        Text(providerType.endpoint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                } header: {
                    Text("Details")
                }
            }
            .navigationTitle(isEditing ? "Edit Provider" : "Add Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: providerType) { _, newValue in
                if name.isEmpty || name == ProviderType.openai.displayName || name == ProviderType.groq.displayName {
                    name = newValue.displayName
                }
                // Reset model to default when provider changes
                modelId = newValue.defaultModel
            }
        }
    }

    private var apiKeyHelpText: String {
        switch providerType {
        case .openai:
            return "Get your API key from platform.openai.com"
        case .groq:
            return "Get your API key from console.groq.com"
        }
    }

    private var canSave: Bool {
        if isEditing {
            return true // Can save without changing API key
        }
        return !apiKey.isEmpty
    }

    private func save() {
        let providerName = name.isEmpty ? providerType.displayName : name

        if let existing = existingProvider {
            // Update existing provider
            var updated = existing
            updated.name = providerName
            updated.modelId = modelId
            updated.isEnabled = isEnabled

            if apiKey.isEmpty {
                providerManager.updateProvider(updated)
            } else {
                providerManager.updateProvider(updated, apiKey: apiKey)
            }
        } else {
            // Create new provider
            let provider = TranscriptionProvider(
                name: providerName,
                providerType: providerType,
                modelId: modelId,
                isEnabled: isEnabled
            )
            providerManager.addProvider(provider, apiKey: apiKey)
        }

        dismiss()
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        let keyToTest: String
        if !apiKey.isEmpty {
            keyToTest = apiKey
        } else if let existing = existingProvider,
                  let existingKey = providerManager.getAPIKey(for: existing.id) {
            keyToTest = existingKey
        } else {
            testResult = TestResult(success: false, message: "No API key provided")
            isTesting = false
            return
        }

        Task {
            let result = await performConnectionTest(apiKey: keyToTest, providerType: providerType, modelId: modelId)
            await MainActor.run {
                testResult = result
                isTesting = false
            }
        }
    }

    private func performConnectionTest(apiKey: String, providerType: ProviderType, modelId: String) async -> TestResult {
        // Create minimal audio data for testing (silent WAV)
        let silentWAV = createSilentWAV()

        do {
            let boundary = UUID().uuidString
            var request = URLRequest(url: URL(string: providerType.endpoint)!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 10

            var body = Data()

            // Add model field
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(modelId)\r\n".data(using: .utf8)!)

            // Add audio file
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"test.wav\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
            body.append(silentWAV)
            body.append("\r\n".data(using: .utf8)!)

            // Close boundary
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)

            request.httpBody = body

            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return TestResult(success: false, message: "Invalid response")
            }

            switch httpResponse.statusCode {
            case 200:
                return TestResult(success: true, message: "Connection successful!")
            case 401:
                return TestResult(success: false, message: "Invalid API key")
            case 403:
                return TestResult(success: false, message: "Access denied")
            case 429:
                return TestResult(success: false, message: "Rate limited (but key is valid)")
            default:
                return TestResult(success: false, message: "Error: HTTP \(httpResponse.statusCode)")
            }
        } catch {
            return TestResult(success: false, message: error.localizedDescription)
        }
    }

    private func createSilentWAV() -> Data {
        // Create a minimal valid WAV file (44 bytes header + 1 second of silence at 8kHz mono)
        var data = Data()

        let sampleRate: UInt32 = 8000
        let numChannels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let numSamples: UInt32 = sampleRate  // 1 second
        let dataSize = numSamples * UInt32(numChannels) * UInt32(bitsPerSample / 8)

        // RIFF header
        data.append("RIFF".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: (36 + dataSize).littleEndian) { Data($0) })
        data.append("WAVE".data(using: .ascii)!)

        // fmt chunk
        data.append("fmt ".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // PCM
        data.append(withUnsafeBytes(of: numChannels.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: sampleRate.littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: (sampleRate * UInt32(numChannels) * UInt32(bitsPerSample / 8)).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: (numChannels * bitsPerSample / 8).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })

        // data chunk
        data.append("data".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: dataSize.littleEndian) { Data($0) })
        data.append(Data(count: Int(dataSize))) // Silent samples

        return data
    }
}

// MARK: - Test Result

struct TestResult {
    let success: Bool
    let message: String
}

// MARK: - Preview

#Preview {
    ProviderFormView(providerManager: ProviderManager.shared)
}
