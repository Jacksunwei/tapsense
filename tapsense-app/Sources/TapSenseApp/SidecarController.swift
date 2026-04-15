import AppKit
import Foundation
import UserNotifications

final class SidecarController: NSObject {
    private(set) var process: Process?
    private(set) var isRunning = false
    private(set) var statusText = "Stopped"
    private(set) var lastEventText = "No events yet"
    private var stdoutBuffer = ""
    private var stderrBuffer = ""
    private let jsonDecoder = JSONDecoder()

    var simulateMode = false
    var testMode = true
    var sensitivity: TapSenseSensitivity = .medium
    var onStateChange: (() -> Void)?

    override init() {
        super.init()
        requestNotificationPermission()
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    func start() {
        guard process == nil else { return }

        let binary = resolveSidecarPath()
        guard FileManager.default.fileExists(atPath: binary.path) else {
            statusText = "Missing sidecar"
            lastEventText = "Build tapsense-sidecar first: ./build.sh"
            onStateChange?()
            return
        }

        // Real accelerometer + CGEventTap both need root. If user wants real mode,
        // make sure the sidecar binary is setuid-root. Prompt once via AppleScript.
        if !simulateMode && !isSetuidRoot(at: binary) {
            guard elevateBinary(at: binary) else {
                statusText = "Needs privileges"
                lastEventText = "Grant admin to enable real tap detection, or use Simulate Mode."
                onStateChange?()
                return
            }
        }

        let process = Process()
        process.executableURL = binary
        process.arguments = buildArguments()

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async {
                self?.consumeOutput(data)
            }
        }

        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async {
                self?.consumeDiagnostics(data)
            }
        }

        process.terminationHandler = { [weak self] terminatedProcess in
            DispatchQueue.main.async {
                self?.finishTerminatedProcess(terminatedProcess)
            }
        }

        do {
            try process.run()
            self.process = process
            self.isRunning = true
            self.statusText = "Starting"
            self.lastEventText = "Launching sidecar"
            onStateChange?()
        } catch {
            clearPipeHandlers(for: process)
            statusText = "Start failed"
            lastEventText = error.localizedDescription
            onStateChange?()
        }
    }

    func stop() {
        clearPipeHandlers(for: process)
        process?.interrupt()
        process = nil
        isRunning = false
        statusText = "Stopped"
        onStateChange?()
    }

    private func finishTerminatedProcess(_ terminatedProcess: Process) {
        guard process === terminatedProcess else {
            return
        }

        flushOutputBuffers()
        clearPipeHandlers(for: terminatedProcess)
        process = nil
        isRunning = false
        statusText = "Stopped"
        onStateChange?()
    }

    private func buildArguments() -> [String] {
        var args: [String] = ["--sensitivity", sensitivity.rawValue]
        if simulateMode {
            args.append("--simulate")
        }
        return args
    }

    private func consumeOutput(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        stdoutBuffer += text

        while let newlineIndex = stdoutBuffer.firstIndex(where: \.isNewline) {
            let line = String(stdoutBuffer[..<newlineIndex])
            stdoutBuffer.removeSubrange(...newlineIndex)
            handleOutputLine(line)
        }
    }

    private func consumeDiagnostics(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        stderrBuffer += text

        while let newlineIndex = stderrBuffer.firstIndex(where: \.isNewline) {
            let line = String(stderrBuffer[..<newlineIndex])
            stderrBuffer.removeSubrange(...newlineIndex)
            handleDiagnosticLine(line)
        }
    }

    private func flushOutputBuffers() {
        if !stdoutBuffer.isEmpty {
            handleOutputLine(stdoutBuffer)
            stdoutBuffer.removeAll(keepingCapacity: true)
        }

        if !stderrBuffer.isEmpty {
            handleDiagnosticLine(stderrBuffer)
            stderrBuffer.removeAll(keepingCapacity: true)
        }
    }

    private func handleOutputLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let jsonData = trimmed.data(using: .utf8) else { return }
        if let event = try? jsonDecoder.decode(SidecarEvent.self, from: jsonData) {
            handle(event: event)
        }
    }

    private func handleDiagnosticLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lastEventText = trimmed
        onStateChange?()
    }

    private func clearPipeHandlers(for process: Process?) {
        if let stdout = process?.standardOutput as? Pipe {
            stdout.fileHandleForReading.readabilityHandler = nil
        }
        if let stderr = process?.standardError as? Pipe {
            stderr.fileHandleForReading.readabilityHandler = nil
        }
    }

    private func handle(event: SidecarEvent) {
        switch event.type {
        case "started":
            statusText = "Running"
            let sensitivity = event.sensitivity ?? self.sensitivity.rawValue
            lastEventText = "Started (\(sensitivity), \(simulateMode ? "simulate" : "real"))"
        case "tap_pattern":
            let pattern = event.pattern ?? "unknown"
            lastEventText = "Detected \(pattern) tap"
            if testMode {
                sendNotification(title: "TapSense Detected", body: "Pattern: \(pattern)")
            }
        case "error":
            statusText = "Error"
            lastEventText = event.message ?? "Unknown error"
            showAlert(title: "TapSense error", message: lastEventText)
        case "stopped":
            statusText = "Stopped"
            lastEventText = "Sidecar stopped"
        default:
            break
        }
        onStateChange?()
    }

    func sendTestNotification() {
        sendNotification(title: "TapSense Test", body: "Manual test notification triggered")
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendNotification(title: String, body: String) {
        // UNUserNotificationCenter requires a properly signed bundle with notification
        // entitlements. For ad-hoc builds and dev use, osascript "display notification"
        // is reliable and doesn't need a permission prompt.
        let safeTitle = title.replacingOccurrences(of: "\"", with: "'")
        let safeBody = body.replacingOccurrences(of: "\"", with: "'")
        let script = "display notification \"\(safeBody)\" with title \"\(safeTitle)\" sound name \"Pop\""
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        try? task.run()
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func isSetuidRoot(at url: URL) -> Bool {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return false }
        let posixPerms = (attrs[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
        let ownerID = (attrs[.ownerAccountID] as? NSNumber)?.uint32Value ?? UINT32_MAX
        return ownerID == 0 && (posixPerms & 0o4000) != 0
    }

    private func elevateBinary(at url: URL) -> Bool {
        let path = url.path.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"chown root:wheel '\(path)' && chmod 4755 '\(path)'\" with administrator privileges"
        var errorDict: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&errorDict)
        if result == nil {
            if let err = errorDict {
                fputs("[tapsense] elevateBinary failed: \(err)\n", stderr)
            }
            return false
        }
        return isSetuidRoot(at: url)
    }

    private func resolveSidecarPath() -> URL {
        let fm = FileManager.default

        if let bundled = bundledSidecarPath(), fm.fileExists(atPath: bundled.path) {
            return bundled
        }

        let candidates = [
            URL(fileURLWithPath: fm.currentDirectoryPath),
            URL(fileURLWithPath: (fm.homeDirectoryForCurrentUser.appending(path: "GitHub/tapsense")).path),
            URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        ]

        for base in candidates {
            for root in searchRoots(startingAt: base) {
                let candidate = root
                    .appending(path: "tapsense-sidecar")
                    .appending(path: ".build")
                    .appending(path: "release")
                    .appending(path: "TapSenseSidecar")
                if fm.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        return fm.homeDirectoryForCurrentUser
            .appending(path: "GitHub")
            .appending(path: "tapsense")
            .appending(path: "tapsense-sidecar")
            .appending(path: ".build")
            .appending(path: "release")
            .appending(path: "TapSenseSidecar")
    }

    private func bundledSidecarPath() -> URL? {
        let executableURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
        let contentsURL = executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        guard contentsURL.lastPathComponent == "Contents" else {
            return nil
        }

        let resourcesURL = contentsURL.appending(path: "Resources")
        return resourcesURL.appending(path: "TapSenseSidecar")
    }

    private func searchRoots(startingAt base: URL) -> [URL] {
        var roots: [URL] = []
        var current = base
        for _ in 0..<6 {
            roots.append(current)
            current.deleteLastPathComponent()
        }
        return roots
    }
}
