import AppKit
import Observation
import PeriodicalCore
import UserNotifications

/// Posts "ends in N minutes" reminders for the running block. Falls back to a chime when
/// notifications are off, so turning reminders on always does something.
@MainActor
@Observable
final class EndAlerts: NSObject, UNUserNotificationCenterDelegate {
    enum Permission {
        case unknown, allowed, denied
    }

    private(set) var permission = Permission.unknown
    @ObservationIgnored private var reminded: Set<String> = []

    /// `UNUserNotificationCenter` traps outside an app bundle (e.g. `swift run`), so it's only touched inside one.
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : .current()
    }

    override init() {
        super.init()
        center?.delegate = self
        refreshPermission()
    }

    /// Asks once, the first time reminders are turned on.
    func requestPermission() {
        guard let center else { return }
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in
            Task { @MainActor in self.refreshPermission() }
        }
    }

    func refreshPermission() {
        guard let center else { return }
        center.getNotificationSettings { settings in
            let status = settings.authorizationStatus
            Task { @MainActor in
                switch status {
                case .authorized, .provisional: self.permission = .allowed
                case .denied: self.permission = .denied
                default: self.permission = .unknown
                }
            }
        }
    }

    func openSystemSettings() {
        let id = Bundle.main.bundleIdentifier ?? ""
        if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Posts a sample reminder right away, so the user can see (and hear) what one looks like.
    func sendTest(minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Chemistry ends in \(minutes) minute\(minutes == 1 ? "" : "s")"
        content.body = "This is how reminders look."
        content.sound = .default
        guard let center, permission == .allowed else {
            NSSound(named: "Glass")?.play()
            return
        }
        center.add(UNNotificationRequest(identifier: "test-\(UUID())", content: content, trigger: nil))
    }

    /// Called every tick with the menu bar's current block.
    func check(_ current: (TimeBlock, BlockPhase)?, next: (block: TimeBlock, start: Date)?, minutesBefore: Int, now: Date) {
        guard minutesBefore > 0, let (block, phase) = current, case .active(let seconds) = phase else { return }
        let threshold = minutesBefore * 60
        // Skip blocks too short to warn about, and only remind once per block per day.
        guard block.minutes * 60 > threshold, seconds <= threshold else { return }
        let key = "\(block.id)-\(CalendarDay(now))"
        guard reminded.insert(key).inserted else { return }

        let minutesLeft = max(1, Int((Double(seconds) / 60).rounded()))
        let content = UNMutableNotificationContent()
        content.title = "\(block.name) ends in \(minutesLeft) minute\(minutesLeft == 1 ? "" : "s")"
        var body = "Until \(TimeParser.format(minutes: block.end))."
        if let next, Calendar.current.isDate(next.start, inSameDayAs: now) {
            body += " Next: \(next.block.name) at \(TimeParser.format(minutes: next.block.start))."
        }
        content.body = body
        content.sound = .default

        guard let center, permission == .allowed else {
            NSSound(named: "Glass")?.play()
            return
        }
        center.add(UNNotificationRequest(identifier: key, content: content, trigger: nil))
    }

    // Show the banner even while the panel has the app active.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
