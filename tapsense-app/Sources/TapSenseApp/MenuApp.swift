import AppKit

final class MenuAppController: NSObject, NSApplicationDelegate {
    private let controller = SidecarController()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    private let statusMenuItem = NSMenuItem(title: "Status: Stopped", action: nil, keyEquivalent: "")
    private let lastEventMenuItem = NSMenuItem(title: "No events yet", action: nil, keyEquivalent: "")
    private let toggleMenuItem = NSMenuItem(title: "Start Listening", action: #selector(toggleListening), keyEquivalent: "")
    private let simulateMenuItem = NSMenuItem(title: "Simulate Mode", action: #selector(toggleSimulate), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller.onStateChange = { [weak self] in
            self?.refreshMenu()
        }

        if let button = statusItem.button {
            button.title = "TapSense"
        }

        let menu = NSMenu()
        menu.addItem(statusMenuItem)
        menu.addItem(lastEventMenuItem)
        menu.addItem(.separator())
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)

        simulateMenuItem.target = self
        simulateMenuItem.state = .on
        menu.addItem(simulateMenuItem)

        menu.addItem(makeModeMenu())
        menu.addItem(makeSensitivityMenu())
        menu.addItem(.separator())

        let testNotification = NSMenuItem(title: "Test Notification", action: #selector(testNotification), keyEquivalent: "")
        testNotification.target = self
        menu.addItem(testNotification)

        let quit = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        refreshMenu()
    }

    private func makeModeMenu() -> NSMenuItem {
        let modeItem = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for mode in TapSenseMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            submenu.addItem(item)
        }
        modeItem.submenu = submenu
        return modeItem
    }

    private func makeSensitivityMenu() -> NSMenuItem {
        let item = NSMenuItem(title: "Sensitivity", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for sensitivity in TapSenseSensitivity.allCases {
            let child = NSMenuItem(title: sensitivity.title, action: #selector(selectSensitivity(_:)), keyEquivalent: "")
            child.target = self
            child.representedObject = sensitivity.rawValue
            submenu.addItem(child)
        }
        item.submenu = submenu
        return item
    }

    private func refreshMenu() {
        statusMenuItem.title = "Status: \(controller.statusText)"
        lastEventMenuItem.title = controller.lastEventText
        toggleMenuItem.title = controller.isRunning ? "Stop Listening" : "Start Listening"
        simulateMenuItem.state = controller.simulateMode ? .on : .off
        updateSubmenuStates()
        if let button = statusItem.button {
            button.title = controller.isRunning ? "TapSense●" : "TapSense"
        }
    }

    private func updateSubmenuStates() {
        statusItem.menu?.items.forEach { item in
            guard let submenu = item.submenu else { return }
            for child in submenu.items {
                if let raw = child.representedObject as? String,
                   let mode = TapSenseMode(rawValue: raw) {
                    child.state = mode == controller.mode ? .on : .off
                } else if let raw = child.representedObject as? String,
                          let sensitivity = TapSenseSensitivity(rawValue: raw) {
                    child.state = sensitivity == controller.sensitivity ? .on : .off
                }
            }
        }
    }

    @objc private func toggleListening() {
        controller.toggle()
    }

    @objc private func toggleSimulate() {
        controller.simulateMode.toggle()
        if controller.isRunning {
            controller.stop()
            controller.start()
        } else {
            refreshMenu()
        }
    }

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = TapSenseMode(rawValue: raw) else { return }
        controller.mode = mode
        if controller.isRunning {
            controller.stop()
            controller.start()
        } else {
            refreshMenu()
        }
    }

    @objc private func selectSensitivity(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let sensitivity = TapSenseSensitivity(rawValue: raw) else { return }
        controller.sensitivity = sensitivity
        if controller.isRunning {
            controller.stop()
            controller.start()
        } else {
            refreshMenu()
        }
    }

    @objc private func testNotification() {
        controller.sendTestNotification()
    }

    @objc private func quitApp() {
        controller.stop()
        NSApp.terminate(nil)
    }
}
