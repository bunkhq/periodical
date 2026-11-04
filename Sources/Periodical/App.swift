import AppKit

@main
enum PeriodicalApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        #if DEBUG
        if Snapshots.runIfRequested() { return }
        #endif
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = BlockStore()
    private let clock = Clock()
    private let prefs = Preferences()
    private lazy var alerts = EndAlerts()
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = StatusItemController(store: store, clock: clock, prefs: prefs, alerts: alerts)
        LoginItem.enableByDefault()
    }
}
