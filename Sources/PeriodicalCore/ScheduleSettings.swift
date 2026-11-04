import Foundation

/// A date without a time, stored as `2026-11-04`.
public struct CalendarDay: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    /// Midnight at the start of this day.
    public func date(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public func adding(days: Int, calendar: Calendar = .current) -> CalendarDay {
        CalendarDay(calendar.date(byAdding: .day, value: days, to: date(calendar: calendar))!, calendar: calendar)
    }

    /// Whole days from `self` to `other`; negative when `other` is earlier.
    public func days(to other: CalendarDay, calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: date(calendar: calendar), to: other.date(calendar: calendar)).day!
    }

    /// `Calendar` weekday: 1 = Sunday ... 7 = Saturday.
    public func weekday(calendar: Calendar = .current) -> Int {
        calendar.component(.weekday, from: date(calendar: calendar))
    }

    public static func < (a: CalendarDay, b: CalendarDay) -> Bool {
        (a.year, a.month, a.day) < (b.year, b.month, b.day)
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Expected yyyy-MM-dd, got \(text)"))
        }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

/// A run of days with no blocks: a snow day, a holiday, a break. Both ends are included.
public struct DayOff: Codable, Hashable, Sendable {
    public var start: CalendarDay
    public var end: CalendarDay

    public init(start: CalendarDay, end: CalendarDay) {
        self.start = min(start, end)
        self.end = max(start, end)
    }

    public func contains(_ day: CalendarDay) -> Bool {
        start <= day && day <= end
    }
}

/// A rotating schedule (A/B days, or up to six letters), in one of two styles:
/// - Alternating (the default): each school day takes the next letter. Weekends and days off are
///   skipped, so a snow day doesn't use up a letter.
/// - By weekday: each weekday always has the same letter, e.g. A on Mon, Tue, Thu, Fri and B on Wed.
public struct Rotation: Codable, Equatable, Sendable {
    public static let maxLength = 6

    /// Number of days in the cycle, 2...6.
    public var length: Int
    /// A day whose letter is known, so every other day can be counted from it.
    public var anchor: CalendarDay
    public var anchorIndex: Int
    /// `Calendar` weekdays that take a letter. Monday to Friday unless changed.
    public var schoolDays: Set<Int>
    /// Fixed letters by weekday, indexed Sunday (0) to Saturday (6); nil entries have no letter.
    /// When set, letters come from here and `anchor`, `anchorIndex`, and `schoolDays` are ignored.
    public var weekdayLetters: [Int?]?
    /// Optional names per letter, e.g. `Regular` and `Late Start`. Blank or missing names read `A Day`, `B Day`.
    public var names: [String]?

    public init(length: Int = 2, anchor: CalendarDay, anchorIndex: Int = 0, schoolDays: Set<Int> = [2, 3, 4, 5, 6], weekdayLetters: [Int?]? = nil, names: [String]? = nil) {
        self.length = min(max(length, 2), Self.maxLength)
        self.anchor = anchor
        self.anchorIndex = anchorIndex
        self.schoolDays = schoolDays
        self.weekdayLetters = weekdayLetters
        self.names = names
    }

    public static func defaultName(_ index: Int) -> String {
        "\(label(index)) Day"
    }

    /// The schedule's name: a custom one, else `A Day`.
    public func name(_ index: Int) -> String {
        let custom = names.flatMap { $0.indices.contains(index) ? $0[index] : nil }?.trimmingCharacters(in: .whitespaces)
        return custom?.isEmpty == false ? custom! : Self.defaultName(index)
    }

    /// One character for tight spots like the weekday circles: the names' initials when they're all
    /// different (`R`, `L` for Regular and Late Start), else the letter.
    public func shortName(_ index: Int) -> String {
        Self.shortNames(length: length, names: names)[index]
    }

    /// Short names for `length` schedules with these (possibly blank) names, before a rotation exists.
    public static func shortNames(length: Int, names: [String]?) -> [String] {
        let full = (0..<length).map { i -> String in
            let custom = names.flatMap { $0.indices.contains(i) ? $0[i] : nil }?.trimmingCharacters(in: .whitespaces) ?? ""
            return custom.isEmpty ? defaultName(i) : custom
        }
        let initials = full.map { $0.prefix(1).uppercased() }
        return Set(initials).count == length ? initials : (0..<length).map(label)
    }

    public var isByWeekday: Bool { weekdayLetters != nil }

    /// The fixed letter for a `Calendar` weekday, when letters are set by weekday.
    public func letter(forWeekday weekday: Int) -> Int? {
        guard let weekdayLetters, weekdayLetters.indices.contains(weekday - 1),
              let index = weekdayLetters[weekday - 1], index < length else { return nil }
        return index
    }

    /// `A`, `B`, `C`...
    public static func label(_ index: Int) -> String {
        String(UnicodeScalar(UInt8(65 + index)))
    }
}

/// A one-day exception: run a different rotation schedule, or replace the day's blocks outright.
public struct DayOverride: Codable, Hashable, Sendable {
    public var day: CalendarDay
    /// The rotation letter to run instead of the usual one.
    public var letter: Int?
    /// When set, the day runs exactly these blocks instead of its usual ones.
    public var blocks: [TimeBlock]?

    public init(day: CalendarDay, letter: Int? = nil, blocks: [TimeBlock]? = nil) {
        self.day = day
        self.letter = letter
        self.blocks = blocks
    }

    public var isEmpty: Bool { letter == nil && blocks == nil }
}

/// Schedule-wide settings that sit beside the blocks: the rotation, days off, and one-day changes.
public struct ScheduleSettings: Codable, Equatable, Sendable {
    /// 2 and up use schedules and grouped blocks; 1 (or a missing file) is Periodical 0.3 data
    /// that `LegacyMigration` still needs to move over.
    public static let currentVersion = 2

    public var version: Int
    public var rotation: Rotation?
    /// The rotation as it was when switched to one schedule, so switching back restores it.
    public var inactiveRotation: Rotation?
    public var daysOff: [DayOff]
    public var overrides: [DayOverride]
    /// `Calendar` weekdays with class, used as the default repeat days for new blocks.
    public var classDays: Set<Int>

    public init(version: Int = currentVersion, rotation: Rotation? = nil, inactiveRotation: Rotation? = nil, daysOff: [DayOff] = [], overrides: [DayOverride] = [], classDays: Set<Int> = [2, 3, 4, 5, 6]) {
        self.version = version
        self.rotation = rotation
        self.inactiveRotation = inactiveRotation
        self.daysOff = daysOff
        self.overrides = overrides
        self.classDays = classDays
    }

    private enum CodingKeys: String, CodingKey {
        case version, rotation, inactiveRotation, daysOff, overrides, classDays
    }

    // Fields added later default when missing, so older settings files still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        rotation = try c.decodeIfPresent(Rotation.self, forKey: .rotation)
        inactiveRotation = try c.decodeIfPresent(Rotation.self, forKey: .inactiveRotation)
        daysOff = try c.decodeIfPresent([DayOff].self, forKey: .daysOff) ?? []
        overrides = try c.decodeIfPresent([DayOverride].self, forKey: .overrides) ?? []
        classDays = try c.decodeIfPresent(Set<Int>.self, forKey: .classDays) ?? [2, 3, 4, 5, 6]
    }

    public func override(for day: CalendarDay) -> DayOverride? {
        overrides.first { $0.day == day }
    }

    public func isDayOff(_ day: CalendarDay) -> Bool {
        daysOff.contains { $0.contains(day) }
    }

    /// The day-off run covering `day`, if any.
    public func dayOff(containing day: CalendarDay) -> DayOff? {
        daysOff.first { $0.contains(day) }
    }

    /// The rotation letter index for `day`, or nil when there's no rotation or `day` isn't a school day.
    /// A day off still gets the letter it would have had, so its blocks can be shown as skipped.
    public func cycleIndex(for day: CalendarDay, calendar: Calendar = .current) -> Int? {
        guard let rotation else { return nil }
        if let letter = override(for: day)?.letter, letter < rotation.length { return letter }
        return usualCycleIndex(for: day, calendar: calendar)
    }

    /// The letter `day` gets from the rotation alone, ignoring a one-day schedule swap.
    public func usualCycleIndex(for day: CalendarDay, calendar: Calendar = .current) -> Int? {
        guard let rotation else { return nil }
        if rotation.isByWeekday { return rotation.letter(forWeekday: day.weekday(calendar: calendar)) }
        guard rotation.schoolDays.contains(day.weekday(calendar: calendar)) else { return nil }
        let offset = day >= rotation.anchor
            ? countedSchoolDays(from: rotation.anchor, to: day, rotation: rotation, calendar: calendar)
            : -countedSchoolDays(from: day, to: rotation.anchor, rotation: rotation, calendar: calendar)
        let n = rotation.length
        return ((rotation.anchorIndex + offset) % n + n) % n
    }

    /// School days in `[from, to)` that aren't days off.
    private func countedSchoolDays(from: CalendarDay, to: CalendarDay, rotation: Rotation, calendar: Calendar) -> Int {
        let total = from.days(to: to, calendar: calendar)
        guard total > 0 else { return 0 }
        var count = total / 7 * rotation.schoolDays.count
        let firstWeekday = from.weekday(calendar: calendar)
        // The leftover days start on the same weekday as `from`, since whole weeks don't move it.
        for i in 0..<(total % 7) where rotation.schoolDays.contains((firstWeekday - 1 + i) % 7 + 1) {
            count += 1
        }
        // Days off don't use up a letter. Overlapping runs are merged so a day isn't skipped twice.
        var skipped = Set<CalendarDay>()
        for off in daysOff where off.end >= from && off.start < to {
            var day = max(off.start, from)
            let last = min(off.end, to.adding(days: -1, calendar: calendar))
            while day <= last {
                if rotation.schoolDays.contains(day.weekday(calendar: calendar)) { skipped.insert(day) }
                day = day.adding(days: 1, calendar: calendar)
            }
        }
        return count - skipped.count
    }
}
