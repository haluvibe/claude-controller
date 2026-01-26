// SettingsView.swift
// iPad Trackpad App - Settings and Preferences
// iOS 18+

import SwiftUI

struct SettingsView: View {
    @Binding var configuration: TrackpadConfiguration
    @Environment(\.dismiss) private var dismiss
    @State private var showConnectionManager = false
    @State private var showGestureGuide = false

    var body: some View {
        NavigationStack {
            List {
                // Connection Section
                Section {
                    NavigationLink(destination: ConnectionManagerView()) {
                        SettingsRow(
                            icon: "wifi",
                            iconColor: .blue,
                            title: "Connections",
                            subtitle: "Manage Mac connections"
                        )
                    }

                    NavigationLink(destination: PairingView()) {
                        SettingsRow(
                            icon: "plus.circle",
                            iconColor: .green,
                            title: "Pair New Mac",
                            subtitle: "Add a new Mac to control"
                        )
                    }
                } header: {
                    Text("Connection")
                }

                // Trackpad Section
                Section {
                    // Cursor sensitivity
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Cursor Speed")
                            Spacer()
                            Text(String(format: "%.1fx", configuration.cursorSensitivity))
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $configuration.cursorSensitivity,
                            in: 0.5...3.0,
                            step: 0.1
                        )
                    }

                    // Scroll sensitivity
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Scroll Speed")
                            Spacer()
                            Text(String(format: "%.1fx", configuration.scrollSensitivity))
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $configuration.scrollSensitivity,
                            in: 0.5...3.0,
                            step: 0.1
                        )
                    }

                    // Natural scrolling toggle
                    Toggle("Natural Scrolling", isOn: $configuration.naturalScrolling)

                    // Acceleration
                    Toggle("Pointer Acceleration", isOn: $configuration.accelerationEnabled)

                    if configuration.accelerationEnabled {
                        Picker("Acceleration Curve", selection: $configuration.accelerationCurve) {
                            ForEach(AccelerationCurve.allCases, id: \.self) { curve in
                                Text(curve.rawValue).tag(curve)
                            }
                        }
                    }
                } header: {
                    Text("Trackpad")
                }

                // Gestures Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Double-Tap Speed")
                            Spacer()
                            Text(String(format: "%.2fs", configuration.doubleTapMaxInterval))
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $configuration.doubleTapMaxInterval,
                            in: 0.2...0.6,
                            step: 0.05
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Long Press Duration")
                            Spacer()
                            Text(String(format: "%.2fs", configuration.longPressThreshold))
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: $configuration.longPressThreshold,
                            in: 0.3...1.0,
                            step: 0.1
                        )
                    }

                    NavigationLink(destination: GestureGuideView()) {
                        SettingsRow(
                            icon: "hand.draw",
                            iconColor: .purple,
                            title: "Gesture Guide",
                            subtitle: "Learn trackpad gestures"
                        )
                    }
                } header: {
                    Text("Gestures")
                }

                // Feedback Section
                Section {
                    Toggle("Touch Indicators", isOn: $configuration.showTouchIndicators)

                    Picker("Haptic Feedback", selection: $configuration.hapticIntensity) {
                        Text("Off").tag(0)
                        Text("Light").tag(1)
                        Text("Medium").tag(2)
                        Text("Strong").tag(3)
                    }

                    Toggle("Show Gesture Hints", isOn: $configuration.showGestureHints)
                } header: {
                    Text("Feedback")
                }

                // Presets Section
                Section {
                    Button("Default") {
                        configuration = .default
                    }
                    Button("Precision") {
                        configuration = .precision
                    }
                    Button("Fast") {
                        configuration = .fast
                    }
                    Button("Accessibility") {
                        configuration = .accessibility
                    }
                } header: {
                    Text("Presets")
                } footer: {
                    Text("Quickly apply optimized settings for different use cases.")
                }

                // Advanced Section
                Section {
                    NavigationLink(destination: AdvancedSettingsView(configuration: $configuration)) {
                        SettingsRow(
                            icon: "slider.horizontal.3",
                            iconColor: .orange,
                            title: "Advanced",
                            subtitle: "Zone sizes, timing, network"
                        )
                    }

                    NavigationLink(destination: KeyboardSettingsView()) {
                        SettingsRow(
                            icon: "keyboard",
                            iconColor: .indigo,
                            title: "Keyboard",
                            subtitle: "Layout and shortcuts"
                        )
                    }
                } header: {
                    Text("Advanced")
                }

                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    NavigationLink(destination: AboutView()) {
                        Text("About")
                    }

                    NavigationLink(destination: HelpView()) {
                        Text("Help & Support")
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Settings Row Component

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(iconColor)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Connection Manager View

struct ConnectionManagerView: View {
    @State private var savedConnections: [SavedConnection] = []
    @State private var isScanning = false

    var body: some View {
        List {
            Section {
                if savedConnections.isEmpty {
                    Text("No saved connections")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(savedConnections) { connection in
                        ConnectionRow(connection: connection)
                    }
                    .onDelete(perform: deleteConnection)
                }
            } header: {
                Text("Saved Macs")
            }

            Section {
                Button(action: { isScanning.toggle() }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Scan for Macs")
                        if isScanning {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
            }
        }
        .navigationTitle("Connections")
    }

    private func deleteConnection(at offsets: IndexSet) {
        savedConnections.remove(atOffsets: offsets)
    }
}

struct SavedConnection: Identifiable {
    let id = UUID()
    let name: String
    let hostname: String
    let lastConnected: Date?
    let isOnline: Bool
}

struct ConnectionRow: View {
    let connection: SavedConnection

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(connection.name)
                    .font(.headline)
                Text(connection.hostname)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Circle()
                .fill(connection.isOnline ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
        }
    }
}

// MARK: - Pairing View

struct PairingView: View {
    @State private var discoveredMacs: [DiscoveredMac] = []
    @State private var isScanning = true
    @State private var selectedMac: DiscoveredMac?
    @State private var showPairingCode = false

    var body: some View {
        List {
            Section {
                if isScanning {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 8)
                        Text("Searching for Macs...")
                            .foregroundColor(.secondary)
                    }
                }

                ForEach(discoveredMacs) { mac in
                    Button(action: { selectMac(mac) }) {
                        HStack {
                            Image(systemName: "desktopcomputer")
                                .font(.title2)
                                .foregroundColor(.blue)

                            VStack(alignment: .leading) {
                                Text(mac.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(mac.hostname)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if selectedMac?.id == mac.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            } header: {
                Text("Available Macs")
            } footer: {
                Text("Make sure the Claude Controller helper app is running on your Mac.")
            }

            if selectedMac != nil {
                Section {
                    Button("Pair with \(selectedMac?.name ?? "Mac")") {
                        showPairingCode = true
                    }
                    .font(.headline)
                }
            }
        }
        .navigationTitle("Pair New Mac")
        .sheet(isPresented: $showPairingCode) {
            PairingCodeView(mac: selectedMac!)
        }
        .onAppear {
            startScanning()
        }
    }

    private func startScanning() {
        // Simulated discovery
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            discoveredMacs = [
                DiscoveredMac(name: "Paul's MacBook Pro", hostname: "Pauls-MacBook-Pro.local"),
                DiscoveredMac(name: "Office iMac", hostname: "Office-iMac.local")
            ]
            isScanning = false
        }
    }

    private func selectMac(_ mac: DiscoveredMac) {
        selectedMac = mac
    }
}

struct DiscoveredMac: Identifiable {
    let id = UUID()
    let name: String
    let hostname: String
}

struct PairingCodeView: View {
    let mac: DiscoveredMac
    @Environment(\.dismiss) private var dismiss
    @State private var pairingCode = "384729"
    @State private var isPaired = false

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 60))
                .foregroundColor(.blue)

            Text("Pairing with \(mac.name)")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Enter this code on your Mac:")
                .foregroundColor(.secondary)

            // Pairing code display
            HStack(spacing: 12) {
                ForEach(Array(pairingCode), id: \.self) { digit in
                    Text(String(digit))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .frame(width: 50, height: 60)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            .padding(.vertical)

            if isPaired {
                Label("Paired Successfully!", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.headline)
            } else {
                ProgressView("Waiting for confirmation...")
            }

            Spacer()

            Button("Cancel") {
                dismiss()
            }
            .foregroundColor(.red)
        }
        .padding()
        .onAppear {
            // Simulate pairing completion
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                isPaired = true
            }
        }
    }
}

// MARK: - Gesture Guide View

struct GestureGuideView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(GestureHintOverlay.GestureHint.allCases, id: \.self) { gesture in
                    GestureGuideCard(gesture: gesture)
                }
            }
            .padding()
        }
        .navigationTitle("Gesture Guide")
    }
}

struct GestureGuideCard: View {
    let gesture: GestureHintOverlay.GestureHint

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: gesture.iconName)
                    .font(.title)
                    .foregroundColor(.blue)
                Text(gesture.title)
                    .font(.headline)
            }

            Text(gesture.description)
                .font(.body)
                .foregroundColor(.secondary)

            // Animation placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .frame(height: 120)
                .overlay(
                    Text("Animation")
                        .foregroundColor(.secondary)
                )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }
}

// MARK: - Advanced Settings View

struct AdvancedSettingsView: View {
    @Binding var configuration: TrackpadConfiguration

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Right Edge Scroll Zone")
                        Spacer()
                        Text(String(format: "%.0f%%", configuration.scrollEdgeRightWidth * 100))
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $configuration.scrollEdgeRightWidth,
                        in: 0.03...0.15,
                        step: 0.01
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Bottom Edge Scroll Zone")
                        Spacer()
                        Text(String(format: "%.0f%%", configuration.scrollEdgeBottomHeight * 100))
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $configuration.scrollEdgeBottomHeight,
                        in: 0.05...0.15,
                        step: 0.01
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Click Zone Height")
                        Spacer()
                        Text(String(format: "%.0f%%", configuration.clickZoneHeight * 100))
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $configuration.clickZoneHeight,
                        in: 0.10...0.25,
                        step: 0.01
                    )
                }
            } header: {
                Text("Zone Sizes")
            } footer: {
                Text("Adjust the size of special interaction zones on the trackpad surface.")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Drag Threshold")
                        Spacer()
                        Text(String(format: "%.2fs", configuration.dragThreshold))
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $configuration.dragThreshold,
                        in: 0.05...0.3,
                        step: 0.01
                    )
                }
            } header: {
                Text("Timing")
            }
        }
        .navigationTitle("Advanced")
    }
}

// MARK: - Keyboard Settings View

struct KeyboardSettingsView: View {
    @State private var showFunctionRow = true
    @State private var keyClickSound = true
    @State private var keyHaptics = true
    @State private var autoCapitalization = true

    var body: some View {
        List {
            Section {
                Toggle("Function Row", isOn: $showFunctionRow)
                Toggle("Key Click Sound", isOn: $keyClickSound)
                Toggle("Key Haptics", isOn: $keyHaptics)
            } header: {
                Text("Keyboard")
            }

            Section {
                Toggle("Auto-Capitalization", isOn: $autoCapitalization)
            } header: {
                Text("Typing")
            }

            Section {
                NavigationLink("Custom Shortcuts") {
                    Text("Custom Shortcuts Editor")
                }
            } header: {
                Text("Shortcuts")
            }
        }
        .navigationTitle("Keyboard")
    }
}

// MARK: - Placeholder Views

struct AboutView: View {
    var body: some View {
        Text("About Claude Controller")
            .navigationTitle("About")
    }
}

struct HelpView: View {
    var body: some View {
        Text("Help & Support")
            .navigationTitle("Help")
    }
}

// MARK: - Preview

#Preview {
    SettingsView(configuration: .constant(.default))
}
