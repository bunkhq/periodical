#if DEBUG
import AppKit
import PeriodicalCore
import SwiftUI

/// `PERIODICAL_SNAPSHOT_DIR=/some/dir swift run` renders panel states with sample data to PNGs and exits.
/// Uses a throwaway store, so the real schedule is never touched.
@MainActor
enum Snapshots {
    static func runIfRequested() -> Bool {
        guard let out = ProcessInfo.processInfo.environment["PERIODICAL_SNAPSHOT_DIR"] else { return false }
        let outURL = URL(fileURLWithPath: out, isDirectory: true)
        try? FileManager.default.createDirectory(at: outURL, withIntermediateDirectories: true)
        _ = NSApplication.shared

        let cal = Calendar.current
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 10, minute: 23, second: 41))!
        let monday = CalendarDay(year: 2026, month: 11, day: 2)

        func store(_ name: String, blocks: [TimeBlock], settings: (BlockStore) -> Void = { _ in }) -> BlockStore {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("periodical-snap-\(name)-\(UUID())")
            let s = BlockStore(directory: dir)
            blocks.forEach { s.add($0) }
            settings(s)
            return s
        }
        let schoolWeek: Set<Int> = [2, 3, 4, 5, 6]
        func b(_ name: String, _ h1: Int, _ m1: Int, _ h2: Int, _ m2: Int, _ color: String, cycle: Set<Int>? = nil, group: UUID? = nil) -> TimeBlock {
            TimeBlock(name: name, start: h1 * 60 + m1, end: h2 * 60 + m2, weekdays: schoolWeek, cycleDays: cycle, color: color, groupID: group)
        }
        let chemistry = UUID()
        let day = [
            b("Homeroom", 8, 0, 8, 15, "#8E8E93"),
            b("Econ & Personal Finance Honors", 8, 20, 9, 10, "#FF9500"),
            b("Chemistry", 9, 15, 10, 5, "#34C759", cycle: [0], group: chemistry),
            b("English", 10, 10, 11, 0, "#007AFF"),
            b("Lunch", 11, 5, 11, 35, "#FFD60A"),
            b("Calculus", 11, 40, 12, 30, "#AF52DE"),
            b("Studio Art", 12, 35, 13, 25, "#FF375F", cycle: [0]),
            b("Physics Lab", 12, 35, 13, 25, "#00C7BE", cycle: [1]),
            b("Study Hall", 13, 30, 14, 20, "#6D7B8D"),
            b("Chemistry", 14, 25, 15, 15, "#34C759", cycle: [1], group: chemistry),
        ]
        let rotating: (BlockStore) -> Void = { $0.setRotation(Rotation(length: 2, anchor: monday)) }

        let full = store("full", blocks: day, settings: rotating)
        let weekly = store("weekly", blocks: day) {
            $0.setRotation(Rotation(length: 2, anchor: monday, weekdayLetters: [nil, 0, 0, 1, 0, 0, nil]))
        }
        let empty = store("empty", blocks: [])
        // A/B switched to one schedule: Chemistry should show once, with its A Day times.
        let single = store("single", blocks: day, settings: rotating)
        single.setRotating(false, fresh: Rotation(length: 2, anchor: monday))
        let custom = store("custom", blocks: day, settings: rotating)
        custom.customizeTimes(on: CalendarDay(now))
        let swapped = store("swapped", blocks: day, settings: rotating)
        swapped.swapSchedule(on: CalendarDay(now), to: 1)
        func framed(_ v: some View) -> AnyView {
            AnyView(v.frame(width: 320).padding(.top, Bubble.arrowHeight)
                .background(Bubble(arrowX: 160).fill(Color(nsColor: .windowBackgroundColor))))
        }
        let off = store("off", blocks: day) { $0.addDayOff(DayOff(start: CalendarDay(now), end: CalendarDay(now).adding(days: 2))) }
        let clock = Clock(fixed: now)
        let prefs = Preferences()
        let alerts = EndAlerts()

        func panel(_ s: BlockStore, _ route: PanelRoute, weekday: Int? = nil) -> some View {
            ContentView(store: s, clock: clock, prefs: prefs, alerts: alerts, layout: PanelLayout(), route: route, dismiss: {})
        }

        // A 0.3 install with a late-start Wednesday, loaded through the real upgrade path.
        let legacyDir = FileManager.default.temporaryDirectory.appendingPathComponent("periodical-snap-legacy-\(UUID())")
        try? FileManager.default.createDirectory(at: legacyDir, withIntermediateDirectories: true)
        let legacyBlocks = [
            TimeBlock(name: "Intro to Computer Science", start: 445, end: 536, weekdays: [2, 3, 5, 6], color: "#7B4AE2"),
            TimeBlock(name: "Chemistry", start: 541, end: 632, weekdays: [2, 3, 5, 6], color: "#34C759"),
            TimeBlock(name: "Intro to Computer Science", start: 540, end: 600, weekdays: [4], color: "#7B4AE2"),
            TimeBlock(name: "Chemistry", start: 605, end: 665, weekdays: [4], color: "#34C759"),
            TimeBlock(name: "Advisory", start: 670, end: 700, weekdays: [4], color: "#FF9500"),
        ]
        try? JSONEncoder().encode(legacyBlocks).write(to: legacyDir.appendingPathComponent("timeblocks.json"))
        // The store keeps its note in the real defaults; put back whatever was there.
        let realNote = UserDefaults.standard.string(forKey: "migrationNote")
        UserDefaults.standard.removeObject(forKey: "migrationNote")
        let legacy = BlockStore(directory: legacyDir)
        let legacyNote = legacy.migrationNote
        UserDefaults.standard.set(realNote, forKey: "migrationNote")
        let migrated = store("migrated", blocks: legacy.blocks) { $0.configure(rotation: legacy.settings.rotation, classDays: legacy.settings.classDays) }
        print("legacy note:", legacyNote ?? "none")

        var shots: [(String, AnyView)] = [
            ("today", AnyView(panel(full, .schedule))),
            ("first-run", AnyView(panel(empty, .schedule))),
            ("day-off", AnyView(panel(off, .schedule))),
            ("edit", AnyView(panel(full, .edit(day[1], isNew: false, day: nil)))),
            ("add", AnyView(panel(full, .add))),
            ("settings", AnyView(panel(full, .settings))),
            ("settings-weekly", AnyView(panel(weekly, .settings))),
            ("onboard-1", AnyView(panel(empty, .onboarding))),
            ("onboard-names", framed(OnboardingView(store: empty, clock: clock, step: .names) { _ in })),
            ("onboard-assign", framed(OnboardingView(store: empty, clock: clock, step: .assign) { _ in })),
            ("onboard-assign-weekday", framed(OnboardingView(store: empty, clock: clock, step: .assign, byWeekday: true) { _ in })),
            ("onboard-done", framed(OnboardingView(store: empty, clock: clock, step: .done) { _ in })),
            ("add-reuse", framed(AddBlockFlow(clock: clock, store: full, day: CalendarDay(now), name: "chemistry") {})),
            ("add-suggest", framed(AddBlockFlow(clock: clock, store: full, day: CalendarDay(now), name: "Che") {})),
            ("add-slots", framed(AddBlockFlow(clock: clock, store: full, day: CalendarDay(now), name: "Spanish", step: .slots) {})),
            ("add-same", framed(AddBlockFlow(clock: clock, store: full, day: CalendarDay(now), name: "Spanish", step: .sameTimes) {})),
            ("add-time-b", framed(AddBlockFlow(clock: clock, store: full, day: CalendarDay(now), name: "Spanish", step: .start(1), sameTimes: false) {})),
            ("set-schedule", framed(SettingsView(store: full, clock: clock, prefs: prefs, alerts: alerts, back: {}, runSetup: {}))),
            ("set-weekly", framed(SettingsView(store: weekly, clock: clock, prefs: prefs, alerts: alerts, back: {}, runSetup: {}))),
            ("set-one", framed(SettingsView(store: empty, clock: clock, prefs: prefs, alerts: alerts, back: {}, runSetup: {}))),
            ("set-daysoff", framed(SettingsView(store: off, clock: clock, prefs: prefs, alerts: alerts, page: .daysOff, showCalendar: true, back: {}, runSetup: {}))),
            ("set-reminders", framed(SettingsView(store: full, clock: clock, prefs: prefs, alerts: alerts, page: .reminders, back: {}, runSetup: {}))),
            ("set-general", framed(SettingsView(store: full, clock: clock, prefs: prefs, alerts: alerts, page: .general, back: {}, runSetup: {}))),
            ("single-from-ab", AnyView(panel(single, .schedule))),
            ("single-edit", AnyView(panel(single, .edit(day[2], isNew: false, day: nil)))),
            ("migrated", AnyView(panel(migrated, .schedule))),
            ("migrated-settings", framed(SettingsView(store: migrated, clock: clock, prefs: prefs, alerts: alerts, back: {}, runSetup: {}))),
            ("migrated-edit", AnyView(panel(migrated, .edit(migrated.blocks[0], isNew: false, day: nil)))),
            ("edit-group", AnyView(panel(full, .edit(day[2], isNew: false, day: nil)))),
            ("custom-day", AnyView(panel(custom, .schedule))),
            ("swapped-day", AnyView(panel(swapped, .schedule))),
            ("today-weekly", AnyView(panel(weekly, .schedule))),
        ]
        // Deleted just now, to show the undo bar.
        let undo = store("undo", blocks: day)
        undo.delete(day[4])
        shots.append(("undo", AnyView(ContentView(store: undo, clock: Clock(fixed: Date()), prefs: prefs, alerts: alerts, layout: PanelLayout(), route: .schedule, dismiss: {}))))
        shots.append(("tomorrow", AnyView(ContentView(store: full, clock: Clock(fixed: cal.date(byAdding: .hour, value: -24 * 2 - 3, to: now)!), prefs: prefs, alerts: alerts, layout: PanelLayout(), route: .schedule, dismiss: {}))))

        for (name, view) in shots {
            for dark in [false, true] {
                render(view, to: outURL.appendingPathComponent("\(name)\(dark ? "-dark" : "").png"), dark: dark)
            }
        }
        print("Wrote \(shots.count * 2) snapshots to \(out)")
        return true
    }

    private static func render(_ view: AnyView, to url: URL, dark: Bool) {
        let host = NSHostingView(rootView: view.environment(\.colorScheme, dark ? .dark : .light))
        host.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let size = host.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = host.appearance
        window.backgroundColor = dark ? NSColor(white: 0.2, alpha: 1) : NSColor(white: 0.85, alpha: 1)
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = size
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
#endif
