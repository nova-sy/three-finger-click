import CoreFoundation
import Darwin
import Foundation

enum TouchTrackerError: LocalizedError {
    case frameworkUnavailable
    case missingSymbol(String)
    case noDevices

    var errorDescription: String? {
        switch self {
        case .frameworkUnavailable:
            return "Unable to load private MultitouchSupport.framework."
        case .missingSymbol(let name):
            return "MultitouchSupport.framework is missing symbol \(name)."
        case .noDevices:
            return "No multitouch trackpad devices were reported by MultitouchSupport."
        }
    }
}

final class TouchTracker {
    fileprivate typealias MTContactFrameCallback = @convention(c) (
        UnsafeMutableRawPointer?,
        UnsafeMutableRawPointer?,
        Int32,
        Double,
        Int32
    ) -> Int32

    private typealias MTDeviceCreateListFunction = @convention(c) () -> Unmanaged<CFArray>?
    private typealias MTRegisterContactFrameCallbackFunction = @convention(c) (
        UnsafeMutableRawPointer,
        MTContactFrameCallback
    ) -> Void
    private typealias MTDeviceStartFunction = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void
    private typealias MTDeviceStopFunction = @convention(c) (UnsafeMutableRawPointer) -> Void
    private typealias MTDeviceReleaseFunction = @convention(c) (UnsafeMutableRawPointer) -> Void

    nonisolated(unsafe) fileprivate static weak var activeTracker: TouchTracker?

    private let lock = NSLock()
    private var frameworkHandle: UnsafeMutableRawPointer?
    private var devices: [UnsafeMutableRawPointer] = []
    private var stopDevice: MTDeviceStopFunction?
    private var releaseDevice: MTDeviceReleaseFunction?
    private var snapshot: TouchSnapshot?
    private let diagnostics: DiagnosticsStore?

    init(diagnostics: DiagnosticsStore? = nil) {
        self.diagnostics = diagnostics
    }

    var latestSnapshot: TouchSnapshot? {
        lock.withLock {
            snapshot
        }
    }

    func start() throws {
        let frameworkPath = "/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(frameworkPath, RTLD_NOW) else {
            throw TouchTrackerError.frameworkUnavailable
        }

        frameworkHandle = handle

        let createList: MTDeviceCreateListFunction = try load("MTDeviceCreateList", from: handle)
        let registerCallback: MTRegisterContactFrameCallbackFunction = try load("MTRegisterContactFrameCallback", from: handle)
        let startDevice: MTDeviceStartFunction = try load("MTDeviceStart", from: handle)
        let stopDevice: MTDeviceStopFunction = try load("MTDeviceStop", from: handle)
        let releaseDevice: MTDeviceReleaseFunction = try load("MTDeviceRelease", from: handle)

        self.stopDevice = stopDevice
        self.releaseDevice = releaseDevice

        guard let unmanagedDeviceList = createList() else {
            throw TouchTrackerError.noDevices
        }

        let deviceList = unmanagedDeviceList.takeRetainedValue()
        let count = CFArrayGetCount(deviceList)
        guard count > 0 else {
            throw TouchTrackerError.noDevices
        }
        diagnostics?.setTouchDeviceCount(count)

        TouchTracker.activeTracker = self

        for index in 0..<count {
            guard let value = CFArrayGetValueAtIndex(deviceList, index) else {
                continue
            }
            let device = UnsafeMutableRawPointer(mutating: value)
            registerCallback(device, touchFrameCallback)
            startDevice(device, 0)
            devices.append(device)
        }

        if devices.isEmpty {
            throw TouchTrackerError.noDevices
        }
    }

    func stop() {
        for device in devices {
            stopDevice?(device)
            releaseDevice?(device)
        }
        devices.removeAll()
        lock.withLock {
            snapshot = nil
        }
        TouchTracker.activeTracker = nil

        if let frameworkHandle {
            dlclose(frameworkHandle)
        }
        frameworkHandle = nil
    }

    fileprivate func updateFingerCount(_ fingerCount: Int) {
        let timestamp = ProcessInfo.processInfo.systemUptime
        lock.withLock {
            snapshot = TouchSnapshot(
                fingerCount: fingerCount,
                timestamp: timestamp
            )
        }
        diagnostics?.recordTouchFrame(fingerCount: fingerCount, timestamp: timestamp)
    }

    private func load<T>(_ symbol: String, from handle: UnsafeMutableRawPointer) throws -> T {
        guard let pointer = dlsym(handle, symbol) else {
            throw TouchTrackerError.missingSymbol(symbol)
        }
        return unsafeBitCast(pointer, to: T.self)
    }
}

private let touchFrameCallback: TouchTracker.MTContactFrameCallback = { _, _, fingerCount, _, _ in
    TouchTracker.activeTracker?.updateFingerCount(Int(fingerCount))
    return 0
}
