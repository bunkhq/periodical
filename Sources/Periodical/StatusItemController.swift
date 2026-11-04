import AppKit
import PeriodicalCore
import SwiftUI

/// Owns the menu bar button: a colored pill for the current block, or a plain hourglass when idle.
@MainActor
final class StatusItemController: NSObject {
    private let store: BlockStore
    private let clock: Clock
    private let prefs: Preferences
    private let alerts: EndAlerts
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel: PanelController
    private let updater = Updater()
    private var lastRendered: MenuBarPill?
    private var lastIdle: IdleState?

    private struct IdleState: Equatable {
        let dayOff: Bool
        let tooltip: String
    }

    init(store: BlockStore, clock: Clock, prefs: Preferences, alerts: EndAlerts) {
        self.store = store
        self.clock = clock
        self.prefs = prefs
        self.alerts = alerts
        self.panel = PanelController(store: store, clock: clock, prefs: prefs, alerts: alerts)
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(clicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageOnly
            button.wantsLayer = true
            button.layer?.cornerCurve = .continuous
        }
        clock.onTick { [weak self] in self?.refresh() }
        store.onChange = { [weak self] in self?.redraw() }
        prefs.onChange = { [weak self] in self?.redraw() }
        refresh()

        if !prefs.hasOnboarded {
            if store.blocks.isEmpty {
                // First launch: open setup under the menu bar item so there's no hunting for it.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    guard let self, let button = self.statusItem.button else { return }
                    self.panel.show(from: button)
                }
            } else {
                // People upgrading with a schedule already in place skip setup.
                prefs.hasOnboarded = true
            }
        }
    }

    /// Forces a repaint after a setting or the schedule changes.
    private func redraw() {
        lastRendered = nil
        lastIdle = nil
        refresh()
    }

    private func refresh() {
        guard let button = statusItem.button else { return }
        let now = Date()
        let current = Schedule.current(store.blocks, settings: store.settings, now: now)
        let next = Schedule.next(store.blocks, settings: store.settings, after: now)
        alerts.check(current, next: next, minutesBefore: prefs.endAlertMinutes, now: now)

        guard let (block, phase) = current else {
            showIdle(next: next, now: now)
            return
        }

        let pill: MenuBarPill
        switch phase {
        case .active(let seconds):
            pill = MenuBarPill(icon: .active, timer: DurationFormat.string(seconds: seconds), title: block.name, color: block.color, fillsButton: prefs.fillMenuBarButton, showsTitle: prefs.showNameInMenuBar)
        case .upcoming(let seconds):
            pill = MenuBarPill(icon: .starting, timer: DurationFormat.string(seconds: seconds), title: block.name, color: block.color, fillsButton: prefs.fillMenuBarButton, showsTitle: prefs.showNameInMenuBar)
        case .passed:
            return
        }
        guard pill != lastRendered else { return }
        lastRendered = pill
        lastIdle = nil

        button.title = ""
        button.imagePosition = .imageOnly
        button.image = pill.image()
        setButtonFill(pill.fillsButton ? NSColor(hex: block.color) : nil)
        let verb = if case .active = phase { "ends" } else { "starts" }
        button.toolTip = "\(block.name) · \(TimeParser.format(minutes: block.start)) – \(TimeParser.format(minutes: block.end))"
        button.setAccessibilityLabel("\(block.name) \(verb) in \(pill.timer)")
    }

    /// Hourglass alone, or with "Off" on a day off so a paused schedule is never mistaken for an empty one.
    private func showIdle(next: (block: TimeBlock, start: Date)?, now: Date) {
        guard let button = statusItem.button else { return }
        let today = CalendarDay(now)
        let dayOff = store.settings.isDayOff(today)
        var tooltip: String
        if store.blocks.isEmpty {
            tooltip = "Periodical · Click to add your first block"
        } else if let next {
            tooltip = "Next: \(next.block.name) · \(RelativeDay.string(for: next.start, now: now))"
        } else {
            tooltip = "Nothing scheduled in the next three weeks"
        }
        if dayOff { tooltip = "Day off · " + tooltip }

        let state = IdleState(dayOff: dayOff, tooltip: tooltip)
        guard state != lastIdle else { return }
        lastIdle = state
        lastRendered = nil

        button.image = Self.idleImage
        button.title = dayOff ? "Off" : ""
        button.font = .systemFont(ofSize: 12, weight: .medium)
        button.imagePosition = dayOff ? .imageLeading : .imageOnly
        button.toolTip = tooltip
        button.setAccessibilityLabel(tooltip)
        setButtonFill(nil)
    }

    /// Paints the button itself as a capsule, so the color reaches the edges of the menu bar highlight.
    private func setButtonFill(_ color: NSColor?) {
        guard let button = statusItem.button, let layer = button.layer else { return }
        button.layoutSubtreeIfNeeded()
        layer.backgroundColor = color?.cgColor
        layer.cornerRadius = color == nil ? 0 : button.bounds.height / 2
    }

    private static let idleImage: NSImage = {
        let image = NSImage(size: NSSize(width: 12, height: 15), flipped: true) { rect in
            MenuBarPill.drawHourglass(.starting, in: rect, color: .black)
            return true
        }
        image.isTemplate = true
        return image
    }()

    @objc private func clicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            panel.close()
            statusItem.menu = makeMenu()
            sender.performClick(nil)
            statusItem.menu = nil
        } else {
            panel.toggle(from: sender)
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        @discardableResult
        func item(_ title: String, _ action: Selector, on: Bool? = nil, key: String = "") -> NSMenuItem {
            let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
            item.target = self
            if let on { item.state = on ? .on : .off }
            return item
        }

        let offToday = store.settings.isDayOff(CalendarDay(Date()))
        item(offToday ? "Back On Today" : "Take Today Off", #selector(toggleDayOff))
        item("Settings…", #selector(openSettings), key: ",")
        menu.addItem(.separator())
        item("Fill Menu Bar Button", #selector(toggleFillButton), on: prefs.fillMenuBarButton)
        item("Show Block Name", #selector(toggleShowTitle), on: prefs.showNameInMenuBar)
        item("Launch at Login", #selector(toggleLoginItem), on: LoginItem.isEnabled)
        menu.addItem(.separator())
        item(updateMenuTitle, #selector(checkForUpdates)).isEnabled = updater.state == .idle
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Periodical", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    @objc private func toggleDayOff() {
        let today = CalendarDay(Date())
        if store.settings.isDayOff(today) {
            store.resume(on: today)
        } else {
            store.addDayOff(DayOff(start: today, end: today))
        }
    }

    @objc private func openSettings() {
        guard let button = statusItem.button else { return }
        // Let the menu finish closing before the panel takes focus.
        DispatchQueue.main.async { self.panel.show(from: button, route: .settings) }
    }

    @objc private func toggleLoginItem() {
        LoginItem.set(!LoginItem.isEnabled)
    }

    private var updateMenuTitle: String {
        switch updater.state {
        case .idle: "Check for Updates…"
        case .checking: "Checking for Updates…"
        case .downloading: "Downloading Update…"
        }
    }

    @objc private func checkForUpdates() {
        updater.checkForUpdates()
    }

    @objc private func toggleFillButton() {
        prefs.fillMenuBarButton.toggle()
    }

    @objc private func toggleShowTitle() {
        prefs.showNameInMenuBar.toggle()
    }
}

/// The menu bar pill: `[⌛] 1h 26m 54s • Econ & Personal Finance Honors`.
/// The hourglass shows whether the block is running (`.active`) or still to come (`.starting`).
///
/// Drawn with AppKit rather than `ImageRenderer`, which returns an empty image for status items.
struct MenuBarPill: Equatable {
    let icon: Hourglass.Kind
    let timer: String
    let title: String
    let color: String
    /// The button paints the color itself, so the image only draws the icon and text.
    let fillsButton: Bool
    /// Off shows only the hourglass and timer.
    let showsTitle: Bool

    private static let height: CGFloat = 20
    private static let padding: CGFloat = 6
    private static let iconSize = NSSize(width: 9, height: 11.25)
    private static let gap: CGFloat = 4

    private var displayTitle: String {
        title.count > 32 ? title.prefix(31).trimmingCharacters(in: .whitespaces) + "…" : title
    }

    func image() -> NSImage {
        let foreground = NSColor.foreground(onHex: color)
        let text = NSMutableAttributedString(string: timer, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold),
            .foregroundColor: foreground,
        ])
        if showsTitle {
            text.append(NSAttributedString(string: " • \(displayTitle)", attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular),
                .foregroundColor: foreground,
            ]))
        }
        let textSize = text.size()
        let size = NSSize(
            width: ceil(Self.padding * 2 + Self.iconSize.width + Self.gap + textSize.width),
            height: Self.height
        )

        let image = NSImage(size: size, flipped: true) { rect in
            if !fillsButton {
                NSColor(hex: color).setFill()
                NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5).fill()
            }
            let iconRect = NSRect(
                x: Self.padding,
                y: (rect.height - Self.iconSize.height) / 2,
                width: Self.iconSize.width,
                height: Self.iconSize.height
            )
            Self.drawHourglass(icon, in: iconRect, color: foreground)
            text.draw(at: NSPoint(x: iconRect.maxX + Self.gap, y: (rect.height - textSize.height) / 2))
            return true
        }
        image.isTemplate = false
        return image
    }

    static func drawHourglass(_ kind: Hourglass.Kind, in rect: NSRect, color: NSColor) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.addPath(Hourglass(kind: kind).path(in: rect).cgPath)
        context.setFillColor(color.cgColor)
        context.fillPath(using: .evenOdd)
    }
}
