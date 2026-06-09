import ApplicationServices
import CoreGraphics
import Foundation

enum ClickTapError: LocalizedError {
    case missingAccessibilityPermission
    case eventTapCreationFailed
    case runLoopSourceCreationFailed

    var errorDescription: String? {
        switch self {
        case .missingAccessibilityPermission:
            return "Accessibility permission is required for CGEventTap and synthetic keyboard events."
        case .eventTapCreationFailed:
            return "Unable to create CGEventTap."
        case .runLoopSourceCreationFailed:
            return "Unable to create a run loop source for CGEventTap."
        }
    }
}

final class ClickTap {
    private let lock = NSLock()
    private let touchSnapshotProvider: () -> TouchSnapshot?
    private let action: () -> Void
    private let diagnostics: DiagnosticsStore?
    private var detector = ThreeFingerClickDetector()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(
        touchSnapshotProvider: @escaping () -> TouchSnapshot?,
        diagnostics: DiagnosticsStore? = nil,
        action: @escaping () -> Void
    ) {
        self.touchSnapshotProvider = touchSnapshotProvider
        self.diagnostics = diagnostics
        self.action = action
    }

    func start(promptForAccessibility: Bool = true) throws {
        diagnostics?.recordTapStartAttempt()
        let trusted = isProcessAccessibilityTrusted(prompt: promptForAccessibility)
        diagnostics?.setAccessibilityTrusted(trusted)

        guard trusted else {
            diagnostics?.setTapActive(false)
            throw ClickTapError.missingAccessibilityPermission
        }

        let eventMask = (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.leftMouseUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: clickTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            diagnostics?.setTapActive(false)
            throw ClickTapError.eventTapCreationFailed
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            diagnostics?.setTapActive(false)
            throw ClickTapError.runLoopSourceCreationFailed
        }

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
        diagnostics?.setTapActive(true)
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        runLoopSource = nil
        eventTap = nil
        diagnostics?.setTapActive(false)
    }

    func setEnabled(_ isEnabled: Bool) {
        lock.withLock {
            detector.isEnabled = isEnabled
            if !isEnabled {
                detector.reset()
            }
        }
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let phase: ClickPhase
        switch type {
        case .leftMouseDown:
            phase = .down
        case .leftMouseUp:
            phase = .up
        default:
            return Unmanaged.passUnretained(event)
        }

        let input = ClickInput(
            phase: phase,
            timestamp: ProcessInfo.processInfo.systemUptime,
            location: event.location
        )

        let decision = lock.withLock {
            detector.handle(input, touch: touchSnapshotProvider())
        }
        diagnostics?.recordMouseEvent(phase: phase, decision: decision)

        if decision.triggerAction {
            action()
        }

        return decision.consumeOriginalClick ? nil : Unmanaged.passUnretained(event)
    }
}

private let clickTapCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }

    let tap = Unmanaged<ClickTap>.fromOpaque(refcon).takeUnretainedValue()
    return tap.handle(type: type, event: event)
}
