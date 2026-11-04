import Foundation

/// A recurring block of time on one or more days of the week.
public struct TimeBlock: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    /// Minutes since midnight.
    public var start: Int
    /// Minutes since midnight. Always greater than `start`.
    public var end: Int
    /// `Calendar` weekdays: 1 = Sunday ... 7 = Saturday.
    public var weekdays: Set<Int>
    /// Rotation letters (0 = A) the block repeats on instead of `weekdays`. Nil repeats by weekday.
    /// Without a rotation set up, the block falls back to `weekdays`.
    public var cycleDays: Set<Int>?
    /// Hex color string, e.g. `#FF3A3A`.
    public var color: String
    /// Links blocks that are one class with different times on different schedules
    /// (Chemistry at 9:00 on A days and 10:15 on B days). Nil for a block on its own.
    public var groupID: UUID?

    public init(id: UUID = UUID(), name: String, start: Int, end: Int, weekdays: Set<Int>, cycleDays: Set<Int>? = nil, color: String, groupID: UUID? = nil) {
        self.id = id
        self.name = name
        self.start = start
        self.end = end
        self.weekdays = weekdays
        self.cycleDays = cycleDays
        self.color = color
        self.groupID = groupID
    }

    /// The same for every block in a group; a lone block is its own group.
    public var groupKey: UUID { groupID ?? id }

    public var minutes: Int { end - start }

    /// Whether the block is on the schedule for `day`. Days off don't change the answer; callers check them.
    public func occurs(on day: CalendarDay, settings: ScheduleSettings, calendar: Calendar = .current) -> Bool {
        if let cycleDays, settings.rotation != nil {
            guard let index = settings.cycleIndex(for: day, calendar: calendar) else { return false }
            return cycleDays.contains(index)
        }
        return weekdays.contains(day.weekday(calendar: calendar))
    }

    public func interval(on day: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let dayStart = calendar.startOfDay(for: day)
        let s = calendar.date(byAdding: .minute, value: start, to: dayStart)!
        let e = calendar.date(byAdding: .minute, value: end, to: dayStart)!
        return (s, e)
    }

    public func phase(on day: Date, now: Date, calendar: Calendar = .current) -> BlockPhase {
        let (s, e) = interval(on: day, calendar: calendar)
        if now < s { return .upcoming(seconds: Self.seconds(until: s, from: now)) }
        if now < e { return .active(seconds: Self.seconds(until: e, from: now)) }
        return .passed
    }

    private static func seconds(until target: Date, from now: Date) -> Int {
        // Ticks land just after whole seconds; the epsilon keeps that jitter from adding a second.
        max(1, Int(ceil(target.timeIntervalSince(now) - 0.01)))
    }
}

public enum BlockPhase: Equatable, Sendable {
    case upcoming(seconds: Int)
    case active(seconds: Int)
    case passed
}

public enum Schedule {
    /// Start of the next occurrence of `weekday` (today if it matches).
    public static func day(forWeekday weekday: Int, now: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        let offset = (weekday - calendar.component(.weekday, from: now) + 7) % 7
        return calendar.date(byAdding: .day, value: offset, to: today)!
    }

    /// Blocks on `day`, in time order: the day's custom blocks if it has them, else the usual ones.
    /// Includes days off, so a skipped day can still show what it skips.
    public static func blocks(_ blocks: [TimeBlock], on day: CalendarDay, settings: ScheduleSettings, calendar: Calendar = .current) -> [TimeBlock] {
        let usual = settings.rotation == nil ? withoutScheduleCopies(blocks) : blocks
        let source = settings.override(for: day)?.blocks ?? usual.filter { $0.occurs(on: day, settings: settings, calendar: calendar) }
        return source.sorted { ($0.start, $0.end, $0.name) < ($1.start, $1.end, $1.name) }
    }

    /// With no rotation, a block that has different times per schedule would otherwise show once per
    /// schedule every day. Keeps one per group instead: the times from its first schedule (A before B).
    /// Weekday blocks pass through untouched.
    public static func withoutScheduleCopies(_ blocks: [TimeBlock]) -> [TimeBlock] {
        var kept: [UUID: TimeBlock] = [:]
        var result: [TimeBlock] = []
        for block in blocks {
            guard let cycle = block.cycleDays else {
                result.append(block)
                continue
            }
            let rank = (cycle.min() ?? Int.max, block.start)
            if let current = kept[block.groupKey], ((current.cycleDays?.min() ?? Int.max), current.start) <= rank { continue }
            kept[block.groupKey] = block
        }
        return result + blocks.filter { block in kept[block.groupKey]?.id == block.id }
    }

    /// The usual blocks for `day`, ignoring any custom blocks set for it.
    public static func usualBlocks(_ blocks: [TimeBlock], on day: CalendarDay, settings: ScheduleSettings, calendar: Calendar = .current) -> [TimeBlock] {
        var plain = settings
        plain.overrides.removeAll { $0.day == day && $0.blocks != nil }
        return Self.blocks(blocks, on: day, settings: plain, calendar: calendar)
    }

    /// The block to show in the menu bar: the active one today, else the next one today. Nil on a day off.
    public static func current(_ blocks: [TimeBlock], settings: ScheduleSettings, now: Date, calendar: Calendar = .current) -> (TimeBlock, BlockPhase)? {
        let today = CalendarDay(now, calendar: calendar)
        guard !settings.isDayOff(today) else { return nil }
        let todays = Self.blocks(blocks, on: today, settings: settings, calendar: calendar)
        let phased = todays.map { ($0, $0.phase(on: now, now: now, calendar: calendar)) }
        // Prefer the most recently started active block when blocks overlap.
        if let active = phased.last(where: { if case .active = $0.1 { return true }; return false }) {
            return active
        }
        return phased.first(where: { if case .upcoming = $0.1 { return true }; return false })
    }

    /// The first block starting after `now`, looking up to `days` ahead and skipping days off.
    public static func next(_ blocks: [TimeBlock], settings: ScheduleSettings, after now: Date, days: Int = 21, calendar: Calendar = .current) -> (block: TimeBlock, start: Date)? {
        let today = CalendarDay(now, calendar: calendar)
        for offset in 0...days {
            let day = today.adding(days: offset, calendar: calendar)
            guard !settings.isDayOff(day) else { continue }
            let dayStart = day.date(calendar: calendar)
            for block in Self.blocks(blocks, on: day, settings: settings, calendar: calendar) {
                let start = block.interval(on: dayStart, calendar: calendar).start
                if start > now { return (block, start) }
            }
        }
        return nil
    }
}

public enum DurationFormat {
    /// `1h 26m 54s`, `4m 3s`, `12s`, or `2d 3h 4m` for long spans.
    public static func string(seconds total: Int) -> String {
        let d = total / 86_400
        let h = total % 86_400 / 3_600
        let m = total % 3_600 / 60
        let s = total % 60
        if d > 0 { return "\(d)d \(h)h \(m)m" }
        if h > 0 { return "\(h)h \(m)m \(s)s" }
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }
}
