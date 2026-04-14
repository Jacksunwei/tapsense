import Foundation

final class SimulatedAccelerometer: AccelerometerSource {
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "accelerometer.simulate")

    private var tickCount = 0
    private let knockIntervalTicks = 300
    private let knockDuration = 3

    func start(callback: @escaping (AccelerometerReading) -> Void) -> Bool {
        fputs("[simulator] Running in simulation mode. Generating double-knock every ~6 seconds.\n", stderr)

        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: .milliseconds(10))
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let reading = self.generateReading()
            callback(reading)
        }
        source.resume()
        self.timer = source
        return true
    }

    private func generateReading() -> AccelerometerReading {
        tickCount += 1
        let cycle = tickCount % knockIntervalTicks

        var x = 0.0, y = 0.0, z = 1.0

        // First knock: spike at tick 0..knockDuration
        if cycle < knockDuration {
            z += 2.5
        }
        // Second knock: spike at tick 15..15+knockDuration (~150ms later)
        if cycle >= 15 && cycle < 15 + knockDuration {
            z += 2.5
        }

        // Add minor noise
        x += Double.random(in: -0.02...0.02)
        y += Double.random(in: -0.02...0.02)
        z += Double.random(in: -0.02...0.02)

        return AccelerometerReading(
            x: x, y: y, z: z,
            timestamp: ProcessInfo.processInfo.systemUptime
        )
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }
}
