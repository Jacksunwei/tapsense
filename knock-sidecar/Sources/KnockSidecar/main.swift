import Foundation

struct SidecarOptions {
    let simulate: Bool
    let mode: KnockMode
    let sensitivity: KnockSensitivity
}

func emitJSON(_ dict: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: dict),
          let str = String(data: data, encoding: .utf8) else { return }
    print(str)
    fflush(stdout)
}

func parseOptions(arguments: [String]) -> SidecarOptions {
    var simulate = false
    var mode: KnockMode = .palmRest
    var sensitivity: KnockSensitivity = .medium

    var index = 1
    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--simulate":
            simulate = true
        case "--mode":
            if index + 1 < arguments.count,
               let parsed = KnockMode(rawValue: arguments[index + 1]) {
                mode = parsed
                index += 1
            }
        case "--sensitivity":
            if index + 1 < arguments.count,
               let parsed = KnockSensitivity(rawValue: arguments[index + 1]) {
                sensitivity = parsed
                index += 1
            }
        default:
            break
        }
        index += 1
    }

    return SidecarOptions(simulate: simulate, mode: mode, sensitivity: sensitivity)
}

let options = parseOptions(arguments: CommandLine.arguments)
let profile = ProfileFactory.make(mode: options.mode, sensitivity: options.sensitivity)

let source: AccelerometerSource
if options.simulate {
    source = SimulatedAccelerometer()
} else {
    source = IOKitAccelerometer()
}

let detector = KnockDetector(profile: profile)

let started = source.start { reading in
    if let event = detector.process(reading) {
        emitJSON([
            "type": "knock_pattern",
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
    "profile": options.mode.rawValue,
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

dispatchMain()
