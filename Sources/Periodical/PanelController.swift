import AppKit
import SwiftUI

/// Borderless panel that drops down from the status item and stays pinned to it while resizing.
final class DropdownPanel: NSPanel {
    var anchorTop: CGFloat?

    override var canBecomeKey: Bool { true }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(anchored(frameRect), display: flag)
    }

    override func setFrame(_ frameRect: NSRect, display displayFlag: Bool, animate animateFlag: Bool) {
        super.setFrame(anchored(frameRect), display: displayFlag, animate: animateFlag)
    }

    private func anchored(_ rect: NSRect) -> NSRect {
        guard let anchorTop else { return rect }
        var r = rect
        r.origin.y = anchorTop - r.height
        return r
    }
}

/// Where the panel's arrow points, set each time the panel opens.
@Observable
final class PanelLayout {
    var arrowX: CGFloat = 160
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let store: BlockStore
    private let clock: Clock
    private let panel: DropdownPanel
    private let hosting: NSHostingController<AnyView>
    private let layout = PanelLayout()
    private var outsideClickMonitor: Any?
    private weak var button: NSStatusBarButton?
    private var closedAt = Date.distantPast

    init(store: BlockStore, clock: Clock) {
        self.store = store
        self.clock = clock
        hosting = NSHostingController(rootView: AnyView(EmptyView()))
        hosting.sizingOptions = [.preferredContentSize]
        panel = DropdownPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.contentViewController = hosting
        panel.delegate = self
    }

    func toggle(from button: NSStatusBarButton) {
        if panel.isVisible {
            close()
        } else if Date().timeIntervalSince(closedAt) > 0.25 {
            // The guard stops a click that just dismissed the panel from reopening it.
            show(from: button)
        }
    }

    private func show(from button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        self.button = button

        // Fresh view state on every open.
        hosting.rootView = AnyView(
            ContentView(store: store, clock: clock, layout: layout, dismiss: { [weak self] in self?.close() })
                .id(UUID())
        )
        hosting.view.layoutSubtreeIfNeeded()
        let size = hosting.view.fittingSize

        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let visible = (buttonWindow.screen ?? NSScreen.main)?.visibleFrame ?? .zero
        // Status bar windows can be taller than the menu bar, so never start above the visible frame.
        let top = min(buttonRect.minY, visible.maxY) - 1
        // Centered under the button, nudged back on screen near the edges; the arrow still points at the button.
        var x = buttonRect.midX - size.width / 2
        x = min(x, visible.maxX - size.width - 8)
        x = max(x, visible.minX + 8)
        layout.arrowX = buttonRect.midX - x

        panel.anchorTop = top
        panel.setFrame(NSRect(x: x, y: top - size.height, width: size.width, height: size.height), display: true)
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        button.highlight(true)

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    func close() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        closedAt = Date()
        button?.highlight(false)
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }
}
