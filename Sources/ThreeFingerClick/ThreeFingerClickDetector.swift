import CoreGraphics
import Foundation

struct TouchSnapshot: Equatable {
    var fingerCount: Int
    var timestamp: TimeInterval
}

enum ClickPhase: Equatable {
    case down
    case up
}

struct ClickInput: Equatable {
    var phase: ClickPhase
    var timestamp: TimeInterval
    var location: CGPoint
}

struct DetectionDecision: Equatable {
    var triggerAction: Bool
    var consumeOriginalClick: Bool

    static let ignore = DetectionDecision(triggerAction: false, consumeOriginalClick: false)
}

struct ThreeFingerClickDetectorConfig: Equatable {
    var requiredFingerCount = 3
    var touchFreshness: TimeInterval = 0.10
    var maxClickDuration: TimeInterval = 0.50
    var maxPointerMovement: CGFloat = 10.0
    var consumeOriginalClick = true
}

struct ThreeFingerClickDetector {
    var isEnabled = true
    var config = ThreeFingerClickDetectorConfig()

    private var candidate: Candidate?

    mutating func reset() {
        candidate = nil
    }

    mutating func handle(_ click: ClickInput, touch: TouchSnapshot?) -> DetectionDecision {
        guard isEnabled else {
            candidate = nil
            return .ignore
        }

        switch click.phase {
        case .down:
            guard isFreshThreeFingerTouch(touch, at: click.timestamp) else {
                candidate = nil
                return .ignore
            }

            candidate = Candidate(timestamp: click.timestamp, location: click.location)
            return DetectionDecision(triggerAction: false, consumeOriginalClick: config.consumeOriginalClick)

        case .up:
            guard let candidate else {
                return .ignore
            }
            self.candidate = nil

            let duration = click.timestamp - candidate.timestamp
            let movement = hypot(click.location.x - candidate.location.x, click.location.y - candidate.location.y)
            let shouldTrigger = duration <= config.maxClickDuration
                && movement <= config.maxPointerMovement
                && isFreshThreeFingerTouch(touch, at: click.timestamp)

            return DetectionDecision(
                triggerAction: shouldTrigger,
                consumeOriginalClick: config.consumeOriginalClick
            )
        }
    }

    private func isFreshThreeFingerTouch(_ touch: TouchSnapshot?, at timestamp: TimeInterval) -> Bool {
        guard let touch else {
            return false
        }

        let age = abs(timestamp - touch.timestamp)
        return touch.fingerCount == config.requiredFingerCount && age <= config.touchFreshness
    }
}

private struct Candidate {
    var timestamp: TimeInterval
    var location: CGPoint
}
