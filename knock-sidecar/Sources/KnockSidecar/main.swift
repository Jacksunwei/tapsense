import Foundation

func emitJSON(_ dict: [String: Any]) {
    guard let data = try? JSONSerialization.data(withJSONObject: dict),
          let str = String(data: data, encoding: .utf8) else { return }
    print(str)
    fflush(stdout)
}

let args = CommandLine.arguments
let simulate = args.contains("--simulate")

let source: AccelerometerSource
if simulate {
    source = SimulatedAccelerometer()
} else {
    let real = IOKitAccelerometer()
    source = real
}

let detector = KnockDetector()

let started = source.start { reading in
    let detected = detector.process(reading)
    if detected {
        emitJSON([
            "type": "double_knock",
            "timestamp": reading.timestamp,
        ])
    }
}

if !started {
    fputs("[sidecar] Failed to start accelerometer source. Try --simulate.\n", stderr)
    emitJSON(["type": "error", "message": "Failed to start accelerometer. Use --simulate mode."])
    exit(1)
}

emitJSON(["type": "started", "mode": simulate ? "simulate" : "real"])

signal(SIGINT, SIG_IGN)
let sigintSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigintSource.setEventHandler {
    source.stop()
    emitJSON(["type": "stopped"])
    exit(0)
}
sigintSource.resume()

dispatchMain()
