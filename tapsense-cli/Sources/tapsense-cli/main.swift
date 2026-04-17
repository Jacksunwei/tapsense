import Foundation
import TapSenseCore
import CoreML

let arguments = CommandLine.arguments

if arguments.contains("--help") || arguments.count < 2 {
    print("Usage: tapsense-cli [mode]")
    print("Modes:")
    print("  --collect [pattern] : Start data collection (default pattern: single)")
    print("  --test-model <path> : Test a trained model (.mlpackage or .mlmodel)")
    exit(0)
}

if arguments.contains("--collect") {
    let patternIdx = arguments.firstIndex(of: "--collect")!
    let pattern = patternIdx + 1 < arguments.count ? arguments[patternIdx + 1] : "single"
    runDataCollection(pattern: pattern)
} else if let modelIdx = arguments.firstIndex(of: "--test-model"), modelIdx + 1 < arguments.count {
    let modelPath = arguments[modelIdx + 1]
    runModelTest(modelPath: modelPath)
} else {
    print("Invalid arguments. Use --help for usage.")
}

func runDataCollection(pattern: String) {
    print("TapSense CLI - Data Collection Mode")
    
    let sampler = Sampler(targetFs: 200.0)
    let detector = TapDetector()
    let accelerometer = IOKitAccelerometer()

    var sampleBuffer: [AccelerometerReading] = []
    let maxBufferSize = 400 // 2 seconds at 200Hz

    let outputFileName = "tapsense-data/raw/desk_\(pattern)_tap.jsonl"

    print("Starting data collection for pattern: \(pattern)")
    print("File will be saved to: \(outputFileName)")
    print("Press Ctrl+C to stop.")

    print("\n[READY] Please tap your desk when prompted...")

    let success = accelerometer.start { rawReading in
        let resampled = sampler.addReading(rawReading)
        
        for reading in resampled {
            sampleBuffer.append(reading)
            if sampleBuffer.count > maxBufferSize {
                sampleBuffer.removeFirst()
            }
            
            if let event = detector.process(reading) {
                print("\n[DETECTED] Heuristic triggered: \(event.pattern) tap!")
                
                let windowSize = 200
                if sampleBuffer.count >= windowSize {
                    let window = Array(sampleBuffer.suffix(windowSize))
                    saveData(window, label: event.pattern, to: outputFileName)
                    print("[SAVED] Window recorded to \(outputFileName)")
                    print("\n[READY] Tap again...")
                }
            }
        }
    }

    guard success else {
        print("Failed to start accelerometer. Run with sudo?")
        exit(1)
    }

    CFRunLoopRun()
}

func runModelTest(modelPath: String) {
    print("TapSense CLI - Model Test Mode")
    print("Loading model from: \(modelPath)")
    
    let modelURL = URL(fileURLWithPath: modelPath)
    
    do {
        print("Compiling model at runtime...")
        let compiledURL = try MLModel.compileModel(at: modelURL)
        print("Model compiled to: \(compiledURL.path)")
        
        let classifier = try TapClassifier(contentsOf: compiledURL)
        print("Classifier initialized successfully!")
        
        let sampler = Sampler(targetFs: 200.0)
        let detector = TapDetector() // Use heuristics to trigger test windows
        let accelerometer = IOKitAccelerometer()
        
        var sampleBuffer: [AccelerometerReading] = []
        let maxBufferSize = 400
        
        print("Starting live test. Please tap your desk...")
        
        let success = accelerometer.start { rawReading in
            let resampled = sampler.addReading(rawReading)
            
            for reading in resampled {
                sampleBuffer.append(reading)
                if sampleBuffer.count > maxBufferSize {
                    sampleBuffer.removeFirst()
                }
                
                if let event = detector.process(reading) {
                    print("\n[CANDIDATE] Heuristic triggered: \(event.pattern)")
                    
                    let windowSize = 200
                    if sampleBuffer.count >= windowSize {
                        let window = Array(sampleBuffer.suffix(windowSize))
                        
                        let x = window.map { Float($0.x) }
                        let y = window.map { Float($0.y) }
                        let z = window.map { Float($0.z) }
                        let resampledData = [x, y, z]
                        
                        if let prediction = classifier.classify(resampledData: resampledData) {
                            print("[PREDICTION] ML Model says: \(prediction) tap!")
                        } else {
                            print("[PREDICTION] ML Model failed to classify.")
                        }
                    }
                }
            }
        }
        
        guard success else {
            print("Failed to start accelerometer. Run with sudo?")
            return
        }
        
        CFRunLoopRun()
        
    } catch {
        print("Error: \(error)")
    }
}

func saveData(_ window: [AccelerometerReading], label: String, to fileName: String) {
    let data = ["label": label, "samples": window.map { ["x": $0.x, "y": $0.y, "z": $0.z, "t": $0.timestamp] }] as [String : Any]
    
    guard let jsonData = try? JSONSerialization.data(withJSONObject: data, options: []),
          let jsonString = String(data: jsonData, encoding: .utf8) else {
        print("Failed to serialize data")
        return
    }
    
    let fileURL = URL(fileURLWithPath: fileName)
    let line = jsonString + "\n"
    
    if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
        fileHandle.seekToEndOfFile()
        fileHandle.write(line.data(using: .utf8)!)
        fileHandle.closeFile()
    } else {
        try? line.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}


