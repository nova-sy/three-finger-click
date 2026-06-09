import ApplicationServices
import CoreGraphics
import Foundation

struct DiagnosticsSnapshot: Equatable {
    var accessibilityTrusted: Bool
    var touchDeviceCount: Int
    var touchFrameCount: Int
    var lastFingerCount: Int?
    var lastTouchTimestamp: TimeInterval?
    var mouseDownCount: Int
    var mouseUpCount: Int
    var lastMousePhase: ClickPhase?
    var lastDecision: DetectionDecision?
    var actionCount: Int
    var tapStartAttempts: Int
    var tapActive: Bool
    var runtimeMessage: String?

    func menuLines(now: TimeInterval) -> [String] {
        let touchAge: String
        if let lastTouchTimestamp {
            touchAge = String(format: "%.3fs ago", now - lastTouchTimestamp)
        } else {
            touchAge = "never"
        }

        return [
            "AX: \(accessibilityTrusted ? "trusted" : "not trusted")",
            "Touch devices: \(touchDeviceCount)",
            "Touch frames: \(touchFrameCount)",
            "Last fingers: \(lastFingerCount.map(String.init) ?? "none") (\(touchAge))",
            "Mouse down/up: \(mouseDownCount)/\(mouseUpCount)",
            "Last mouse: \(lastMousePhase.map { String(describing: $0) } ?? "none")",
            "Last decision: \(lastDecision.map { "trigger=\($0.triggerAction), consume=\($0.consumeOriginalClick)" } ?? "none")",
            "Actions: \(actionCount)",
            "Tap starts: \(tapStartAttempts)",
            "Tap active: \(tapActive ? "yes" : "no")",
            "Message: \(runtimeMessage ?? "none")"
        ]
    }

    func pasteboardText(now: TimeInterval) -> String {
        menuLines(now: now).joined(separator: "\n")
    }
}

final class DiagnosticsStore {
    private let lock = NSLock()
    private var snapshot = DiagnosticsSnapshot(
        accessibilityTrusted: false,
        touchDeviceCount: 0,
        touchFrameCount: 0,
        lastFingerCount: nil,
        lastTouchTimestamp: nil,
        mouseDownCount: 0,
        mouseUpCount: 0,
        lastMousePhase: nil,
        lastDecision: nil,
        actionCount: 0,
        tapStartAttempts: 0,
        tapActive: false,
        runtimeMessage: nil
    )

    func currentSnapshot() -> DiagnosticsSnapshot {
        lock.withLock {
            snapshot
        }
    }

    func setAccessibilityTrusted(_ trusted: Bool) {
        lock.withLock {
            snapshot.accessibilityTrusted = trusted
        }
    }

    func setTouchDeviceCount(_ count: Int) {
        lock.withLock {
            snapshot.touchDeviceCount = count
        }
    }

    func recordTouchFrame(fingerCount: Int, timestamp: TimeInterval) {
        lock.withLock {
            snapshot.touchFrameCount += 1
            snapshot.lastFingerCount = fingerCount
            snapshot.lastTouchTimestamp = timestamp
        }
    }

    func recordMouseEvent(phase: ClickPhase, decision: DetectionDecision) {
        lock.withLock {
            switch phase {
            case .down:
                snapshot.mouseDownCount += 1
            case .up:
                snapshot.mouseUpCount += 1
            }
            snapshot.lastMousePhase = phase
            snapshot.lastDecision = decision
        }
    }

    func recordAction() {
        lock.withLock {
            snapshot.actionCount += 1
        }
    }

    func recordTapStartAttempt() {
        lock.withLock {
            snapshot.tapStartAttempts += 1
        }
    }

    func setTapActive(_ active: Bool) {
        lock.withLock {
            snapshot.tapActive = active
        }
    }

    func setRuntimeMessage(_ message: String?) {
        lock.withLock {
            snapshot.runtimeMessage = message
        }
    }
}

func isProcessAccessibilityTrusted(prompt: Bool) -> Bool {
    let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}
