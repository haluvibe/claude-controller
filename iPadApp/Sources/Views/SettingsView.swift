// SettingsView.swift
// iPad Trackpad Controller - Settings Screen
// iOS 18+ / iPadOS 18+

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var providerManager: ProviderManager
    @State private var showAddProvider = false
    @State private var editingProvider: TranscriptionProvider?

    var body: some View {
        NavigationStack {
            List {
                // Providers Section
                Section {
                    if providerManager.providers.isEmpty {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("No transcription providers configured")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        ForEach(providerManager.providers) { provider in
                            ProviderRow(
                                provider: provider,
                                isActive: providerManager.activeProviderId == provider.id,
                                hasAPIKey: providerManager.getAPIKey(for: provider.id) != nil,
                                onSelect: {
                                    providerManager.setActiveProvider(provider.id)
                                },
                                onEdit: {
                                    editingProvider = provider
                                }
                            )
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                providerManager.deleteProvider(providerManager.providers[index])
                            }
                        }
                    }

                    Button(action: { showAddProvider = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add Provider")
                        }
                    }
                } header: {
                    Text("Transcription Providers")
                } footer: {
                    Text("Select the active provider for cloud transcription. API keys are stored securely in the iOS Keychain.")
                }

                // Info Section
                Section {
                    HStack {
                        Text("Cloud Mode")
                        Spacer()
                        if let provider = providerManager.activeProvider {
                            Text(provider.name)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not configured")
                                .foregroundColor(.orange)
                        }
                    }

                    HStack {
                        Text("Local Mode")
                        Spacer()
                        Text("whisper.cpp (On-Device)")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Transcription Modes")
                } footer: {
                    Text("Cloud mode uses the selected provider's API. Local mode runs transcription on-device using whisper.cpp.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddProvider) {
                ProviderFormView(providerManager: providerManager)
            }
            .sheet(item: $editingProvider) { provider in
                ProviderFormView(providerManager: providerManager, existingProvider: provider)
            }
        }
    }
}

// MARK: - Provider Row

struct ProviderRow: View {
    let provider: TranscriptionProvider
    let isActive: Bool
    let hasAPIKey: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            // Selection indicator
            Button(action: onSelect) {
                Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isActive ? .blue : .gray)
                    .font(.system(size: 22))
            }
            .buttonStyle(.plain)

            // Provider icon
            Image(systemName: provider.providerType.icon)
                .foregroundColor(.blue)
                .frame(width: 24)

            // Provider info
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.body)
                Text("\(provider.providerType.displayName) - \(provider.modelName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status indicators
            if !provider.isEnabled {
                Text("Disabled")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(4)
            } else if !hasAPIKey {
                Text("No Key")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.15))
                    .cornerRadius(4)
            }

            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil.circle")
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }
}

// MARK: - Preview

#Preview {
    SettingsView(providerManager: ProviderManager.shared)
}
