import Foundation
import ServiceManagement

/// Launch-at-login via `SMAppService`. Turned on the first time the app runs; after that the user's choice sticks.
@MainActor
enum LoginItem {
    private static let configuredKey = "loginItemConfigured"

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers on first launch only, so turning it off from the menu isn't undone on the next start.
    static func enableByDefault() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: configuredKey) else { return }
        defaults.set(true, forKey: configuredKey)
        set(true)
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Periodical: couldn't \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }
}
