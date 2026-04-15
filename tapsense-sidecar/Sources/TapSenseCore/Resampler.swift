import Foundation

public struct Resampler {
    /// Resamples a slice of AccelerometerReadings to a target frequency and window duration.
    /// Returns a 2D array of shape (3, 200) containing the resampled X, Y, Z values.
    public static func resample(
        readings: [AccelerometerReading],
        targetFs: Double = 200.0,
        windowDuration: Double = 1.0
    ) -> [[Float]]? {
        guard readings.count >= 2 else { return nil }
        
        let targetSamples = Int(targetFs * windowDuration) // 200
        let startTime = readings.first!.timestamp
        let endTime = readings.last!.timestamp
        let duration = endTime - startTime
        
        guard duration > 0 else { return nil }
        
        var resampledX = [Float](repeating: 0, count: targetSamples)
        var resampledY = [Float](repeating: 0, count: targetSamples)
        var resampledZ = [Float](repeating: 0, count: targetSamples)
        
        let step = duration / Double(targetSamples - 1)
        
        var readIdx = 0
        
        for i in 0..<targetSamples {
            let t = startTime + Double(i) * step
            
            // Advance readIdx until t is between readIdx and readIdx + 1
            while readIdx < readings.count - 1 && readings[readIdx + 1].timestamp < t {
                readIdx += 1
            }
            
            if readIdx >= readings.count - 1 {
                // Fallback to last value if we overshoot slightly due to rounding
                resampledX[i] = Float(readings.last!.x)
                resampledY[i] = Float(readings.last!.y)
                resampledZ[i] = Float(readings.last!.z)
                continue
            }
            
            let r1 = readings[readIdx]
            let r2 = readings[readIdx + 1]
            
            let dt = r2.timestamp - r1.timestamp
            let fraction = (t - r1.timestamp) / dt
            
            resampledX[i] = Float(r1.x + (r2.x - r1.x) * fraction)
            resampledY[i] = Float(r1.y + (r2.y - r1.y) * fraction)
            resampledZ[i] = Float(r1.z + (r2.z - r1.z) * fraction)
        }
        
        return [resampledX, resampledY, resampledZ]
    }
}
