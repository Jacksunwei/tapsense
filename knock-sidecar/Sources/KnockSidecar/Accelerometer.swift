import Foundation
import IOKit
import IOKit.hid

struct AccelerometerReading {
    let x: Double
    let y: Double
    let z: Double
    let timestamp: TimeInterval
}

protocol AccelerometerSource {
    func start(callback: @escaping (AccelerometerReading) -> Void) -> Bool
    func stop()
}

final class IOKitAccelerometer: AccelerometerSource {
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var callback: ((AccelerometerReading) -> Void)?
    private static let reportBufferLength = 64
    private let reportBuffer: UnsafeMutablePointer<UInt8>
    private let usagePage: Int = 0xFF00
    private let usage: Int = 0x03

    init() {
        reportBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Self.reportBufferLength)
        reportBuffer.initialize(repeating: 0, count: Self.reportBufferLength)
    }

    deinit {
        stop()
        reportBuffer.deinitialize(count: Self.reportBufferLength)
        reportBuffer.deallocate()
    }

    func start(callback: @escaping (AccelerometerReading) -> Void) -> Bool {
        self.callback = callback

        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager

        let matching: [String: Any] = [
            kIOHIDPrimaryUsagePageKey as String: usagePage,
            kIOHIDPrimaryUsageKey as String: usage,
        ]

        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, deviceMatched, selfPtr)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, deviceRemoved, selfPtr)

        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            fputs("[accelerometer] Failed to open IOHIDManager: \(openResult)\n", stderr)
            return false
        }

        if let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
           let existing = devices.first {
            attach(to: existing)
        }

        if device == nil {
            fputs("[accelerometer] No Apple SPU accelerometer device matched usage page 0xFF00 / usage 0x03.\n", stderr)
            fputs("[accelerometer] This prototype falls back to simulate mode well, but real mode depends on the private HID device being visible on this Mac.\n", stderr)
            return false
        }

        return true
    }

    func stop() {
        if let device {
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }

        if let manager {
            IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }

        device = nil
        manager = nil
        callback = nil
    }

    func attach(to device: IOHIDDevice) {
        self.device = device

        let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        guard openResult == kIOReturnSuccess else {
            fputs("[accelerometer] Failed to open HID device: \(openResult)\n", stderr)
            return
        }

        IOHIDDeviceScheduleWithRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(
            device,
            reportBuffer,
            Self.reportBufferLength,
            inputReportCallback,
            selfPtr
        )

        fputs("[accelerometer] Connected to HID accelerometer device.\n", stderr)
    }

    func handleReport(_ report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        guard length >= 18 else { return }

        let buffer = UnsafeBufferPointer(start: report, count: length)
        guard let x = readInt32LE(buffer, offset: 6),
              let y = readInt32LE(buffer, offset: 10),
              let z = readInt32LE(buffer, offset: 14) else {
            return
        }

        let reading = AccelerometerReading(
            x: Double(x) / 65536.0,
            y: Double(y) / 65536.0,
            z: Double(z) / 65536.0,
            timestamp: ProcessInfo.processInfo.systemUptime
        )

        self.callback?(reading)
    }

    private func readInt32LE(_ buffer: UnsafeBufferPointer<UInt8>, offset: Int) -> Int32? {
        guard offset + 4 <= buffer.count else { return nil }
        let value = UInt32(buffer[offset])
            | (UInt32(buffer[offset + 1]) << 8)
            | (UInt32(buffer[offset + 2]) << 16)
            | (UInt32(buffer[offset + 3]) << 24)
        return Int32(bitPattern: value)
    }
}

private func deviceMatched(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    let accelerometer = Unmanaged<IOKitAccelerometer>.fromOpaque(context).takeUnretainedValue()
    accelerometer.attach(to: device)
}

private func deviceRemoved(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    device: IOHIDDevice
) {
    guard let context else { return }
    let _ = Unmanaged<IOKitAccelerometer>.fromOpaque(context).takeUnretainedValue()
    fputs("[accelerometer] HID device removed.\n", stderr)
}

private func inputReportCallback(
    context: UnsafeMutableRawPointer?,
    result: IOReturn,
    sender: UnsafeMutableRawPointer?,
    reportType: IOHIDReportType,
    reportID: UInt32,
    report: UnsafeMutablePointer<UInt8>,
    reportLength: CFIndex
) {
    guard let context else { return }
    guard result == kIOReturnSuccess else { return }

    let accelerometer = Unmanaged<IOKitAccelerometer>.fromOpaque(context).takeUnretainedValue()
    accelerometer.handleReport(report, length: reportLength)
}
