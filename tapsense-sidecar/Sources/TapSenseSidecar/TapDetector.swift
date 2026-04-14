import Foundation

struct TapEvent {
    let count: Int
    let timestamp: TimeInterval

    var pattern: String {
        switch count {
        case 1:
            return "single"
        case 2:
            return "double"
        default:
            return "triple"
        }
    }
}

final class TapDetector {
    private let magnitudeThreshold: Double
    private let maxGapMs: Double
    private let minGapMs: Double
    private let cooldownMs: Double
    private let maxTapsPerPattern: Int
    private let confirmSamples: Int
    private let releaseRatio: Double

    private var tapTimes: [TimeInterval] = []
    private var lastEmitTime: TimeInterval = 0

    // High-pass filter state (per-axis gravity removal)
    private let gravityAlpha: Double = 0.95
    private var gravityX: Double = 0
    private var gravityY: Double = 0
    private var gravityZ: Double = 0
    private var gravityInitialized = false

    // Peak confirmation state
    private var consecutiveAbove: Int = 0
    private var tapFired: Bool = false

    init(
        magnitudeThreshold: Double = 0.5,
        minGapMs: Double = 50,
        maxGapMs: Double = 400,
        cooldownMs: Double = 1000,
        maxTapsPerPattern: Int = 3,
        confirmSamples: Int = 2,
        releaseRatio: Double = 0.5
    ) {
        self.magnitudeThreshold = magnitudeThreshold
        self.minGapMs = minGapMs
        self.maxGapMs = maxGapMs
        self.cooldownMs = cooldownMs
        self.maxTapsPerPattern = maxTapsPerPattern
        self.confirmSamples = confirmSamples
        self.releaseRatio = releaseRatio
        self.lastEmitTime = -(cooldownMs / 1000)
    }

    convenience init(profile: DetectorProfile, maxTapsPerPattern: Int = 3) {
        self.init(
            magnitudeThreshold: profile.magnitudeThreshold,
            minGapMs: profile.minGapMs,
            maxGapMs: profile.maxGapMs,
            cooldownMs: profile.cooldownMs,
            maxTapsPerPattern: maxTapsPerPattern
        )
    }

    func process(_ reading: AccelerometerReading) -> TapEvent? {
        let now = reading.timestamp

        if let event = finalizeIfTimedOut(now: now) {
            return event
        }

        let magnitude = filteredMagnitude(reading)
        let releaseThreshold = magnitudeThreshold * releaseRatio

        if magnitude > magnitudeThreshold {
            consecutiveAbove += 1
        } else if magnitude < releaseThreshold {
            consecutiveAbove = 0
            tapFired = false
            return nil
        } else {
            return nil
        }

        guard consecutiveAbove >= confirmSamples && !tapFired else {
            return nil
        }

        tapFired = true
        return registerTap(at: now)
    }

    private func filteredMagnitude(_ reading: AccelerometerReading) -> Double {
        if !gravityInitialized {
            gravityX = reading.x
            gravityY = reading.y
            gravityZ = reading.z
            gravityInitialized = true
            return 0
        }

        gravityX = gravityAlpha * gravityX + (1 - gravityAlpha) * reading.x
        gravityY = gravityAlpha * gravityY + (1 - gravityAlpha) * reading.y
        gravityZ = gravityAlpha * gravityZ + (1 - gravityAlpha) * reading.z

        let ax = reading.x - gravityX
        let ay = reading.y - gravityY
        let az = reading.z - gravityZ

        return sqrt(ax * ax + ay * ay + az * az)
    }

    private func finalizeIfTimedOut(now: TimeInterval) -> TapEvent? {
        guard let lastTapTime = tapTimes.last else {
            return nil
        }

        let elapsedMs = (now - lastTapTime) * 1000
        guard elapsedMs > maxGapMs else {
            return nil
        }

        return emitCurrentPattern(timestamp: lastTapTime)
    }

    private func registerTap(at now: TimeInterval) -> TapEvent? {
        let sinceLastEmitMs = (now - lastEmitTime) * 1000
        if tapTimes.isEmpty && sinceLastEmitMs < cooldownMs {
            return nil
        }

        if let previous = tapTimes.last {
            let gapMs = (now - previous) * 1000

            if gapMs < minGapMs {
                return nil
            }

            if gapMs > maxGapMs {
                let event = emitCurrentPattern(timestamp: previous)
                tapTimes = [now]
                return event
            }
        }

        tapTimes.append(now)

        if tapTimes.count >= maxTapsPerPattern {
            return emitCurrentPattern(timestamp: now)
        }

        return nil
    }

    private func emitCurrentPattern(timestamp: TimeInterval) -> TapEvent? {
        guard !tapTimes.isEmpty else {
            return nil
        }

        let count = min(tapTimes.count, maxTapsPerPattern)
        tapTimes.removeAll(keepingCapacity: true)
        lastEmitTime = timestamp
        return TapEvent(count: count, timestamp: timestamp)
    }
}
