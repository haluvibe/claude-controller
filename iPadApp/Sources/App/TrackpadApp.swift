// TrackpadApp.swift
// iPad Trackpad Controller - App Entry Point
// iOS 18+ / iPadOS 18+

import SwiftUI

@main
struct TrackpadApp: App {
    @StateObject private var connectionManager = ConnectionManager()

    var body: some Scene {
        WindowGroup {
            TrackpadView()
                .environmentObject(connectionManager)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}
