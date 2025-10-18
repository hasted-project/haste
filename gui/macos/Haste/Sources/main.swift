import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Activate the app
app.setActivationPolicy(.accessory)
app.activate(ignoringOtherApps: true)

// Run the app
app.run()

