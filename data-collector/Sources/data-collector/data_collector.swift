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
        
        let started = accelerometer.start { reading in
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
        }
        
        if !started {
            print("Failed to start accelerometer. Make sure to run with sudo.")
            return
        }
        
        print("Recording started. Press Ctrl+C to stop.")
        
        // Run the run loop to keep the tool alive and receiving callbacks
        RunLoop.current.run()
        
        // This point is never reached unless the run loop is stopped, 
        // but it's good practice to close the handle.
        try? fileHandle.close()
    }
}
