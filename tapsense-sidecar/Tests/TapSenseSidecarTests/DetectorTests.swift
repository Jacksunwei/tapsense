import XCTest
@testable import TapSenseSidecar

final class DetectorTests: XCTestCase {
    func testSingleTapDetection() {
        let detector = TapDetector(
            magnitudeThreshold: 0.5,
            minGapMs: 50,
            maxGapMs: 400,
            cooldownMs: 500,
            maxTapsPerPattern: 3,
            confirmSamples: 2,
            releaseRatio: 0.5
        )
        
        var timestamp: TimeInterval = 100.0
        let dt: TimeInterval = 0.01 // 10ms (100Hz)
        
        // 1. Resting state (near zero after gravity filter)
        for _ in 0..<10 {
            timestamp += dt
            let event = detector.process(AccelerometerReading(x: 0, y: 0, z: 1.0, timestamp: timestamp))
            XCTAssertNil(event)
        }
        
        // 2. Tap start (above threshold)
        // Need to account for gravity filter α=0.95 initialization.
        // After first reading, gravity initializes to 1.0 on Z.
        // So subsequent 1.0 readings will produce 0.0 magnitude.
        
        // Simulate a sharp impulse on X
        for _ in 0..<3 {
            timestamp += dt
            let event = detector.process(AccelerometerReading(x: 1.5, y: 0, z: 1.0, timestamp: timestamp))
            XCTAssertNil(event, "Should not fire until falling edge")
        }
        
        // 3. Falling edge (back to rest)
        timestamp += dt
        let event = detector.process(AccelerometerReading(x: 0, y: 0, z: 1.0, timestamp: timestamp))
        
        // 4. Wait for gap timeout to finalize the pattern
        timestamp += 0.5 // exceed maxGapMs (400ms)
        let finalEvent = detector.process(AccelerometerReading(x: 0, y: 0, z: 1.0, timestamp: timestamp))
        
        XCTAssertNotNil(finalEvent)
        XCTAssertEqual(finalEvent?.count, 1)
        XCTAssertEqual(finalEvent?.pattern, "single")
    }
}
