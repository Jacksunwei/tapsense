import AppKit

let application = NSApplication.shared
let delegate = MenuAppController()
application.delegate = delegate
application.run()
