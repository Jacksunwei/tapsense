import Foundation

enum KnockMode: String {
    case palmRest
    case desk
}

enum KnockSensitivity: String {
    case low
    case medium
    case high
}

struct DetectorProfile {
    let mode: KnockMode
    let sensitivity: KnockSensitivity
    let magnitudeThreshold: Double
    let minGapMs: Double
    let maxGapMs: Double
    let cooldownMs: Double
}

enum ProfileFactory {
    static func make(mode: KnockMode, sensitivity: KnockSensitivity) -> DetectorProfile {
        switch (mode, sensitivity) {
        case (.palmRest, .low):
            return DetectorProfile(mode: mode, sensitivity: sensitivity, magnitudeThreshold: 1.2, minGapMs: 70, maxGapMs: 280, cooldownMs: 1000)
        case (.palmRest, .medium):
            return DetectorProfile(mode: mode, sensitivity: sensitivity, magnitudeThreshold: 0.9, minGapMs: 60, maxGapMs: 320, cooldownMs: 900)
        case (.palmRest, .high):
            return DetectorProfile(mode: mode, sensitivity: sensitivity, magnitudeThreshold: 0.6, minGapMs: 50, maxGapMs: 340, cooldownMs: 850)
        case (.desk, .low):
            return DetectorProfile(mode: mode, sensitivity: sensitivity, magnitudeThreshold: 1.0, minGapMs: 90, maxGapMs: 360, cooldownMs: 1200)
        case (.desk, .medium):
            return DetectorProfile(mode: mode, sensitivity: sensitivity, magnitudeThreshold: 0.8, minGapMs: 80, maxGapMs: 380, cooldownMs: 1100)
        case (.desk, .high):
            return DetectorProfile(mode: mode, sensitivity: sensitivity, magnitudeThreshold: 0.5, minGapMs: 70, maxGapMs: 400, cooldownMs: 1000)
        }
    }
}
