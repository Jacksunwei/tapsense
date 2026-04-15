import Foundation

public struct TapEvent {
    public let count: Int
    public let timestamp: TimeInterval

    public var pattern: String {
        switch count {
        case 1: return "single"
        case 2: return "double"
        default: return "triple"
        }
    }

    public init(count: Int, timestamp: TimeInterval) {
        self.count = count
        self.timestamp = timestamp
    }
}

/// State machine:
///   IDLE  -- magnitude > threshold + confirmed N samples --> FIRE a tap, record timestamp,
///            enter REFRACTORY (ignore all input for `refractoryMs`)
///   REFRACTORY -- refractoryMs elapsed --> IDLE
///
/// Pattern emission: after each fired tap, wait `maxGapMs` for the next tap.
/// If no next tap arrives within that window, emit the accumulated count.
/// If `maxTapsPerPattern` taps accumulate, emit immediately.
public final class TapDetector {
    private let magnitudeThreshold: Double
    private let maxGapMs: Double
    private let refractoryMs: Double
    private let cooldownMs: Double
    private let maxTapsPerPattern: Int
    private let confirmSamples: Int

    private var tapCount: Int = 0
    private var firstTapTime: TimeInterval = 0
    private var lastTapTime: TimeInterval = 0
    private var lastEmitTime: TimeInterval = 0

    private let gravityAlpha: Double
    private var gravityX: Double = 0
    private var gravityY: Double = 0
    private var gravityZ: Double = 0
    private var gravityInitialized = false

    private var consecutiveAbove: Int = 0
    private var refractoryUntil: TimeInterval = 0
    private var armed: Bool = true  // false after firing until magnitude dips below release
    private var belowCount: Int = 0
    private let releaseRatio: Double
    private let releaseSamples: Int

    public init(
        magnitudeThreshold: Double = 0.20,
        minGapMs: Double = 60,
        maxGapMs: Double = 320,
        cooldownMs: Double = 900,
        maxTapsPerPattern: Int = 3,
        confirmSamples: Int = 2,
        gravityAlpha: Double = 0.95,
        releaseRatio: Double = 0.6,
        releaseSamples: Int = 3
    ) {
        self.magnitudeThreshold = magnitudeThreshold
        self.refractoryMs = minGapMs
        self.maxGapMs = maxGapMs
        self.cooldownMs = cooldownMs
        self.maxTapsPerPattern = maxTapsPerPattern
        self.confirmSamples = confirmSamples
        self.gravityAlpha = gravityAlpha
        self.releaseRatio = releaseRatio
        self.releaseSamples = releaseSamples
        self.lastEmitTime = -(cooldownMs / 1000)
    }

    public convenience init(profile: DetectorProfile, maxTapsPerPattern: Int = 3) {
        self.init(
            magnitudeThreshold: profile.magnitudeThreshold,
            minGapMs: profile.minGapMs,
            maxGapMs: profile.maxGapMs,
            cooldownMs: profile.cooldownMs,
            maxTapsPerPattern: maxTapsPerPattern
        )
    }

    public func process(_ reading: AccelerometerReading) -> TapEvent? {
        let now = reading.timestamp
        var timedOutEvent: TapEvent? = nil

        if tapCount > 0 && (now - lastTapTime) * 1000 > maxGapMs {
            fputs("[detector] Timeout! Emitting accumulated pattern.\n", stderr)
            timedOutEvent = emitPattern()
        }

        let magnitude = filteredMagnitude(reading)

        // Re-arming: after a tap fires, require N consecutive samples below release threshold
        // AND the refractory window to elapse before we can fire again.
        if !armed {
            if magnitude < magnitudeThreshold * releaseRatio {
                belowCount += 1
            } else {
                belowCount = 0
            }
            if belowCount >= releaseSamples && now >= refractoryUntil {
                armed = true
                belowCount = 0
                consecutiveAbove = 0
                fputs("[detector] Armed again.\n", stderr)
            }
            return timedOutEvent
        }

        if magnitude > magnitudeThreshold {
            consecutiveAbove += 1
            fputs("[detector] Above threshold (\(consecutiveAbove)/\(confirmSamples)): \(magnitude)\n", stderr)
        } else {
            consecutiveAbove = 0
            return timedOutEvent
        }

        guard consecutiveAbove >= confirmSamples else { return timedOutEvent }
        fputs("[detector] TAP CONFIRMED! Previous tapCount: \(tapCount)\n", stderr)
        consecutiveAbove = 0
        armed = false
        refractoryUntil = now + refractoryMs / 1000

        if tapCount == 0 {
            let sinceLastEmitMs = (now - lastEmitTime) * 1000
            if sinceLastEmitMs < cooldownMs { return timedOutEvent }
            firstTapTime = now
        }

        tapCount += 1
        lastTapTime = now

        if tapCount >= maxTapsPerPattern {
            return emitPattern()
        }
        return timedOutEvent
    }

    private func emitPattern() -> TapEvent? {
        guard tapCount > 0 else { return nil }
        let count = min(tapCount, maxTapsPerPattern)
        let ts = firstTapTime
        tapCount = 0
        lastEmitTime = lastTapTime
        let event = TapEvent(count: count, timestamp: ts)
        fputs("[detector] emitPattern: pattern=\(event.pattern) count=\(count)\n", stderr)
        return event
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
}
