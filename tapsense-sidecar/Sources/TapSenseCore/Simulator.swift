import Foundation

public final class SimulatedAccelerometer: AccelerometerSource {
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "accelerometer.simulate")

    private var tickCount = 0
    private let cycleLength = 540
    private let tapDuration = 3
    private let patternOffsets: [[Int]] = [
        [0],
        [0, 15],
        [0, 15, 30],
    ]

    public init() {}

    public func start(callback: @escaping (AccelerometerReading) -> Void) -> Bool {
        fputs("[simulator] Running in simulation mode. Cycling single, double, and triple tap patterns.\n", stderr)

        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: .milliseconds(10))
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let reading = self.generateReading()
            DispatchQueue.main.async {
                callback(reading)
            }
        }
        source.resume()
        self.timer = source
        return true
    }

    private func generateReading() -> AccelerometerReading {
        tickCount += 1
        let cycle = tickCount % cycleLength
        let phaseLength = cycleLength / patternOffsets.count
        let phaseIndex = min(cycle / phaseLength, patternOffsets.count - 1)
        let phaseTick = cycle % phaseLength
        let activePattern = patternOffsets[phaseIndex]

        var x = 0.0, y = 0.0, z = 1.0

        for offset in activePattern where phaseTick >= offset && phaseTick < offset + tapDuration {
            z += 2.5
        }

        x += Double.random(in: -0.02...0.02)
        y += Double.random(in: -0.02...0.02)
        z += Double.random(in: -0.02...0.02)

        return AccelerometerReading(
            x: x, y: y, z: z,
            timestamp: Double(tickCount) * 0.01
        )
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }
}
