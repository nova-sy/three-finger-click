import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var enabledMenuItem: NSMenuItem?
    private var statusMenuItem: NSMenuItem?
    private var touchTracker: TouchTracker?
    private var clickTap: ClickTap?
    private let diagnostics = DiagnosticsStore()
    private lazy var actionRunner = ActionRunner(diagnostics: diagnostics)
    private var isEnabled = true
    private var lastRuntimeMessage: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        startServices()
        refreshStatus()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clickTap?.stop()
        touchTracker?.stop()
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let image = NSImage(systemSymbolName: "hand.tap", accessibilityDescription: "Three Finger Click") {
            image.isTemplate = true
            item.button?.image = image
        } else {
            item.button?.title = "3F"
        }

        let menu = NSMenu()
        menu.delegate = self

        let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledItem.target = self
        enabledItem.state = isEnabled ? .on : .off
        menu.addItem(enabledItem)

        let statusLineItem = NSMenuItem(title: "Status: Starting", action: nil, keyEquivalent: "")
        statusLineItem.isEnabled = false
        menu.addItem(statusLineItem)

        let permissionsItem = NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permissionsItem.target = self
        menu.addItem(permissionsItem)

        let restartItem = NSMenuItem(title: "Restart Listener", action: #selector(restartServices), keyEquivalent: "")
        restartItem.target = self
        menu.addItem(restartItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu

        enabledMenuItem = enabledItem
        statusMenuItem = statusLineItem
        self.statusItem = item
        refreshStatus()
    }

    func menuWillOpen(_ menu: NSMenu) {
        let trusted = isProcessAccessibilityTrusted(prompt: false)
        diagnostics.setAccessibilityTrusted(trusted)
        if trusted, clickTap == nil, lastRuntimeMessage?.contains("Accessibility permission") == true {
            startServices()
        }
        refreshStatus()
    }

    @objc private func toggleEnabled(_ sender: NSMenuItem) {
        isEnabled.toggle()
        clickTap?.setEnabled(isEnabled)
        enabledMenuItem?.state = isEnabled ? .on : .off
        refreshStatus()
    }

    @objc private func restartServices() {
        startServices()
        refreshStatus()
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func startServices() {
        clickTap?.stop()
        touchTracker?.stop()
        clickTap = nil
        touchTracker = nil
        lastRuntimeMessage = nil
        diagnostics.setRuntimeMessage(nil)
        diagnostics.setTapActive(false)
        diagnostics.setAccessibilityTrusted(isProcessAccessibilityTrusted(prompt: false))

        let tracker = TouchTracker(diagnostics: diagnostics)
        do {
            try tracker.start()
            touchTracker = tracker
        } catch {
            lastRuntimeMessage = "Touch: \(error.localizedDescription)"
            diagnostics.setRuntimeMessage(lastRuntimeMessage)
            return
        }

        let runner = actionRunner
        let tap = ClickTap(
            touchSnapshotProvider: { [weak tracker] in
                tracker?.latestSnapshot
            },
            diagnostics: diagnostics,
            action: {
                runner.sendCommandW()
            }
        )

        do {
            tap.setEnabled(isEnabled)
            try tap.start(promptForAccessibility: true)
            clickTap = tap
            diagnostics.setRuntimeMessage("Tap started")
        } catch {
            lastRuntimeMessage = "Tap: \(error.localizedDescription)"
            diagnostics.setRuntimeMessage(lastRuntimeMessage)
        }
    }

    private func refreshStatus() {
        if let lastRuntimeMessage {
            statusMenuItem?.title = "Status: \(lastRuntimeMessage)"
            return
        }

        let enabledText = isEnabled ? "Enabled" : "Disabled"
        let touchText = touchTracker == nil ? "Touch unavailable" : "Touch ready"
        let tapText = clickTap == nil ? "Tap unavailable" : "Tap ready"
        statusMenuItem?.title = "Status: \(enabledText), \(touchText), \(tapText)"
    }
}
