import Foundation

enum TapSensitivity: String {
    case low
    case medium
    case high
}

struct DetectorProfile {
    let sensitivity: TapSensitivity
    let magnitudeThreshold: Double
    let minGapMs: Double
    let maxGapMs: Double
    let cooldownMs: Double
}

enum ProfileFactory {
    // Central tuning knob — calibrated on M-series MacBook Air palm rest.
    static let baseThreshold: Double = 0.02

    // low = harder to trigger (fewer false positives), high = easier to trigger.
    static let sensitivityMultiplier: [TapSensitivity: Double] = [
        .low: 1.25,
        .medium: 1.00,
        .high: 0.75,
    ]

    static func make(sensitivity: TapSensitivity) -> DetectorProfile {
        let threshold = baseThreshold * (sensitivityMultiplier[sensitivity] ?? 1.0)

        let (minGap, maxGap, cooldown): (Double, Double, Double)
        switch sensitivity {
        case .low:    (minGap, maxGap, cooldown) = (120, 400, 1000)
        case .medium: (minGap, maxGap, cooldown) = (110, 450, 900)
        case .high:   (minGap, maxGap, cooldown) = (100, 500, 850)
        }

        return DetectorProfile(
            sensitivity: sensitivity,
            magnitudeThreshold: threshold,
            minGapMs: minGap,
            maxGapMs: maxGap,
            cooldownMs: cooldown
        )
    }
}
