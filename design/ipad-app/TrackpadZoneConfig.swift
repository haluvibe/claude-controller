// TrackpadZoneConfig.swift
// iPad Trackpad App - Zone Configuration
// iOS 18+

import Foundation
import UIKit

/// Defines the different interaction zones on the trackpad surface
enum TrackpadZone: CaseIterable {
    case main           // Primary cursor movement area (90% of surface)
    case scrollEdgeRight // Dedicated scroll zone on right edge
    case scrollEdgeBottom // Dedicated scroll zone on bottom edge
    case clickZone      // Bottom area for physical click simulation

    var description: String {
        switch self {
        case .main: return "Cursor Movement"
        case .scrollEdgeRight: return "Vertical Scroll"
        case .scrollEdgeBottom: return "Horizontal Scroll"
        case .clickZone: return "Click Area"
        }
    }
}

/// Configuration for trackpad zones and behavior
struct TrackpadConfiguration {
    // MARK: - Zone Dimensions (as percentage of screen)

    /// Right edge scroll zone width (percentage of screen width)
    var scrollEdgeRightWidth: CGFloat = 0.05 // 5% of width

    /// Bottom edge scroll zone height (percentage of screen height)
    var scrollEdgeBottomHeight: CGFloat = 0.08 // 8% of height

    /// Click zone height at very bottom (percentage of screen height)
    var clickZoneHeight: CGFloat = 0.15 // 15% of height

    // MARK: - Sensitivity Settings

    /// Cursor movement sensitivity multiplier (0.5 - 3.0)
    var cursorSensitivity: CGFloat = 1.0

    /// Scroll speed multiplier (0.5 - 3.0)
    var scrollSensitivity: CGFloat = 1.0

    /// Enable natural scrolling (content follows finger direction)
    var naturalScrolling: Bool = true

    /// Acceleration curve for cursor movement
    var accelerationEnabled: Bool = true
    var accelerationCurve: AccelerationCurve = .medium

    // MARK: - Gesture Timing

    /// Maximum time between taps for double-tap (seconds)
    var doubleTapMaxInterval: TimeInterval = 0.3

    /// Minimum time finger must be down for drag (seconds)
    var dragThreshold: TimeInterval = 0.15

    /// Time before tap-and-hold triggers right-click (seconds)
    var longPressThreshold: TimeInterval = 0.5

    // MARK: - Visual Feedback

    /// Show touch indicators on trackpad
    var showTouchIndicators: Bool = true

    /// Haptic feedback intensity (0 = off, 1 = light, 2 = medium, 3 = heavy)
    var hapticIntensity: Int = 2

    /// Show gesture hints for new users
    var showGestureHints: Bool = true

    // MARK: - Zone Detection

    func zone(for point: CGPoint, in bounds: CGRect) -> TrackpadZone {
        let normalizedX = point.x / bounds.width
        let normalizedY = point.y / bounds.height

        // Check right edge scroll zone
        if normalizedX > (1.0 - scrollEdgeRightWidth) {
            return .scrollEdgeRight
        }

        // Check bottom edge scroll zone
        if normalizedY > (1.0 - scrollEdgeBottomHeight) {
            return .scrollEdgeBottom
        }

        // Check click zone (bottom portion when tap-to-click disabled)
        if normalizedY > (1.0 - clickZoneHeight) {
            return .clickZone
        }

        return .main
    }
}

/// Acceleration curves for cursor movement
enum AccelerationCurve: String, CaseIterable {
    case none = "None"
    case light = "Light"
    case medium = "Medium"
    case heavy = "Heavy"

    /// Apply acceleration to a velocity value
    func apply(to velocity: CGFloat) -> CGFloat {
        switch self {
        case .none:
            return velocity
        case .light:
            return velocity * (1.0 + abs(velocity) * 0.3)
        case .medium:
            return velocity * (1.0 + abs(velocity) * 0.6)
        case .heavy:
            return velocity * (1.0 + abs(velocity) * 1.0)
        }
    }
}

/// Preset configurations for different use cases
extension TrackpadConfiguration {
    static var `default`: TrackpadConfiguration {
        TrackpadConfiguration()
    }

    static var precision: TrackpadConfiguration {
        var config = TrackpadConfiguration()
        config.cursorSensitivity = 0.7
        config.accelerationEnabled = false
        config.scrollSensitivity = 0.8
        return config
    }

    static var fast: TrackpadConfiguration {
        var config = TrackpadConfiguration()
        config.cursorSensitivity = 1.5
        config.accelerationCurve = .heavy
        config.scrollSensitivity = 1.5
        return config
    }

    static var accessibility: TrackpadConfiguration {
        var config = TrackpadConfiguration()
        config.cursorSensitivity = 0.6
        config.doubleTapMaxInterval = 0.5
        config.longPressThreshold = 0.8
        config.hapticIntensity = 3
        config.showGestureHints = true
        return config
    }
}
