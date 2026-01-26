// GestureHandler.swift
// iPad Trackpad Controller - Touch Processing
// iOS 18+ / iPadOS 18+

import UIKit

/// Custom UIView that captures all touch events for trackpad emulation
class GestureHandlerView: UIView {

    // MARK: - Callbacks

    var onMove: ((CGFloat, CGFloat) -> Void)?
    var onClick: (() -> Void)?
    var onRightClick: (() -> Void)?
    var onScroll: ((CGFloat, CGFloat) -> Void)?

    // MARK: - Touch Tracking

    private var previousTouchPosition: CGPoint?
    private var touchStartTime: Date?
    private var touchStartPosition: CGPoint?
    private var activeTouches: [UITouch] = []
    private var previousTwoFingerCenter: CGPoint?

    // MARK: - Configuration

    private let tapMaxDuration: TimeInterval = 0.2  // 200ms
    private let tapMaxMovement: CGFloat = 10.0      // 10 points
    private let twoFingerTapMaxDuration: TimeInterval = 0.25
    private let scrollSensitivity: CGFloat = 2.0

    // Acceleration curve parameters (mimics macOS trackpad)
    private let baseSensitivity: CGFloat = 1.0
    private let accelerationThreshold: CGFloat = 3.0   // Velocity above this gets boosted
    private let maxAcceleration: CGFloat = 4.0         // Maximum multiplier for fast swipes
    private let accelerationCurve: CGFloat = 1.5       // How quickly acceleration ramps up

    // Velocity tracking
    private var lastMoveTime: Date?
    private var velocityHistory: [CGFloat] = []
    private let velocityHistorySize = 3

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.append(contentsOf: touches)

        if activeTouches.count == 1 {
            // Single finger touch start
            if let touch = touches.first {
                let position = touch.location(in: self)
                touchStartTime = Date()
                touchStartPosition = position
                previousTouchPosition = position
            }
        } else if activeTouches.count == 2 {
            // Two finger touch start
            touchStartTime = Date()
            previousTwoFingerCenter = calculateCenter(of: activeTouches)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if activeTouches.count == 1 {
            // Single finger move - cursor movement with acceleration
            guard let touch = activeTouches.first,
                  let previousPosition = previousTouchPosition else { return }

            let currentPosition = touch.location(in: self)
            let rawDeltaX = currentPosition.x - previousPosition.x
            let rawDeltaY = currentPosition.y - previousPosition.y

            // Always update position first to prevent drift
            previousTouchPosition = currentPosition

            // Calculate velocity for acceleration
            let now = Date()
            let rawDistance = hypot(rawDeltaX, rawDeltaY)
            var velocity: CGFloat = rawDistance

            if let lastTime = lastMoveTime {
                let timeDelta = now.timeIntervalSince(lastTime)
                if timeDelta > 0 {
                    velocity = rawDistance / CGFloat(timeDelta * 60) // Normalize to ~60fps
                }
            }
            lastMoveTime = now

            // Smooth velocity with history
            velocityHistory.append(velocity)
            if velocityHistory.count > velocityHistorySize {
                velocityHistory.removeFirst()
            }
            let smoothedVelocity = velocityHistory.reduce(0, +) / CGFloat(velocityHistory.count)

            // Apply acceleration curve (like macOS trackpad)
            let accelerationMultiplier: CGFloat
            if smoothedVelocity < accelerationThreshold {
                // Slow movement: precise control (1:1 or slightly less)
                accelerationMultiplier = baseSensitivity
            } else {
                // Fast movement: accelerate based on velocity
                let excess = smoothedVelocity - accelerationThreshold
                let normalized = excess / 20.0 // Normalize the excess
                let curved = pow(normalized, accelerationCurve)
                accelerationMultiplier = min(baseSensitivity + curved * (maxAcceleration - baseSensitivity), maxAcceleration)
            }

            let deltaX = rawDeltaX * accelerationMultiplier
            let deltaY = rawDeltaY * accelerationMultiplier

            // Send if any movement detected
            if abs(deltaX) > 0.2 || abs(deltaY) > 0.2 {
                onMove?(deltaX, deltaY)
            }

        } else if activeTouches.count == 2 {
            // Two finger move - scrolling
            let currentCenter = calculateCenter(of: activeTouches)

            if let previousCenter = previousTwoFingerCenter {
                let deltaX = (currentCenter.x - previousCenter.x) * scrollSensitivity
                let deltaY = (currentCenter.y - previousCenter.y) * scrollSensitivity

                // Invert for natural scrolling
                if abs(deltaX) > 0.5 || abs(deltaY) > 0.5 {
                    onScroll?(-deltaX, -deltaY)
                }
            }

            previousTwoFingerCenter = currentCenter
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touchCountBefore = activeTouches.count

        // Remove ended touches
        for touch in touches {
            if let index = activeTouches.firstIndex(of: touch) {
                activeTouches.remove(at: index)
            }
        }

        // Check for tap gestures
        if let startTime = touchStartTime {
            let duration = Date().timeIntervalSince(startTime)

            if touchCountBefore == 1 {
                // Check for single finger tap
                if duration < tapMaxDuration {
                    if let startPos = touchStartPosition,
                       let touch = touches.first {
                        let endPos = touch.location(in: self)
                        let movement = hypot(endPos.x - startPos.x, endPos.y - startPos.y)

                        if movement < tapMaxMovement {
                            // This is a tap - send click
                            onClick?()
                        }
                    }
                }
            } else if touchCountBefore == 2 {
                // Check for two finger tap (right click)
                if duration < twoFingerTapMaxDuration {
                    let allTouchesEnded = activeTouches.isEmpty
                    if allTouchesEnded {
                        // Verify minimal movement for both touches
                        var totalMovement: CGFloat = 0
                        for touch in touches {
                            if let startPos = touchStartPosition {
                                let endPos = touch.location(in: self)
                                totalMovement += hypot(endPos.x - startPos.x, endPos.y - startPos.y)
                            }
                        }

                        if totalMovement < tapMaxMovement * 2 {
                            onRightClick?()
                        }
                    }
                }
            }
        }

        // Reset state when all touches end
        if activeTouches.isEmpty {
            resetState()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if let index = activeTouches.firstIndex(of: touch) {
                activeTouches.remove(at: index)
            }
        }

        if activeTouches.isEmpty {
            resetState()
        }
    }

    // MARK: - Helpers

    private func calculateCenter(of touches: [UITouch]) -> CGPoint {
        guard !touches.isEmpty else { return .zero }

        var sumX: CGFloat = 0
        var sumY: CGFloat = 0

        for touch in touches {
            let position = touch.location(in: self)
            sumX += position.x
            sumY += position.y
        }

        return CGPoint(
            x: sumX / CGFloat(touches.count),
            y: sumY / CGFloat(touches.count)
        )
    }

    private func resetState() {
        previousTouchPosition = nil
        touchStartTime = nil
        touchStartPosition = nil
        previousTwoFingerCenter = nil
        activeTouches.removeAll()
        lastMoveTime = nil
        velocityHistory.removeAll()
    }
}
