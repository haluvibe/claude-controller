// ProviderManager.swift
// iPad Trackpad Controller - Transcription Provider Management
// iOS 18+ / iPadOS 18+

import Foundation
import Security

// MARK: - Provider Types

enum ProviderType: String, Codable, CaseIterable {
    case openai
    case groq

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .groq: return "Groq"
        }
    }

    var endpoint: String {
        switch self {
        case .openai: return "https://api.openai.com/v1/audio/transcriptions"
        case .groq: return "https://api.groq.com/openai/v1/audio/transcriptions"
        }
    }

    var defaultModel: String {
        availableModels.first?.id ?? ""
    }

    var availableModels: [WhisperModel] {
        switch self {
        case .openai:
            return [
                WhisperModel(id: "whisper-1", name: "Whisper v2", description: "Standard model")
            ]
        case .groq:
            return [
                WhisperModel(id: "whisper-large-v3-turbo", name: "Large v3 Turbo", description: "Fastest, best for most use cases"),
                WhisperModel(id: "whisper-large-v3", name: "Large v3", description: "Highest accuracy"),
                WhisperModel(id: "distil-whisper-large-v3-en", name: "Distil v3 (English)", description: "Optimized for English")
            ]
        }
    }

    var icon: String {
        switch self {
        case .openai: return "brain"
        case .groq: return "bolt"
        }
    }
}

// MARK: - Whisper Model

struct WhisperModel: Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
}

// MARK: - Provider Model

struct TranscriptionProvider: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var providerType: ProviderType
    var modelId: String
    var isEnabled: Bool

    init(id: UUID = UUID(), name: String? = nil, providerType: ProviderType, modelId: String? = nil, isEnabled: Bool = true) {
        self.id = id
        self.name = name ?? providerType.displayName
        self.providerType = providerType
        self.modelId = modelId ?? providerType.defaultModel
        self.isEnabled = isEnabled
    }

    var endpoint: String { providerType.endpoint }
    var model: String { modelId }

    var modelName: String {
        providerType.availableModels.first { $0.id == modelId }?.name ?? modelId
    }
}

// MARK: - Provider Manager

@MainActor
class ProviderManager: ObservableObject {
    static let shared = ProviderManager()

    @Published private(set) var providers: [TranscriptionProvider] = []
    @Published var activeProviderId: UUID? {
        didSet {
            if let id = activeProviderId {
                UserDefaults.standard.set(id.uuidString, forKey: Keys.activeProviderId)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.activeProviderId)
            }
        }
    }

    private enum Keys {
        static let providers = "transcriptionProviders"
        static let activeProviderId = "activeProviderId"
        static let keychainService = "com.paulhayes.ClaudeController.apikeys"
    }

    var activeProvider: TranscriptionProvider? {
        guard let id = activeProviderId else { return nil }
        return providers.first { $0.id == id && $0.isEnabled }
    }

    var hasConfiguredProvider: Bool {
        activeProvider != nil && getAPIKey(for: activeProvider!.id) != nil
    }

    private init() {
        loadProviders()
    }

    // MARK: - Provider CRUD

    func addProvider(_ provider: TranscriptionProvider, apiKey: String) {
        providers.append(provider)
        saveAPIKey(apiKey, for: provider.id)
        saveProviders()

        // If this is the first provider, make it active
        if activeProviderId == nil {
            activeProviderId = provider.id
        }
    }

    func updateProvider(_ provider: TranscriptionProvider, apiKey: String? = nil) {
        guard let index = providers.firstIndex(where: { $0.id == provider.id }) else { return }
        providers[index] = provider

        if let key = apiKey {
            saveAPIKey(key, for: provider.id)
        }
        saveProviders()
    }

    func deleteProvider(_ provider: TranscriptionProvider) {
        providers.removeAll { $0.id == provider.id }
        deleteAPIKey(for: provider.id)
        saveProviders()

        // If deleted provider was active, select next available
        if activeProviderId == provider.id {
            activeProviderId = providers.first(where: { $0.isEnabled })?.id
        }
    }

    func setActiveProvider(_ id: UUID) {
        guard providers.contains(where: { $0.id == id && $0.isEnabled }) else { return }
        activeProviderId = id
    }

    func getAPIKey(for providerId: UUID) -> String? {
        return loadAPIKeyFromKeychain(for: providerId)
    }

    // MARK: - Persistence (UserDefaults for metadata)

    private func saveProviders() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(providers) {
            UserDefaults.standard.set(data, forKey: Keys.providers)
        }
    }

    private func loadProviders() {
        // Load providers from UserDefaults
        if let data = UserDefaults.standard.data(forKey: Keys.providers),
           let decoded = try? JSONDecoder().decode([TranscriptionProvider].self, from: data) {
            providers = decoded
        }

        // Load active provider ID
        if let idString = UserDefaults.standard.string(forKey: Keys.activeProviderId),
           let id = UUID(uuidString: idString) {
            activeProviderId = id
        } else {
            // Default to first enabled provider
            activeProviderId = providers.first(where: { $0.isEnabled })?.id
        }

        // Migration: If no providers exist but there's an old API key in Info.plist, create a provider
        if providers.isEmpty {
            migrateFromInfoPlist()
        }
    }

    private func migrateFromInfoPlist() {
        // Check for old-style API key in Info.plist
        if let key = Bundle.main.object(forInfoDictionaryKey: "OPENAI_WHISPER_KEY") as? String,
           !key.isEmpty,
           key != "$(OPENAI_WHISPER_KEY)" {
            let provider = TranscriptionProvider(providerType: .openai)
            addProvider(provider, apiKey: key)
            print("[ProviderManager] Migrated API key from Info.plist")
        }
    }

    // MARK: - Keychain Storage

    private func saveAPIKey(_ key: String, for providerId: UUID) {
        let account = providerId.uuidString
        let keyData = key.data(using: .utf8)!

        // Delete existing key first
        deleteAPIKey(for: providerId)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keys.keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("[ProviderManager] Failed to save API key to Keychain: \(status)")
        }
    }

    private func loadAPIKeyFromKeychain(for providerId: UUID) -> String? {
        let account = providerId.uuidString

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keys.keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    private func deleteAPIKey(for providerId: UUID) {
        let account = providerId.uuidString

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Keys.keychainService,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
