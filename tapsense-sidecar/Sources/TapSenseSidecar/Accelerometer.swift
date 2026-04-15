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
    private var device: IOHIDDevice?
    private var callback: ((AccelerometerReading) -> Void)?
    private static let reportBufferLength = 4096
    private static let xOffset = 6
    private static let yOffset = 10
    private static let zOffset = 14
    private static let scaleFactor = 65536.0
    private let reportBuffer: UnsafeMutablePointer<UInt8>
    private var rawLogCount = 0

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

        // Wake the sensor by setting properties on AppleSPUHIDDriver nodes (NOT the device).
        // Reference: macimu/_spu.py — the driver node is what powers the sensor; the device
        // node only exposes the HID interface. Setting properties on the device is silently ignored.
        wakeSPUDrivers()

        // Find AppleSPUHIDDevice directly — bypasses IOHIDManager which skips RegisterService=No devices
        let matching = IOServiceMatching("AppleSPUHIDDevice")
        var iterator: io_iterator_t = 0
        let kr = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard kr == kIOReturnSuccess else {
            fputs("[accelerometer] IOServiceGetMatchingServices failed: \(kr)\n", stderr)
            return false
        }
        defer { IOObjectRelease(iterator) }

        // Find the accelerometer service (usage page 0xFF00, usage 0x03)
        var accelService: io_service_t = 0
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let pairs = IORegistryEntryCreateCFProperty(service, "DeviceUsagePairs" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [[String: Any]] {
                let isAccel = pairs.contains {
                    ($0["DeviceUsagePage"] as? Int) == 0xFF00 && ($0["DeviceUsage"] as? Int) == 0x03
                }
                if isAccel {
                    accelService = service
                    break
                }
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        guard accelService != 0 else {
            fputs("[accelerometer] No AppleSPUHIDDevice with usage 0xFF00/0x03 found.\n", stderr)
            return false
        }
        defer { IOObjectRelease(accelService) }

        // Create IOHIDDevice from the service
        guard let hidDevice = IOHIDDeviceCreate(kCFAllocatorDefault, accelService) else {
            fputs("[accelerometer] IOHIDDeviceCreate failed.\n", stderr)
            return false
        }
        self.device = hidDevice

        // Open with flags=0 (NOT kIOHIDOptionsTypeSeizeDevice — that requires root and kills callbacks)
        let openResult = IOHIDDeviceOpen(hidDevice, IOOptionBits(0))
        guard openResult == kIOReturnSuccess else {
            fputs("[accelerometer] IOHIDDeviceOpen failed: \(openResult)\n", stderr)
            return false
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(
            hidDevice,
            reportBuffer,
            Self.reportBufferLength,
            inputReportCallback,
            selfPtr
        )

        IOHIDDeviceScheduleWithRunLoop(hidDevice, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

        fputs("[accelerometer] Connected to AppleSPUHIDDevice (accelerometer).\n", stderr)
        return true
    }

    func stop() {
        if let device {
            IOHIDDeviceUnscheduleFromRunLoop(device, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDDeviceClose(device, IOOptionBits(0))
        }
        device = nil
        callback = nil
    }

    func handleReport(_ report: UnsafeMutablePointer<UInt8>, length: CFIndex) {
        guard length >= 18 else { return }

        let buffer = UnsafeBufferPointer(start: report, count: length)

        if rawLogCount < 5 {
            rawLogCount += 1
            let hex = (0..<length).map { String(format: "%02x", buffer[$0]) }.joined(separator: " ")
            fputs("[report \(rawLogCount)] len=\(length): \(hex)\n", stderr)
        }

        guard let x = readInt32LE(buffer, offset: Self.xOffset),
              let y = readInt32LE(buffer, offset: Self.yOffset),
              let z = readInt32LE(buffer, offset: Self.zOffset) else { return }

        let reading = AccelerometerReading(
            x: Double(x) / Self.scaleFactor,
            y: Double(y) / Self.scaleFactor,
            z: Double(z) / Self.scaleFactor,
            timestamp: ProcessInfo.processInfo.systemUptime
        )
        self.callback?(reading)
    }

    private func wakeSPUDrivers() {
        let matching = IOServiceMatching("AppleSPUHIDDriver")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess else {
            fputs("[accelerometer] No AppleSPUHIDDriver found to wake.\n", stderr)
            return
        }
        defer { IOObjectRelease(iterator) }

        let wakeProps: [(String, Int32)] = [
            ("SensorPropertyReportingState", 1),
            ("SensorPropertyPowerState", 1),
            ("ReportInterval", 1000),
        ]

        var count = 0
        var driver = IOIteratorNext(iterator)
        while driver != 0 {
            for (key, value) in wakeProps {
                IORegistryEntrySetCFProperty(driver, key as CFString, NSNumber(value: value))
            }
            IOObjectRelease(driver)
            count += 1
            driver = IOIteratorNext(iterator)
        }
        fputs("[accelerometer] Woke \(count) AppleSPUHIDDriver node(s).\n", stderr)
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
