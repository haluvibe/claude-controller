// TrackpadGestureView.swift
// iPad Trackpad App - Custom Gesture Recognition
// iOS 18+

import UIKit

/// Custom UIView that handles all trackpad gesture recognition
class TrackpadGestureView: UIView {

    // MARK: - Properties

    weak var delegate: TrackpadGestureViewDelegate?
    var configuration = TrackpadConfiguration()

    // Touch tracking
    private var activeTouches: [UITouch: TouchInfo] = [:]
    private var previousTouchPositions: [UITouch: CGPoint] = [:]
    private var touchStartTime: Date?
    private var lastTapTime: Date?
    private var lastTapPosition: CGPoint?
    private var tapCount = 0

    // Gesture state
    private var isDragging = false
    private var isScrolling = false
    private var isPinching = false
    private var dragStarted = false
    private var initialPinchDistance: CGFloat = 0

    // Timers
    private var longPressTimer: Timer?
    private var tapRecognitionTimer: Timer?

    // Thresholds
    private let movementThreshold: CGFloat = 5.0
    private let scrollActivationThreshold: CGFloat = 8.0
    private let pinchActivationThreshold: CGFloat = 15.0
    private let tapMovementTolerance: CGFloat = 20.0

    // MARK: - Touch Info

    struct TouchInfo {
        let startPosition: CGPoint
        let startTime: Date
        var currentPosition: CGPoint
        var hasMovedSignificantly: Bool = false
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let position = touch.location(in: self)
            activeTouches[touch] = TouchInfo(
                startPosition: position,
                startTime: Date(),
                currentPosition: position
            )
            previousTouchPositions[touch] = position
        }

        touchStartTime = Date()
        cancelLongPressTimer()

        // Notify delegate of touch positions
        let positions = activeTouches.values.map { $0.currentPosition }
        delegate?.touchesBegan(count: activeTouches.count, positions: positions)

        // Start long press detection for single finger
        if activeTouches.count == 1 {
            startLongPressTimer()
        }

        // Handle gesture initialization based on finger count
        handleGestureStart()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        var totalDelta = CGPoint.zero
        var touchCount = 0

        for touch in touches {
            guard var info = activeTouches[touch],
                  let previousPosition = previousTouchPositions[touch] else { continue }

            let currentPosition = touch.location(in: self)
            let delta = CGPoint(
                x: currentPosition.x - previousPosition.x,
                y: currentPosition.y - previousPosition.y
            )

            // Check if moved significantly
            let distanceFromStart = hypot(
                currentPosition.x - info.startPosition.x,
                currentPosition.y - info.startPosition.y
            )
            if distanceFromStart > movementThreshold {
                info.hasMovedSignificantly = true
                cancelLongPressTimer()
            }

            info.currentPosition = currentPosition
            activeTouches[touch] = info
            previousTouchPositions[touch] = currentPosition

            totalDelta.x += delta.x
            totalDelta.y += delta.y
            touchCount += 1
        }

        guard touchCount > 0 else { return }

        // Average the delta for multi-touch
        let averageDelta = CGPoint(
            x: totalDelta.x / CGFloat(touchCount),
            y: totalDelta.y / CGFloat(touchCount)
        )

        // Determine gesture type and handle
        handleGestureMove(delta: averageDelta)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touchCountBefore = activeTouches.count

        for touch in touches {
            if let info = activeTouches[touch] {
                handleTouchEnd(info: info, touchCount: touchCountBefore)
            }
            activeTouches.removeValue(forKey: touch)
            previousTouchPositions.removeValue(forKey: touch)
        }

        cancelLongPressTimer()

        if activeTouches.isEmpty {
            handleAllTouchesEnded(previousCount: touchCountBefore)
            delegate?.touchesEnded()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            activeTouches.removeValue(forKey: touch)
            previousTouchPositions.removeValue(forKey: touch)
        }

        cancelLongPressTimer()
        resetGestureState()
        delegate?.touchesEnded()
    }

    // MARK: - Gesture Handling

    private func handleGestureStart() {
        switch activeTouches.count {
        case 1:
            // Single finger - could be move, tap, or drag
            break

        case 2:
            // Two fingers - scroll or pinch
            isScrolling = false
            isPinching = false
            if let distance = twoFingerDistance() {
                initialPinchDistance = distance
            }

        case 3:
            // Three fingers - system gesture preparation
            break

        default:
            break
        }
    }

    private func handleGestureMove(delta: CGPoint) {
        let magnitude = hypot(delta.x, delta.y)

        switch activeTouches.count {
        case 1:
            // Single finger movement
            if isDragging {
                delegate?.didContinueDrag(delta: applyAcceleration(to: delta))
            } else {
                delegate?.didMove(delta: applyAcceleration(to: delta))
            }

        case 2:
            // Two finger scroll or pinch
            if !isPinching, let currentDistance = twoFingerDistance() {
                let distanceChange = abs(currentDistance - initialPinchDistance)

                if distanceChange > pinchActivationThreshold {
                    isPinching = true
                    delegate?.didPinch(scale: currentDistance / initialPinchDistance, phase: .began)
                } else if magnitude > scrollActivationThreshold {
                    isScrolling = true
                    let scrollDelta = configuration.naturalScrolling ?
                        CGPoint(x: -delta.x, y: -delta.y) : delta
                    delegate?.didScroll(delta: applyScrollSensitivity(to: scrollDelta), phase: .began)
                }
            } else if isPinching, let currentDistance = twoFingerDistance() {
                delegate?.didPinch(scale: currentDistance / initialPinchDistance, phase: .changed)
            } else if isScrolling {
                let scrollDelta = configuration.naturalScrolling ?
                    CGPoint(x: -delta.x, y: -delta.y) : delta
                delegate?.didScroll(delta: applyScrollSensitivity(to: scrollDelta), phase: .changed)
            }

        case 3:
            // Three finger swipe detection
            detectThreeFingerSwipe(delta: delta)

        default:
            break
        }
    }

    private func handleTouchEnd(info: TouchInfo, touchCount: Int) {
        let touchDuration = Date().timeIntervalSince(info.startTime)
        let isTap = !info.hasMovedSignificantly && touchDuration < configuration.longPressThreshold
        let distance = hypot(
            info.currentPosition.x - info.startPosition.x,
            info.currentPosition.y - info.startPosition.y
        )

        // For single-finger tap recognition
        if touchCount == 1 && isTap && distance < tapMovementTolerance {
            handleSingleFingerTap(at: info.currentPosition)
        }
    }

    private func handleAllTouchesEnded(previousCount: Int) {
        // End any ongoing gestures
        if isScrolling {
            delegate?.didScroll(delta: .zero, phase: .ended)
            isScrolling = false
        }

        if isPinching {
            delegate?.didPinch(scale: 1.0, phase: .ended)
            isPinching = false
        }

        if isDragging {
            if let lastTouch = activeTouches.values.first {
                delegate?.didEndDrag(at: lastTouch.currentPosition)
            }
            isDragging = false
            dragStarted = false
        }

        // Two-finger tap (right-click)
        if previousCount == 2 {
            let positions = previousTouchPositions.values
            if allTouchesWereTaps() {
                let center = positions.reduce(CGPoint.zero) { result, point in
                    CGPoint(x: result.x + point.x, y: result.y + point.y)
                }
                let averagePosition = CGPoint(
                    x: center.x / CGFloat(positions.count),
                    y: center.y / CGFloat(positions.count)
                )
                delegate?.didTwoFingerTap(at: averagePosition)
            }
        }
    }

    private func handleSingleFingerTap(at position: CGPoint) {
        let now = Date()

        // Check for double-tap
        if let lastTap = lastTapTime,
           let lastPos = lastTapPosition,
           now.timeIntervalSince(lastTap) < configuration.doubleTapMaxInterval,
           hypot(position.x - lastPos.x, position.y - lastPos.y) < tapMovementTolerance {
            // Double tap
            tapCount += 1
            if tapCount >= 2 {
                delegate?.didTap(at: position, tapCount: 2)
                tapCount = 0
                lastTapTime = nil
                lastTapPosition = nil
                return
            }
        } else {
            tapCount = 1
        }

        lastTapTime = now
        lastTapPosition = position

        // Delay single tap to allow for double-tap detection
        tapRecognitionTimer?.invalidate()
        tapRecognitionTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.doubleTapMaxInterval,
            repeats: false
        ) { [weak self] _ in
            guard let self = self else { return }
            if self.tapCount == 1 {
                self.delegate?.didTap(at: position, tapCount: 1)
            }
            self.tapCount = 0
        }
    }

    // MARK: - Helper Methods

    private func startLongPressTimer() {
        longPressTimer = Timer.scheduledTimer(
            withTimeInterval: configuration.longPressThreshold,
            repeats: false
        ) { [weak self] _ in
            guard let self = self,
                  let touch = self.activeTouches.first,
                  !touch.value.hasMovedSignificantly else { return }

            self.isDragging = true
            self.dragStarted = true
            self.delegate?.didStartDrag(at: touch.value.currentPosition)
            HapticFeedbackManager.shared.click()
        }
    }

    private func cancelLongPressTimer() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }

    private func twoFingerDistance() -> CGFloat? {
        let positions = Array(activeTouches.values.map { $0.currentPosition })
        guard positions.count >= 2 else { return nil }
        return hypot(
            positions[0].x - positions[1].x,
            positions[0].y - positions[1].y
        )
    }

    private func allTouchesWereTaps() -> Bool {
        // Check if all recent touches were brief with minimal movement
        guard let startTime = touchStartTime else { return false }
        let duration = Date().timeIntervalSince(startTime)
        return duration < configuration.longPressThreshold
    }

    private func detectThreeFingerSwipe(delta: CGPoint) {
        let threshold: CGFloat = 50.0
        let absX = abs(delta.x)
        let absY = abs(delta.y)

        if absY > threshold && absY > absX {
            let direction: SwipeDirection = delta.y < 0 ? .up : .down
            delegate?.didThreeFingerSwipe(direction: direction)
        } else if absX > threshold && absX > absY {
            let direction: SwipeDirection = delta.x < 0 ? .left : .right
            delegate?.didThreeFingerSwipe(direction: direction)
        }
    }

    private func applyAcceleration(to delta: CGPoint) -> CGPoint {
        guard configuration.accelerationEnabled else {
            return CGPoint(
                x: delta.x * configuration.cursorSensitivity,
                y: delta.y * configuration.cursorSensitivity
            )
        }

        let velocity = hypot(delta.x, delta.y)
        let multiplier = configuration.accelerationCurve.apply(to: velocity) / max(velocity, 0.001)

        return CGPoint(
            x: delta.x * multiplier * configuration.cursorSensitivity,
            y: delta.y * multiplier * configuration.cursorSensitivity
        )
    }

    private func applyScrollSensitivity(to delta: CGPoint) -> CGPoint {
        return CGPoint(
            x: delta.x * configuration.scrollSensitivity,
            y: delta.y * configuration.scrollSensitivity
        )
    }

    private func resetGestureState() {
        isDragging = false
        isScrolling = false
        isPinching = false
        dragStarted = false
        tapCount = 0
    }
}

// MARK: - Three-Finger Gesture Accumulator

extension TrackpadGestureView {
    /// Accumulates three-finger movement to detect swipe gestures
    private class ThreeFingerGestureTracker {
        var accumulatedDelta: CGPoint = .zero
        var startTime: Date?
        let swipeThreshold: CGFloat = 100.0
        let maxDuration: TimeInterval = 0.5

        func reset() {
            accumulatedDelta = .zero
            startTime = nil
        }

        func accumulate(_ delta: CGPoint) -> SwipeDirection? {
            if startTime == nil {
                startTime = Date()
            }

            accumulatedDelta.x += delta.x
            accumulatedDelta.y += delta.y

            // Check if gesture completed
            guard let start = startTime,
                  Date().timeIntervalSince(start) < maxDuration else {
                reset()
                return nil
            }

            let absX = abs(accumulatedDelta.x)
            let absY = abs(accumulatedDelta.y)

            if absY > swipeThreshold && absY > absX * 1.5 {
                let direction: SwipeDirection = accumulatedDelta.y < 0 ? .up : .down
                reset()
                return direction
            }

            if absX > swipeThreshold && absX > absY * 1.5 {
                let direction: SwipeDirection = accumulatedDelta.x < 0 ? .left : .right
                reset()
                return direction
            }

            return nil
        }
    }
}
