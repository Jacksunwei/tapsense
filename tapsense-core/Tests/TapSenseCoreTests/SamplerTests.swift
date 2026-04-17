import XCTest
@testable import TapSenseCore

final class SamplerTests: XCTestCase {
    func testSampler200Hz() {
        let sampler = Sampler(targetFs: 200.0)
        
        // Simulate 100Hz input data
        var rawReadings: [AccelerometerReading] = []
        let startTime = ProcessInfo.processInfo.systemUptime
        for i in 0..<10 {
            let t = startTime + Double(i) * 0.01 // 100Hz
            rawReadings.append(AccelerometerReading(x: Double(i), y: Double(i), z: Double(i), timestamp: t))
        }
        
        var allResampled: [AccelerometerReading] = []
        for reading in rawReadings {
            let resampled = sampler.addReading(reading)
            allResampled.append(contentsOf: resampled)
        }
        
        // With 10 samples at 100Hz (0.09s duration), we should get around 18-20 samples at 200Hz.
        XCTAssertGreaterThan(allResampled.count, 0)
        
        // Verify spacing
        for i in 1..<allResampled.count {
            let dt = allResampled[i].timestamp - allResampled[i - 1].timestamp
            XCTAssertEqual(dt, 0.005, accuracy: 0.0001) // 200Hz implies 0.005s step
        }
    }
}
