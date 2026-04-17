import Foundation

public final class MLTapDetector {
    private let detector: TapDetector
    private let classifier: TapClassifier?
    private var readingsBuffer: [AccelerometerReading] = []
    private let maxBufferSize = 2000 // Keep 2 seconds of data to be safe
    
    public init(profile: DetectorProfile) {
        self.detector = TapDetector(profile: profile)
        do {
            self.classifier = try TapClassifier()
        } catch {
            fputs("[MLTapDetector] Failed to load classifier: \(error)\n", stderr)
            self.classifier = nil
        }
    }
    
    public func process(_ reading: AccelerometerReading) -> TapEvent? {
        // Add to buffer
        readingsBuffer.append(reading)
        if readingsBuffer.count > maxBufferSize {
            readingsBuffer.removeFirst()
        }
        
        // Use heuristic to detect peak
        let event = detector.process(reading)
        
        // If heuristic detected a tap, we use ML to classify it
        if let heuristicEvent = event {
            guard let classifier = classifier else {
                // Fallback to heuristic if ML is not available
                return heuristicEvent
            }
            
            fputs("[MLTapDetector] Heuristic triggered! Running ML classification...\n", stderr)
            
            // Extract window of 1 second ending at current time
            // Since heuristic confirms a tap slightly after the peak, this window should contain the peak.
            let now = reading.timestamp
            let startTime = now - 1.0
            let windowReadings = readingsBuffer.filter { $0.timestamp >= startTime }
            
            if windowReadings.count >= 2 {
                if let resampled = Resampler.resample(readings: windowReadings) {
                    if let label = classifier.classify(resampledData: resampled) {
                        fputs("[MLTapDetector] ML Result: \(label)\n", stderr)
                        
                        switch label {
                        case "single_tap":
                            return TapEvent(count: 1, timestamp: now)
                        case "double_tap":
                            return TapEvent(count: 2, timestamp: now)
                        case "no_tap":
                            fputs("[MLTapDetector] ML rejected false trigger.\n", stderr)
                            return nil
                        default:
                            return nil
                        }
                    }
                }
            }
            
            // Fallback to heuristic if ML failed to classify
            return heuristicEvent
        }
        
        return nil
    }
}
