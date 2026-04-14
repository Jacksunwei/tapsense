import Foundation

struct KnockEvent {
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

final class KnockDetector {
    private let magnitudeThreshold: Double
    private let maxGapMs: Double
    private let minGapMs: Double
    private let cooldownMs: Double
    private let maxKnocksPerPattern: Int
    private let confirmSamples: Int
    private let releaseRatio: Double

    private var knockTimes: [TimeInterval] = []
    private var lastEmitTime: TimeInterval = 0

    // High-pass filter state (per-axis gravity removal)
    private let gravityAlpha: Double = 0.95
    private var gravityX: Double = 0
    private var gravityY: Double = 0
    private var gravityZ: Double = 0
    private var gravityInitialized = false

    // Peak confirmation state
    private var consecutiveAbove: Int = 0
    private var knockFired: Bool = false

    init(
        magnitudeThreshold: Double = 0.5,
        minGapMs: Double = 50,
        maxGapMs: Double = 400,
        cooldownMs: Double = 1000,
        maxKnocksPerPattern: Int = 3,
        confirmSamples: Int = 2,
        releaseRatio: Double = 0.5
    ) {
        self.magnitudeThreshold = magnitudeThreshold
        self.minGapMs = minGapMs
        self.maxGapMs = maxGapMs
        self.cooldownMs = cooldownMs
        self.maxKnocksPerPattern = maxKnocksPerPattern
        self.confirmSamples = confirmSamples
        self.releaseRatio = releaseRatio
        self.lastEmitTime = -(cooldownMs / 1000)
    }

    convenience init(profile: DetectorProfile, maxKnocksPerPattern: Int = 3) {
        self.init(
            magnitudeThreshold: profile.magnitudeThreshold,
            minGapMs: profile.minGapMs,
            maxGapMs: profile.maxGapMs,
            cooldownMs: profile.cooldownMs,
            maxKnocksPerPattern: maxKnocksPerPattern
        )
    }

    func process(_ reading: AccelerometerReading) -> KnockEvent? {
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
            knockFired = false
            return nil
        } else {
            return nil
        }

        guard consecutiveAbove >= confirmSamples && !knockFired else {
            return nil
        }

        knockFired = true
        return registerKnock(at: now)
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

    private func finalizeIfTimedOut(now: TimeInterval) -> KnockEvent? {
        guard let lastKnockTime = knockTimes.last else {
            return nil
        }

        let elapsedMs = (now - lastKnockTime) * 1000
        guard elapsedMs > maxGapMs else {
            return nil
        }

        return emitCurrentPattern(timestamp: lastKnockTime)
    }

    private func registerKnock(at now: TimeInterval) -> KnockEvent? {
        let sinceLastEmitMs = (now - lastEmitTime) * 1000
        if knockTimes.isEmpty && sinceLastEmitMs < cooldownMs {
            return nil
        }

        if let previous = knockTimes.last {
            let gapMs = (now - previous) * 1000

            if gapMs < minGapMs {
                return nil
            }

            if gapMs > maxGapMs {
                let event = emitCurrentPattern(timestamp: previous)
                knockTimes = [now]
                return event
            }
        }

        knockTimes.append(now)

        if knockTimes.count >= maxKnocksPerPattern {
            return emitCurrentPattern(timestamp: now)
        }

        return nil
    }

    private func emitCurrentPattern(timestamp: TimeInterval) -> KnockEvent? {
        guard !knockTimes.isEmpty else {
            return nil
        }

        let count = min(knockTimes.count, maxKnocksPerPattern)
        knockTimes.removeAll(keepingCapacity: true)
        lastEmitTime = timestamp
        return KnockEvent(count: count, timestamp: timestamp)
    }
}
