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

    private var knockTimes: [TimeInterval] = []
    private var lastEmitTime: TimeInterval = 0
    private var isAboveThreshold = false

    init(
        magnitudeThreshold: Double = 2.0,
        minGapMs: Double = 50,
        maxGapMs: Double = 400,
        cooldownMs: Double = 1000,
        maxKnocksPerPattern: Int = 3
    ) {
        self.magnitudeThreshold = magnitudeThreshold
        self.minGapMs = minGapMs
        self.maxGapMs = maxGapMs
        self.cooldownMs = cooldownMs
        self.maxKnocksPerPattern = maxKnocksPerPattern
        self.lastEmitTime = -(cooldownMs / 1000)
    }

    func process(_ reading: AccelerometerReading) -> KnockEvent? {
        let now = reading.timestamp

        if let event = finalizeIfTimedOut(now: now) {
            return event
        }

        let magnitude = sqrt(reading.x * reading.x + reading.y * reading.y + reading.z * reading.z)
        let isCurrentlyAbove = magnitude > magnitudeThreshold

        defer { isAboveThreshold = isCurrentlyAbove }

        guard isCurrentlyAbove else {
            return nil
        }

        guard !isAboveThreshold else {
            return nil
        }

        return registerKnock(at: now)
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
