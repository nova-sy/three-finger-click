import CoreGraphics
import Foundation

final class ActionRunner {
    private let commandWKeyCode: CGKeyCode = 13
    private let diagnostics: DiagnosticsStore?

    init(diagnostics: DiagnosticsStore? = nil) {
        self.diagnostics = diagnostics
    }

    func sendCommandW() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: commandWKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: commandWKeyCode, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
        diagnostics?.recordAction()
    }
}
