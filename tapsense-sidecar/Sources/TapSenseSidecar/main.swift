import Foundation
import TapSenseCore

struct SidecarOptions {
    let simulate: Bool
    let sensitivity: TapSensitivity
    let thresholdOverride: Double?
    let keySuppressionMs: Double?
    let keyLookaheadMs: Double?
    let recordFile: String?
}

func emitJSON(_ dict: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: dict),
          let str = String(data: data, encoding: .utf8) else { return }
    print(str)
    fflush(stdout)
}

func parseOptions(arguments: [String]) -> SidecarOptions {
    var simulate = false
    var sensitivity: TapSensitivity = .medium
    var thresholdOverride: Double? = nil
    var keySuppressionMs: Double? = nil
    var keyLookaheadMs: Double? = nil
    var recordFile: String? = nil

    var index = 1
    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--simulate":
            simulate = true
        case "--record":
            if index + 1 < arguments.count {
                recordFile = arguments[index + 1]
                index += 1
            }
        case "--sensitivity":
            if index + 1 < arguments.count,
               let parsed = TapSensitivity(rawValue: arguments[index + 1]) {
                sensitivity = parsed
                index += 1
            }
        case "--threshold":
            if index + 1 < arguments.count, let parsed = Double(arguments[index + 1]) {
                thresholdOverride = parsed
                index += 1
            }
        case "--key-suppression":
            if index + 1 < arguments.count, let parsed = Double(arguments[index + 1]) {
                keySuppressionMs = parsed
                index += 1
            }
        case "--key-lookahead":
            if index + 1 < arguments.count, let parsed = Double(arguments[index + 1]) {
                keyLookaheadMs = parsed
                index += 1
            }
        default:
            break
        }
        index += 1
    }

    return SidecarOptions(simulate: simulate, sensitivity: sensitivity, thresholdOverride: thresholdOverride, keySuppressionMs: keySuppressionMs, keyLookaheadMs: keyLookaheadMs, recordFile: recordFile)
}

let options = parseOptions(arguments: CommandLine.arguments)
let baseProfile = ProfileFactory.make(sensitivity: options.sensitivity)
let profile: DetectorProfile
if let override = options.thresholdOverride {
    profile = DetectorProfile(
        sensitivity: baseProfile.sensitivity,
        magnitudeThreshold: override,
        minGapMs: baseProfile.minGapMs,
        maxGapMs: baseProfile.maxGapMs,
        cooldownMs: baseProfile.cooldownMs
    )
    fputs("[sidecar] Threshold override: \(override) g\n", stderr)
} else {
    profile = baseProfile
}

let source: AccelerometerSource
if options.simulate {
    source = SimulatedAccelerometer()
} else {
    source = IOKitAccelerometer()
}

let detector = TapDetector(profile: profile)

fputs(String(format: "[sidecar] sens=%@ threshold=%.3fg refractory=%.0fms maxGap=%.0fms\n",
             options.sensitivity.rawValue,
             profile.magnitudeThreshold, profile.minGapMs, profile.maxGapMs), stderr)

let keyMonitor = KeyMonitor()
let keyStarted = keyMonitor.start()
if !keyStarted {
    fputs("[sidecar] WARNING: keyboard monitor failed — typing will NOT be suppressed.\n", stderr)
}
let keySuppressionSec: TimeInterval = (options.keySuppressionMs ?? 200.0) / 1000.0
let keyLookaheadSec: TimeInterval = (options.keyLookaheadMs ?? 500.0) / 1000.0

let started = source.start { reading in
    let sinceKey = reading.timestamp - keyMonitor.lastKeyEventTime
    if sinceKey >= 0 && sinceKey < keySuppressionSec {
        return
    }
    guard let event = detector.process(reading) else { return }

    let detectedAt = event.timestamp
    let keyCountAtDetect = keyMonitor.eventCount
    let delayMs = Int(keyLookaheadSec * 1000)
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs)) {
        // If a new key event fired during the lookahead window, assume the tap was
        // typing vibration and suppress. Also check same-window keys that arrived
        // slightly after detection.
        if keyMonitor.eventCount > keyCountAtDetect {
            fputs("[sidecar] Suppressed tap (\(event.pattern)) — key event in lookahead window.\n", stderr)
            return
        }
        if keyMonitor.lastKeyEventTime > detectedAt - keySuppressionSec {
            fputs("[sidecar] Suppressed tap (\(event.pattern)) — recent key event.\n", stderr)
            return
        }
        emitJSON([
            "type": "tap_pattern",
            "pattern": event.pattern,
            "count": event.count,
            "timestamp": event.timestamp,
        ])
    }
}

if !started {
    fputs("[sidecar] Failed to start accelerometer source. Try --simulate.\n", stderr)
    emitJSON(["type": "error", "message": "Failed to start accelerometer. Use --simulate mode."])
    exit(1)
}

emitJSON([
    "type": "started",
    "mode": options.simulate ? "simulate" : "real",
    "sensitivity": options.sensitivity.rawValue,
])

signal(SIGINT, SIG_IGN)
let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigintSource.setEventHandler {
    source.stop()
    emitJSON(["type": "stopped"])
    exit(0)
}
sigintSource.resume()

RunLoop.main.run()
