import CoreGraphics
import Testing
@testable import ThreeFingerClick

@Suite("ThreeFingerClickDetector")
struct ThreeFingerClickDetectorTests {
    @Test("valid three-finger click triggers on mouse up and consumes both events")
    func validThreeFingerClickTriggersOnMouseUp() {
        var detector = ThreeFingerClickDetector()
        let down = detector.handle(
            ClickInput(phase: .down, timestamp: 1.0, location: CGPoint(x: 10, y: 10)),
            touch: TouchSnapshot(fingerCount: 3, timestamp: 0.95)
        )
        let up = detector.handle(
            ClickInput(phase: .up, timestamp: 1.12, location: CGPoint(x: 12, y: 12)),
            touch: TouchSnapshot(fingerCount: 3, timestamp: 1.10)
        )

        #expect(down.consumeOriginalClick)
        #expect(!down.triggerAction)
        #expect(up.consumeOriginalClick)
        #expect(up.triggerAction)
    }

    @Test("stale touch data does not create a candidate")
    func staleTouchDataDoesNotCreateCandidate() {
        var detector = ThreeFingerClickDetector()
        let down = detector.handle(
            ClickInput(phase: .down, timestamp: 1.0, location: .zero),
            touch: TouchSnapshot(fingerCount: 3, timestamp: 0.5)
        )
        let up = detector.handle(
            ClickInput(phase: .up, timestamp: 1.1, location: .zero),
            touch: TouchSnapshot(fingerCount: 3, timestamp: 1.1)
        )

        #expect(!down.consumeOriginalClick)
        #expect(!up.triggerAction)
    }

    @Test("non-three-finger click is ignored")
    func nonThreeFingerClickIsIgnored() {
        var detector = ThreeFingerClickDetector()
        let down = detector.handle(
            ClickInput(phase: .down, timestamp: 1.0, location: .zero),
            touch: TouchSnapshot(fingerCount: 2, timestamp: 0.99)
        )
        let up = detector.handle(
            ClickInput(phase: .up, timestamp: 1.1, location: .zero),
            touch: TouchSnapshot(fingerCount: 2, timestamp: 1.09)
        )

        #expect(!down.consumeOriginalClick)
        #expect(!up.triggerAction)
    }

    @Test("long click is consumed but does not trigger")
    func longClickDoesNotTrigger() {
        var detector = ThreeFingerClickDetector()
        _ = detector.handle(
            ClickInput(phase: .down, timestamp: 1.0, location: .zero),
            touch: TouchSnapshot(fingerCount: 3, timestamp: 0.99)
        )
        let up = detector.handle(
            ClickInput(phase: .up, timestamp: 1.7, location: .zero),
            touch: TouchSnapshot(fingerCount: 3, timestamp: 1.69)
        )

        #expect(up.consumeOriginalClick)
        #expect(!up.triggerAction)
    }

    @Test("large pointer movement is consumed but does not trigger")
    func largePointerMovementDoesNotTrigger() {
        var detector = ThreeFingerClickDetector()
        _ = detector.handle(
            ClickInput(phase: .down, timestamp: 1.0, location: CGPoint(x: 0, y: 0)),
            touch: TouchSnapshot(fingerCount: 3, timestamp: 0.99)
        )
        let up = detector.handle(
            ClickInput(phase: .up, timestamp: 1.1, location: CGPoint(x: 30, y: 0)),
            touch: TouchSnapshot(fingerCount: 3, timestamp: 1.09)
        )

        #expect(up.consumeOriginalClick)
        #expect(!up.triggerAction)
    }
}
