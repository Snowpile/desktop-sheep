import AppKit
import ServiceManagement

/// "Launch at Login" via SMAppService (macOS 13+). Only works when running from the .app bundle.
@MainActor
enum LaunchAtLogin {
    /// False for `swift run` builds, which aren't an app bundle macOS can register.
    static var isAvailable: Bool { Bundle.main.bundlePath.hasSuffix(".app") }

    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static var needsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }

    static func toggle() {
        do {
            if isEnabled || needsApproval {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Launch at Login"
            alert.informativeText = error.localizedDescription
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
        if needsApproval {
            // macOS wants the user to allow the login item first.
            let alert = NSAlert()
            alert.messageText = "Allow Desktop Sheep in Login Items"
            alert.informativeText = "macOS needs your OK: turn on Desktop Sheep under System Settings › General › Login Items."
            alert.addButton(withTitle: "Open Login Items")
            alert.addButton(withTitle: "Later")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn { SMAppService.openSystemSettingsLoginItems() }
        }
    }
}
