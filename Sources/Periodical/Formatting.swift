import Foundation
import PeriodicalCore

enum RelativeDay {
    /// `8:00 AM`, `Tomorrow 8:00 AM`, `Mon 8:00 AM`, or `Nov 30 8:00 AM` beyond a week.
    static func string(for date: Date, now: Date, calendar: Calendar = .current) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDate(date, inSameDayAs: now) { return time }
        if calendar.isDateInTomorrow(date) { return "Tomorrow \(time)" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: date).day ?? 0
        if days < 7 { return "\(date.formatted(.dateTime.weekday(.abbreviated))) \(time)" }
        return "\(date.formatted(.dateTime.month(.abbreviated).day())) \(time)"
    }

    /// `Wednesday, Nov 4`.
    static func heading(for day: CalendarDay) -> String {
        day.date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    /// `Nov 4` or `Nov 4 – Nov 9`.
    static func range(_ off: DayOff) -> String {
        let style = Date.FormatStyle.dateTime.month(.abbreviated).day()
        let start = off.start.date().formatted(style)
        return off.start == off.end ? start : "\(start) – \(off.end.date().formatted(style))"
    }
}

extension DurationFormat {
    /// `50 min`, `1 hr`, `1 hr 30 min` for a block's length.
    static func length(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return "\(m) min"
        case (_, 0): return "\(h) hr"
        default: return "\(h) hr \(m) min"
        }
    }
}
