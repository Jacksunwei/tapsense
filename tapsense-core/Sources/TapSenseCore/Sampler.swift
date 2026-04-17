import Foundation

public class Sampler {
    private let targetFs: Double
    private let step: Double
    private var buffer: [AccelerometerReading] = []
    private var nextSyntheticTime: Double?
    
    public init(targetFs: Double = 200.0) {
        self.targetFs = targetFs
        self.step = 1.0 / targetFs
    }
    
    /// Adds a raw reading and returns any newly available resampled points.
    public func addReading(_ reading: AccelerometerReading) -> [AccelerometerReading] {
        buffer.append(reading)
        
        // Need at least 2 readings to interpolate
        guard buffer.count >= 2 else { return [] }
        
        if nextSyntheticTime == nil {
            nextSyntheticTime = buffer.first!.timestamp
        }
        
        var resampledPoints: [AccelerometerReading] = []
        
        while let nextTime = nextSyntheticTime {
            // Find the first sample that is strictly after nextTime
            guard let afterIdx = buffer.firstIndex(where: { $0.timestamp > nextTime }) else {
                // We don't have a sample after nextTime yet. Wait for more data.
                break
            }
            
            if afterIdx == 0 {
                nextSyntheticTime! += step
                continue
            }
            
            let r1 = buffer[afterIdx - 1]
            let r2 = buffer[afterIdx]
            
            let dt = r2.timestamp - r1.timestamp
            let fraction = (nextTime - r1.timestamp) / dt
            
            let x = r1.x + (r2.x - r1.x) * fraction
            let y = r1.y + (r2.y - r1.y) * fraction
            let z = r1.z + (r2.z - r1.z) * fraction
            
            resampledPoints.append(AccelerometerReading(x: x, y: y, z: z, timestamp: nextTime))
            
            nextSyntheticTime! += step
            
            // Clean up buffer: we can remove samples that are before the new r1,
            // because any future nextTime will be >= the current nextTime.
            if afterIdx > 1 {
                buffer.removeFirst(afterIdx - 1)
            }
        }
        
        return resampledPoints
    }
}
