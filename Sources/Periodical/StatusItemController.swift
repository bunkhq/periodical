import AppKit
import PeriodicalCore
import SwiftUI

/// Owns the menu bar button: a colored pill for the current block, or a plain hourglass when idle.
@MainActor
final class StatusItemController: NSObject {
    private let store: BlockStore
    private let clock: Clock
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let panel: PanelController
    private var lastRendered: MenuBarPill?
    private var showingIdle = false

    private static let fillButtonKey = "fillMenuBarButton"

    /// When on, the block color fills the whole rounded menu bar button instead of a box inside it. Off by default.
    private var fillButton: Bool {
        get { UserDefaults.standard.bool(forKey: Self.fillButtonKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.fillButtonKey) }
    }

    private static let showTitleKey = "showCourseNameInMenuBar"

    /// When on, the course name follows the timer in the menu bar button. On by default.
    private var showTitle: Bool {
        get { UserDefaults.standard.object(forKey: Self.showTitleKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: Self.showTitleKey) }
    }

    init(store: BlockStore, clock: Clock) {
        self.store = store
        self.clock = clock
        self.panel = PanelController(store: store, clock: clock)
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
        store.onChange = { [weak self] in self?.refresh() }
        refresh()
    }

    private func refresh() {
        guard let button = statusItem.button else { return }

        guard let (block, phase) = Schedule.current(store.blocks, now: Date()) else {
            if !showingIdle {
                button.image = Self.idleImage
                button.toolTip = "Periodical"
                setButtonFill(nil)
                lastRendered = nil
                showingIdle = true
            }
            return
        }

        let pill: MenuBarPill
        switch phase {
        case .active(let seconds):
            pill = MenuBarPill(icon: .active, timer: DurationFormat.string(seconds: seconds), title: block.name, color: block.color, fillsButton: fillButton, showsTitle: showTitle)
        case .upcoming(let seconds):
            pill = MenuBarPill(icon: .starting, timer: DurationFormat.string(seconds: seconds), title: block.name, color: block.color, fillsButton: fillButton, showsTitle: showTitle)
        case .passed:
            return
        }
        guard pill != lastRendered else { return }
        lastRendered = pill
        showingIdle = false

        button.image = pill.image()
        setButtonFill(pill.fillsButton ? NSColor(hex: block.color) : nil)
        button.toolTip = "\(block.name) · \(TimeParser.format(minutes: block.start)) – \(TimeParser.format(minutes: block.end))"
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
            let menu = NSMenu()
            let login = menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
            login.target = self
            login.state = LoginItem.isEnabled ? .on : .off
            let fill = menu.addItem(withTitle: "Fill Menu Bar Button", action: #selector(toggleFillButton), keyEquivalent: "")
            fill.target = self
            fill.state = fillButton ? .on : .off
            let title = menu.addItem(withTitle: "Show Course Name", action: #selector(toggleShowTitle), keyEquivalent: "")
            title.target = self
            title.state = showTitle ? .on : .off
            menu.addItem(.separator())
            menu.addItem(withTitle: "Quit Periodical", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            statusItem.menu = menu
            sender.performClick(nil)
            statusItem.menu = nil
        } else {
            panel.toggle(from: sender)
        }
    }

    @objc private func toggleLoginItem() {
        LoginItem.set(!LoginItem.isEnabled)
    }

    @objc private func toggleFillButton() {
        fillButton.toggle()
        lastRendered = nil
        refresh()
    }

    @objc private func toggleShowTitle() {
        showTitle.toggle()
        lastRendered = nil
        refresh()
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
        let foreground = NSColor(hex: color).relativeLuminance > 0.55
            ? NSColor.black.withAlphaComponent(0.85)
            : NSColor.white
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
