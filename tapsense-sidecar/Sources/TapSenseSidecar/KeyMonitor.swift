import Foundation
import CoreGraphics

/// Watches global keyboard events via CGEventTap. Exposes the timestamp of the most
/// recent key event so the tap detector can ignore accelerometer vibrations caused by typing.
///
/// Requires root OR accessibility permission. Under `sudo` the tap is allowed.
final class KeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private(set) var lastKeyEventTime: TimeInterval = 0
    private(set) var eventCount: Int = 0

    func start() -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue)
                 | (1 << CGEventType.flagsChanged.rawValue)
                 | (1 << CGEventType.leftMouseDown.rawValue)
                 | (1 << CGEventType.leftMouseUp.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // Try HID-level tap first (captures events earlier, more reliable under sudo).
        var tapKind = "cghidEventTap"
        var tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: keyTapCallback,
            userInfo: selfPtr
        )
        if tap == nil {
            tapKind = "cgSessionEventTap"
            tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .listenOnly,
                eventsOfInterest: CGEventMask(mask),
                callback: keyTapCallback,
                userInfo: selfPtr
            )
        }

        guard let tap else {
            fputs("[keymonitor] CGEvent.tapCreate failed on BOTH hid and session (need root or Accessibility).\n", stderr)
            return false
        }
        fputs("[keymonitor] tapCreate succeeded (\(tapKind)).\n", stderr)

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.eventTap = tap
        self.runLoopSource = source
        fputs("[keymonitor] Keyboard suppression active.\n", stderr)
        return true
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .defaultMode)
        }
        eventTap = nil
        runLoopSource = nil
    }

    fileprivate func noteKey() {
        lastKeyEventTime = ProcessInfo.processInfo.systemUptime
        eventCount += 1
        if eventCount == 1 {
            fputs("[keymonitor] First key event received — suppression confirmed working.\n", stderr)
        }
    }
}

private func keyTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let userInfo {
        let monitor = Unmanaged<KeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        monitor.noteKey()
    }
    return Unmanaged.passUnretained(event)
}
