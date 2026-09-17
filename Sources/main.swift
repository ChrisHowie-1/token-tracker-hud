import Cocoa

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // Accessory app so it doesn't show in the macOS Dock, behaves as a pure menu/HUD agent
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
