import Foundation
import Observation
import PeriodicalCore

/// Saved timeblocks and schedule settings, persisted as JSON in Application Support.
@Observable
final class BlockStore {
    private(set) var blocks: [TimeBlock] = []
    private(set) var settings = ScheduleSettings()
    /// The last deleted blocks, kept briefly so they can be put back. `day` is set for a one-day block.
    private(set) var recentlyDeleted: (blocks: [TimeBlock], at: Date, day: CalendarDay?)?
    /// What a one-time upgrade from an older version changed, shown until dismissed.
    private(set) var migrationNote: String? = UserDefaults.standard.string(forKey: BlockStore.migrationNoteKey)
    @ObservationIgnored var onChange: (() -> Void)?

    private static let migrationNoteKey = "migrationNote"

    @ObservationIgnored private let directory: URL

    /// Blocks keep their own file so older versions of the app can still read it.
    private var blocksURL: URL { directory.appendingPathComponent("timeblocks.json") }
    private var settingsURL: URL { directory.appendingPathComponent("settings.json") }

    /// Where the schedule lives by default: `~/Library/Application Support/Periodical` for the installed app.
    /// Development builds (bundle id ending in `.dev`, as `scripts/dev.sh` makes, or `swift run` with no bundle)
    /// use `Periodical Dev` instead, so resetting a dev build never touches the real schedule.
    static var defaultDirectory: URL {
        let id = Bundle.main.bundleIdentifier
        let isDev = id == nil || id!.hasSuffix(".dev")
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(isDev ? "Periodical Dev" : "Periodical", isDirectory: true)
    }

    /// `directory` defaults to `defaultDirectory`.
    init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.directory = dir
        if let data = try? Data(contentsOf: blocksURL),
           let saved = try? JSONDecoder().decode([TimeBlock].self, from: data) {
            blocks = saved
        }
        if let data = try? Data(contentsOf: settingsURL),
           let saved = try? JSONDecoder().decode(ScheduleSettings.self, from: data) {
            settings = saved
        } else if !blocks.isEmpty {
            // Blocks without a settings file come from Periodical 0.3 or earlier.
            settings.version = 1
        }
        if settings.version < ScheduleSettings.currentVersion { migrate() }
    }

    /// Moves older data to the current structure, keeping a copy of the original files beside them.
    private func migrate() {
        let fm = FileManager.default
        for url in [blocksURL, settingsURL] where fm.fileExists(atPath: url.path) {
            let backup = url.deletingPathExtension().appendingPathExtension("v\(settings.version)-backup.json")
            if !fm.fileExists(atPath: backup.path) { try? fm.copyItem(at: url, to: backup) }
        }
        let result = LegacyMigration.migrate(blocks, settings: settings, today: CalendarDay(Date()))
        blocks = result.blocks
        settings = result.settings
        saveBlocks()
        saveSettings()
        if let summary = result.summary {
            migrationNote = summary
            UserDefaults.standard.set(summary, forKey: Self.migrationNoteKey)
        }
    }

    func dismissMigrationNote() {
        migrationNote = nil
        UserDefaults.standard.removeObject(forKey: Self.migrationNoteKey)
    }

    // MARK: - Blocks

    /// Adds a block to the regular schedule, or to `day` alone when that day has its own blocks.
    func add(_ block: TimeBlock, on day: CalendarDay? = nil) {
        recentlyDeleted = nil
        if let day {
            editCustomBlocks(on: day) { $0.append(block) }
        } else {
            blocks.append(block)
            saveBlocks()
        }
    }

    func update(_ block: TimeBlock, on day: CalendarDay? = nil) {
        if let day {
            editCustomBlocks(on: day) { list in
                if let i = list.firstIndex(where: { $0.id == block.id }) { list[i] = block } else { list.append(block) }
            }
            return
        }
        guard let i = blocks.firstIndex(where: { $0.id == block.id }) else { return add(block) }
        blocks[i] = block
        saveBlocks()
    }

    /// Deletes one of a day's own blocks, or a regular block along with the rest of its group.
    func delete(_ block: TimeBlock, on day: CalendarDay? = nil) {
        if let day {
            recentlyDeleted = ([block], Date(), day)
            editCustomBlocks(on: day) { $0.removeAll { $0.id == block.id } }
        } else {
            let group = self.group(of: block)
            recentlyDeleted = (group, Date(), nil)
            blocks.removeAll { $0.groupKey == block.groupKey }
            saveBlocks()
        }
    }

    func undoDelete() {
        guard let (deleted, _, day) = recentlyDeleted else { return }
        recentlyDeleted = nil
        if let day {
            deleted.forEach { add($0, on: day) }
        } else {
            blocks.append(contentsOf: deleted)
            saveBlocks()
        }
    }

    /// Every regular block in `block`'s group, itself included.
    func group(of block: TimeBlock) -> [TimeBlock] {
        let members = blocks.filter { $0.groupKey == block.groupKey }
        return members.isEmpty ? [block] : members
    }

    /// Adds several blocks at once, e.g. one class with different times per schedule.
    func add(_ newBlocks: [TimeBlock]) {
        recentlyDeleted = nil
        blocks.append(contentsOf: newBlocks)
        saveBlocks()
    }

    /// Swaps a group's blocks for `replacement`, keeping their place in the list.
    func replaceGroup(_ key: UUID, with replacement: [TimeBlock]) {
        let index = blocks.firstIndex { $0.groupKey == key } ?? blocks.endIndex
        blocks.removeAll { $0.groupKey == key }
        blocks.insert(contentsOf: replacement, at: min(index, blocks.endIndex))
        saveBlocks()
    }

    func forgetDeleted() {
        recentlyDeleted = nil
    }


    // MARK: - One-day changes

    /// Runs `letter`'s schedule on `day` instead of its usual one. Nil goes back to the usual one.
    func swapSchedule(on day: CalendarDay, to letter: Int?) {
        editOverride(on: day) { $0.letter = letter }
    }

    /// Gives `day` its own copy of its blocks to change freely, without touching any other day.
    func customizeTimes(on day: CalendarDay) {
        guard settings.override(for: day)?.blocks == nil else { return }
        let copies = Schedule.blocks(blocks, on: day, settings: settings).map { block in
            var copy = block
            copy.id = UUID()
            return copy
        }
        editOverride(on: day) { $0.blocks = copies }
    }

    /// Drops `day`'s own blocks so it runs its usual ones again.
    func resetTimes(on day: CalendarDay) {
        editOverride(on: day) { $0.blocks = nil }
    }

    private func editCustomBlocks(on day: CalendarDay, _ change: (inout [TimeBlock]) -> Void) {
        editOverride(on: day) { override in
            var list = override.blocks ?? []
            change(&list)
            override.blocks = list
        }
    }

    private func editOverride(on day: CalendarDay, _ change: (inout DayOverride) -> Void) {
        var override = settings.override(for: day) ?? DayOverride(day: day)
        change(&override)
        settings.overrides.removeAll { $0.day == day }
        if !override.isEmpty { settings.overrides.append(override) }
        saveSettings()
    }

    // MARK: - Settings

    /// Saves the choices from first-run setup.
    func configure(rotation: Rotation?, classDays: Set<Int>) {
        // Picking one schedule keeps the old rotation aside, so it can come back.
        if rotation == nil, let current = settings.rotation { settings.inactiveRotation = current }
        if rotation != nil { settings.inactiveRotation = nil }
        settings.rotation = rotation
        settings.classDays = classDays
        saveSettings()
    }

    /// Switches between one schedule and several, keeping the rotation (names, style, which day is
    /// which, per-schedule block times) so switching back restores it. `fresh` is used the first time.
    func setRotating(_ on: Bool, fresh: @autoclosure () -> Rotation) {
        if on {
            guard settings.rotation == nil else { return }
            settings.rotation = settings.inactiveRotation ?? fresh()
            settings.inactiveRotation = nil
        } else {
            guard let current = settings.rotation else { return }
            settings.inactiveRotation = current
            settings.rotation = nil
        }
        saveSettings()
    }

    func setRotation(_ rotation: Rotation?) {
        settings.rotation = rotation
        saveSettings()
    }

    func setClassDays(_ days: Set<Int>) {
        settings.classDays = days
        saveSettings()
    }

    func addDayOff(_ dayOff: DayOff) {
        settings.daysOff.append(dayOff)
        saveSettings()
    }

    func removeDayOff(_ dayOff: DayOff) {
        settings.daysOff.removeAll { $0 == dayOff }
        saveSettings()
    }

    /// Ends any day-off run covering `day`, keeping the days before it.
    func resume(on day: CalendarDay) {
        settings.daysOff = settings.daysOff.compactMap { off in
            guard off.contains(day) else { return off }
            return off.start < day ? DayOff(start: off.start, end: day.adding(days: -1)) : nil
        }
        saveSettings()
    }

    // MARK: - Saving

    private func saveBlocks() {
        write(blocks, to: blocksURL)
    }

    private func saveSettings() {
        write(settings, to: settingsURL)
    }

    private func write(_ value: some Encodable, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(value) {
            try? data.write(to: url, options: .atomic)
        }
        onChange?()
    }
}

/// App preferences in UserDefaults, observable so the panel and the right-click menu stay in sync.
@Observable
final class Preferences {
    @ObservationIgnored var onChange: (() -> Void)?

    /// When on, the block color fills the whole rounded menu bar button instead of a box inside it. Off by default.
    var fillMenuBarButton: Bool {
        didSet { save(fillMenuBarButton, "fillMenuBarButton") }
    }

    /// When on, the block name follows the timer in the menu bar button. On by default.
    var showNameInMenuBar: Bool {
        didSet { save(showNameInMenuBar, "showCourseNameInMenuBar") }
    }

    /// Whether first-run setup has been finished or skipped.
    var hasOnboarded: Bool {
        didSet { save(hasOnboarded, "hasOnboarded") }
    }

    /// Minutes before a block ends to post a reminder. 0 turns reminders off.
    var endAlertMinutes: Int {
        didSet { save(endAlertMinutes, "endAlertMinutes") }
    }

    static let endAlertChoices = [0, 1, 2, 5, 10]

    init() {
        let defaults = UserDefaults.standard
        fillMenuBarButton = defaults.bool(forKey: "fillMenuBarButton")
        showNameInMenuBar = defaults.object(forKey: "showCourseNameInMenuBar") as? Bool ?? true
        endAlertMinutes = defaults.integer(forKey: "endAlertMinutes")
        hasOnboarded = defaults.bool(forKey: "hasOnboarded")
    }

    private func save(_ value: Any, _ key: String) {
        UserDefaults.standard.set(value, forKey: key)
        onChange?()
    }
}

/// Publishes the current time once per second, on the second.
@Observable
final class Clock {
    private(set) var now = Date()
    @ObservationIgnored private var listeners: [() -> Void] = []

    init() {
        let nextSecond = Date(timeIntervalSinceReferenceDate: floor(Date().timeIntervalSinceReferenceDate) + 1)
        let timer = Timer(fire: nextSecond, interval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        timer.tolerance = 0.05
        // .common keeps ticking while menus and scroll views are tracking.
        RunLoop.main.add(timer, forMode: .common)
    }

    #if DEBUG
    /// A clock stopped at `now`, for snapshots.
    init(fixed now: Date) {
        self.now = now
    }
    #endif

    func onTick(_ listener: @escaping () -> Void) {
        listeners.append(listener)
    }

    private func tick() {
        now = Date()
        listeners.forEach { $0() }
    }
}
