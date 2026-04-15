import Foundation
import TapSenseCore

@main
struct DataCollector {
    static func main() {
        let arguments = CommandLine.arguments
        guard arguments.count > 1 else {
            print("Usage: sudo data-collector <output_file.jsonl>")
            return
        }
        let outputFile = arguments[1]
        
        print("Starting data collection. Writing to \(outputFile)")
        
        // Ensure file exists or create it
        if !FileManager.default.fileExists(atPath: outputFile) {
            FileManager.default.createFile(atPath: outputFile, contents: nil, attributes: nil)
        }
        
        guard let fileHandle = FileHandle(forWritingAtPath: outputFile) else {
            print("Failed to open file handle for \(outputFile)")
            return
        }
        
        // Move to the end of the file to append if it already exists
        fileHandle.seekToEndOfFile()
        
        let accelerometer = IOKitAccelerometer()
        
        // Use the standard medium profile to count taps for UI feedback
        let profile = ProfileFactory.make(sensitivity: .medium)
        let detector = TapDetector(profile: profile)
        
        var tapCount = 0
        var lastTapTime: TimeInterval = 0
        
        let started = accelerometer.start { reading in
            // 1. Record raw data
            let dict: [String: Any] = [
                "t": reading.timestamp,
                "x": reading.x,
                "y": reading.y,
                "z": reading.z
            ]
            
            if let data = try? JSONSerialization.data(withJSONObject: dict),
               let str = String(data: data, encoding: .utf8) {
                let line = str + "\n"
                if let lineData = line.data(using: .utf8) {
                    fileHandle.write(lineData)
                }
            }
            
            // 2. Provide real-time feedback on pace
            if let _ = detector.process(reading) {
                tapCount += 1
                let now = reading.timestamp
                
                var feedback = ""
                if tapCount > 1 {
                    let interval = now - lastTapTime
                    if interval < 1.5 {
                        feedback = "⚠️ Too fast! Wait a bit longer."
                    } else if interval > 3.0 {
                        feedback = "🐢 A bit slow. Keep a steady pace."
                    } else {
                        feedback = "✅ Good pace!"
                    }
                }
                
                lastTapTime = now
                print("Recorded tap #\(tapCount) \(feedback)")
            }
        }
        
        if !started {
            print("Failed to start accelerometer. Make sure to run with sudo.")
            return
        }
        
        print("Recording started. Press Ctrl+C to stop.")
        
        // Run the run loop to keep the tool alive and receiving callbacks
        RunLoop.current.run()
        
        try? fileHandle.close()
    }
}
