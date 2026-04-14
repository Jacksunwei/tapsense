import AppKit
import Foundation

final class SidecarController: NSObject {
    private(set) var process: Process?
    private(set) var isRunning = false
    private(set) var statusText = "Stopped"
    private(set) var lastEventText = "No events yet"

    var simulateMode = true
    var mode: MenuKnockMode = .palmRest
    var sensitivity: MenuKnockSensitivity = .medium
    var onStateChange: (() -> Void)?

    override init() {
        super.init()
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    func start() {
        guard process == nil else { return }

        let binary = resolveSidecarPath()
        guard FileManager.default.fileExists(atPath: binary.path) else {
            statusText = "Missing sidecar"
            lastEventText = "Build knock-sidecar first: ./build.sh"
            onStateChange?()
            return
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
            self?.consumeOutput(data)
        }

        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                DispatchQueue.main.async {
                    self?.lastEventText = text
                    self?.onStateChange?()
                }
            }
        }

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.process = nil
                self?.isRunning = false
                self?.statusText = "Stopped"
                self?.onStateChange?()
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
            statusText = "Start failed"
            lastEventText = error.localizedDescription
            onStateChange?()
        }
    }

    func stop() {
        process?.interrupt()
        process = nil
        isRunning = false
        statusText = "Stopped"
        onStateChange?()
    }

    private func buildArguments() -> [String] {
        var args: [String] = ["--mode", mode.rawValue, "--sensitivity", sensitivity.rawValue]
        if simulateMode {
            args.append("--simulate")
        }
        return args
    }

    private func consumeOutput(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        let lines = text.split(whereSeparator: \.isNewline)
        for line in lines {
            guard let jsonData = String(line).data(using: .utf8) else { continue }
            if let event = try? JSONDecoder().decode(SidecarEvent.self, from: jsonData) {
                DispatchQueue.main.async {
                    self.handle(event: event)
                }
            }
        }
    }

    private func handle(event: SidecarEvent) {
        switch event.type {
        case "started":
            statusText = "Running"
            let profile = event.profile ?? mode.rawValue
            let sensitivity = event.sensitivity ?? self.sensitivity.rawValue
            lastEventText = "Started (\(profile), \(sensitivity), \(simulateMode ? "simulate" : "real"))"
        case "knock_pattern":
            let pattern = event.pattern ?? "unknown"
            lastEventText = "Detected \(pattern) knock"
        case "error":
            statusText = "Error"
            lastEventText = event.message ?? "Unknown error"
            showAlert(title: "Knock error", message: lastEventText)
        case "stopped":
            statusText = "Stopped"
            lastEventText = "Sidecar stopped"
        default:
            break
        }
        onStateChange?()
    }

    func sendTestNotification() {
        showAlert(title: "Knock menu app", message: "Test notification")
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.runModal()
    }

    private func resolveSidecarPath() -> URL {
        let fm = FileManager.default
        let candidates = [
            URL(fileURLWithPath: fm.currentDirectoryPath),
            URL(fileURLWithPath: (fm.homeDirectoryForCurrentUser.appending(path: "GitHub/vscode-knock-demo")).path),
            URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        ]

        for base in candidates {
            for root in searchRoots(startingAt: base) {
                let candidate = root
                    .appending(path: "knock-sidecar")
                    .appending(path: ".build")
                    .appending(path: "release")
                    .appending(path: "KnockSidecar")
                if fm.fileExists(atPath: candidate.path) {
                    return candidate
                }
            }
        }

        return fm.homeDirectoryForCurrentUser
            .appending(path: "GitHub")
            .appending(path: "vscode-knock-demo")
            .appending(path: "knock-sidecar")
            .appending(path: ".build")
            .appending(path: "release")
            .appending(path: "KnockSidecar")
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
