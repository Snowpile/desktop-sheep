import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// No Dock icon or app menu; the menu-bar item is the only UI besides the sheep.
app.setActivationPolicy(.accessory)
app.run()
