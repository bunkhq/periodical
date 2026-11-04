import Foundation

/// Brings data from Periodical 0.3 and earlier (blocks that repeat on weekdays, no schedules)
/// into the current structure.
///
/// Each weekday's lineup of blocks is compared. Weekdays with the same lineup run the same schedule:
/// - One lineup: stays "Same every day" on those weekdays.
/// - Two to six: becomes a rotation where each weekday has its schedule (A is the most common lineup;
///   a schedule used on a single weekday is named after it, e.g. "Wednesday").
/// - More than six: too varied to sort, so blocks stay on their weekdays.
///
/// Either way, blocks with the same name become one block (one shared group ID) with its times per
/// schedule or weekday. A name that appears twice in one day (two lunches) stays two blocks.
public enum LegacyMigration {
    public struct Result {
        public var blocks: [TimeBlock]
        public var settings: ScheduleSettings
        /// What changed, to tell the user once. Nil when nothing needed moving.
        public var summary: String?
    }

    public static func migrate(_ blocks: [TimeBlock], settings: ScheduleSettings, today: CalendarDay, calendar: Calendar = .current) -> Result {
        var settings = settings
        settings.version = ScheduleSettings.currentVersion

        // Already in the new shape (or nothing to move): just record the version.
        guard !blocks.isEmpty, settings.rotation == nil, settings.inactiveRotation == nil,
              !blocks.contains(where: { $0.cycleDays != nil || $0.groupID != nil }) else {
            return Result(blocks: blocks, settings: settings, summary: nil)
        }

        // A class is a name, plus which occurrence of it in the day (for a name used twice in a day).
        struct ClassKey: Hashable {
            let name: String
            let occurrence: Int
        }
        struct Entry: Hashable {
            let key: ClassKey
            let range: TimeRange
        }
        var lineups: [Int: [Entry]] = [:]
        var sources: [ClassKey: [TimeBlock]] = [:]
        var classOrder: [ClassKey] = []

        for weekday in weekOrder {
            let todays = blocks.filter { $0.weekdays.contains(weekday) }
                .sorted { ($0.start, $0.end, $0.name) < ($1.start, $1.end, $1.name) }
            var seen: [String: Int] = [:]
            var entries: [Entry] = []
            for block in todays {
                let name = block.name.trimmingCharacters(in: .whitespaces).lowercased()
                let key = ClassKey(name: name, occurrence: seen[name, default: 0])
                seen[name, default: 0] += 1
                entries.append(Entry(key: key, range: TimeRange(start: block.start, end: block.end)))
                if sources[key] == nil { classOrder.append(key) }
                if !(sources[key]?.contains { $0.id == block.id } ?? false) { sources[key, default: []].append(block) }
            }
            if !entries.isEmpty { lineups[weekday] = entries }
        }

        let classDays = Set(lineups.keys)
        guard !classDays.isEmpty else { return Result(blocks: blocks, settings: settings, summary: nil) }

        // Weekdays with identical lineups share a schedule. Most-used first, then Monday-first.
        var distinct: [[Entry]] = []
        for weekday in [2, 3, 4, 5, 6, 7, 1] {
            guard let lineup = lineups[weekday], !distinct.contains(lineup) else { continue }
            distinct.append(lineup)
        }
        let daysFor: ([Entry]) -> [Int] = { lineup in weekOrder.filter { lineups[$0] == lineup } }
        distinct = distinct.enumerated()
            .sorted { a, b in
                let (da, db) = (daysFor(a.element).count, daysFor(b.element).count)
                return da != db ? da > db : a.offset < b.offset
            }
            .map(\.element)

        func display(_ key: ClassKey) -> (name: String, color: String, ids: [UUID]) {
            let originals = sources[key] ?? []
            let colors = originals.map(\.color)
            // The color used most, and the first one on a tie.
            let color = colors.max { a, b in
                let (ca, cb) = (colors.filter { $0 == a }.count, colors.filter { $0 == b }.count)
                return ca != cb ? ca < cb : colors.firstIndex(of: a)! > colors.firstIndex(of: b)!
            } ?? "#8E8E93"
            return (originals.first?.name.trimmingCharacters(in: .whitespaces) ?? key.name, color, originals.map(\.id))
        }

        var newBlocks: [TimeBlock] = []
        let summary: String

        if distinct.count >= 2 && distinct.count <= Rotation.maxLength {
            var letters: [Int?] = Array(repeating: nil, count: 7)
            for (index, lineup) in distinct.enumerated() {
                for weekday in daysFor(lineup) { letters[weekday - 1] = index }
            }
            let names = distinct.map { lineup -> String in
                let days = daysFor(lineup)
                return days.count == 1 ? Calendar.current.weekdaySymbols[days[0] - 1] : ""
            }
            let rotation = Rotation(
                length: distinct.count,
                anchor: today,
                schoolDays: classDays,
                weekdayLetters: letters,
                names: names.contains { !$0.isEmpty } ? names : nil
            )
            settings.rotation = rotation

            for key in classOrder {
                var times: [Int: TimeRange] = [:]
                for (index, lineup) in distinct.enumerated() {
                    if let entry = lineup.first(where: { $0.key == key }) { times[index] = entry.range }
                }
                let (name, color, ids) = display(key)
                newBlocks += BlockGroups.make(name: name, color: color, times: times, order: Array(0..<distinct.count),
                                              bySchedule: true, key: ids.first ?? UUID(), ids: ids, schoolDays: classDays)
            }
            let described = distinct.enumerated().map { index, lineup in
                // A schedule named after its one weekday already says which day it is.
                daysFor(lineup).count == 1 ? rotation.name(index) : "\(rotation.name(index)) (\(dayList(daysFor(lineup))))"
            }
            summary = "Periodical now sorts your week into schedules. It found \(distinct.count): "
                + described.formatted(.list(type: .and))
                + ". Blocks with the same name are now one block with its times on each schedule."
        } else {
            // One lineup, or too many to sort: blocks stay on weekdays, one block per class.
            for key in classOrder {
                var times: [Int: TimeRange] = [:]
                for (weekday, lineup) in lineups {
                    if let entry = lineup.first(where: { $0.key == key }) { times[weekday] = entry.range }
                }
                let (name, color, ids) = display(key)
                newBlocks += BlockGroups.make(name: name, color: color, times: times, order: Array(1...7),
                                              bySchedule: false, key: ids.first ?? UUID(), ids: ids, schoolDays: classDays)
            }
            summary = distinct.count == 1
                ? "Your blocks moved over: the same schedule on \(dayList(weekOrder.filter(classDays.contains))). If your school has A/B days, set them up in Settings."
                : "Your days were too varied to sort into schedules, so blocks stay on their weekdays. You can set up schedules in Settings."
        }

        settings.classDays = classDays
        return Result(blocks: newBlocks, settings: settings, summary: summary)
    }

    /// Sunday to Saturday.
    private static let weekOrder = Array(1...7)

    /// Weekday names in the user's language, e.g. "Mon, Tue, and Thu".
    private static func dayList(_ days: [Int]) -> String {
        days.map { Calendar.current.shortWeekdaySymbols[$0 - 1] }.formatted(.list(type: .and))
    }
}
