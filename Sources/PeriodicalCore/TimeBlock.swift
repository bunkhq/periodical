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
    /// Hex color string, e.g. `#FF3A3A`.
    public var color: String

    public init(id: UUID = UUID(), name: String, start: Int, end: Int, weekdays: Set<Int>, color: String) {
        self.id = id
        self.name = name
        self.start = start
        self.end = end
        self.weekdays = weekdays
        self.color = color
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

    public static func blocks(_ blocks: [TimeBlock], onWeekday weekday: Int) -> [TimeBlock] {
        blocks
            .filter { $0.weekdays.contains(weekday) }
            .sorted { ($0.start, $0.end, $0.name) < ($1.start, $1.end, $1.name) }
    }

    /// The block to show in the menu bar: the active one today, else the next one today.
    public static func current(_ blocks: [TimeBlock], now: Date, calendar: Calendar = .current) -> (TimeBlock, BlockPhase)? {
        let todays = Self.blocks(blocks, onWeekday: calendar.component(.weekday, from: now))
        let phased = todays.map { ($0, $0.phase(on: now, now: now, calendar: calendar)) }
        // Prefer the most recently started active block when blocks overlap.
        if let active = phased.last(where: { if case .active = $0.1 { return true }; return false }) {
            return active
        }
        return phased.first(where: { if case .upcoming = $0.1 { return true }; return false })
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
