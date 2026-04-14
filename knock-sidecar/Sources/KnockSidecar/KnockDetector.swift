import Foundation

final class KnockDetector {
    private let magnitudeThreshold: Double
    private let maxGapMs: Double
    private let minGapMs: Double
    private let cooldownMs: Double

    private var lastKnockTime: TimeInterval = 0
    private var waitingForSecond = false
    private var lastEmitTime: TimeInterval = 0

    init(
        magnitudeThreshold: Double = 2.0,
        minGapMs: Double = 50,
        maxGapMs: Double = 400,
        cooldownMs: Double = 1000
    ) {
        self.magnitudeThreshold = magnitudeThreshold
        self.minGapMs = minGapMs
        self.maxGapMs = maxGapMs
        self.cooldownMs = cooldownMs
    }

    func process(_ reading: AccelerometerReading) -> Bool {
        let magnitude = sqrt(reading.x * reading.x + reading.y * reading.y + reading.z * reading.z)

        guard magnitude > magnitudeThreshold else {
            if waitingForSecond {
                let elapsed = (reading.timestamp - lastKnockTime) * 1000
                if elapsed > maxGapMs {
                    waitingForSecond = false
                }
            }
            return false
        }

        let now = reading.timestamp

        if !waitingForSecond {
            lastKnockTime = now
            waitingForSecond = true
            return false
        }

        let gapMs = (now - lastKnockTime) * 1000

        guard gapMs >= minGapMs && gapMs <= maxGapMs else {
            lastKnockTime = now
            return false
        }

        let sinceLast = (now - lastEmitTime) * 1000
        guard sinceLast >= cooldownMs else {
            waitingForSecond = false
            return false
        }

        waitingForSecond = false
        lastEmitTime = now
        return true
    }
}
