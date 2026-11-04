import Foundation
import Testing
@testable import PeriodicalCore

private var calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/New_York")!
    return c
}()

/// Thursday 2026-10-22 10:15:40 in New York.
private let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 10, minute: 15, second: 40))!

private func parse(_ s: String) -> Int? { TimeParser.parse(s, now: now, calendar: calendar) }
private func hm(_ h: Int, _ m: Int) -> Int { h * 60 + m }

@Test(arguments: [
    ("9am", hm(9, 0)),
    ("at 9am", hm(9, 0)),
    ("9 AM", hm(9, 0)),
    ("9:45 a.m.", hm(9, 45)),
    ("12pm", hm(12, 0)),
    ("12am", hm(0, 0)),
    ("14:31", hm(14, 31)),
    ("1431", hm(14, 31)),
    ("930", hm(9, 30)),
    ("9.30", hm(9, 30)),
    ("2:15", hm(14, 15)),
    ("02:15", hm(2, 15)),
    ("3", hm(15, 0)),
    ("11", hm(11, 0)),
    ("noon", hm(12, 0)),
    ("midnight", hm(0, 0)),
    ("five mins past noon", hm(12, 5)),
    ("five past noon", hm(12, 5)),
    ("quarter to 3", hm(14, 45)),
    ("half past nine", hm(9, 30)),
    ("ten to midnight", hm(23, 50)),
    ("twelve thirty", hm(12, 30)),
    ("nine oh five", hm(9, 5)),
    ("eight in the evening", hm(20, 0)),
    ("7 o'clock in the morning", hm(7, 0)),
    ("in 30 minutes", hm(10, 46)),
    ("in 30 mins", hm(10, 46)),
    ("in 30", hm(10, 46)),
    ("in an hour", hm(11, 16)),
    ("in half an hour", hm(10, 46)),
    ("in an hour and a half", hm(11, 46)),
    ("in 1h30m", hm(11, 46)),
    ("in 2 hours and 5 minutes", hm(12, 21)),
    ("in five minutes", hm(10, 21)),
    ("20 minutes from now", hm(10, 36)),
    ("now", hm(10, 16)),
    // The edit form prefills the system's short time, which uses a narrow no-break space before AM/PM.
    ("9:05\u{202F}AM", hm(9, 5)),
    ("12:30 PM", hm(12, 30)),
])
func parses(input: String, expected: Int) {
    #expect(parse(input) == expected, "\(input)")
}

@Test(arguments: ["", "banana", "25:00", "9:75", "in a while"])
func rejects(input: String) {
    #expect(parse(input) == nil, "\(input)")
}

@Test(arguments: [
    ("45 minutes after", hm(9, 45)),
    ("after 45 minutes", hm(9, 45)),
    ("45 mins after start", hm(9, 45)),
    ("45", hm(9, 45)),
    ("45 min", hm(9, 45)),
    ("+20", hm(9, 20)),
    ("1h 30m", hm(10, 30)),
    ("an hour later", hm(10, 0)),
    ("half an hour after", hm(9, 30)),
    ("for 50 minutes", hm(9, 50)),
    ("in 30 minutes", hm(10, 46)),
    ("10:15", hm(10, 15)),
    ("3", hm(15, 0)),
    ("5 minutes after 3", hm(15, 5)),
])
func parsesRelativeToStart(input: String, expected: Int) {
    #expect(TimeParser.parse(input, now: now, calendar: calendar, reference: hm(9, 0)) == expected, "\(input)")
}

@Test func phases() {
    let block = TimeBlock(name: "Econ", start: hm(9, 0), end: hm(11, 42), weekdays: [5], color: "#FF3A3A")
    #expect(block.phase(on: now, now: now, calendar: calendar) == .active(seconds: 86 * 60 + 20))
    let later = TimeBlock(name: "Lunch", start: hm(12, 0), end: hm(12, 30), weekdays: [5], color: "#FF3A3A")
    #expect(later.phase(on: now, now: now, calendar: calendar) == .upcoming(seconds: 104 * 60 + 20))
    let earlier = TimeBlock(name: "Homeroom", start: hm(8, 0), end: hm(8, 10), weekdays: [5], color: "#FF3A3A")
    #expect(earlier.phase(on: now, now: now, calendar: calendar) == .passed)

    let current = Schedule.current([later, earlier, block], settings: ScheduleSettings(), now: now, calendar: calendar)
    #expect(current?.0.name == "Econ")
}

@Test func durations() {
    #expect(DurationFormat.string(seconds: 5214) == "1h 26m 54s")
    #expect(DurationFormat.string(seconds: 243) == "4m 3s")
    #expect(DurationFormat.string(seconds: 9) == "9s")
    #expect(DurationFormat.string(seconds: 2 * 86_400 + 3_600 * 3 + 240) == "2d 3h 4m")
}

@Test func nextWeekdayOccurrence() {
    let monday = Schedule.day(forWeekday: 2, now: now, calendar: calendar)
    #expect(calendar.dateComponents([.month, .day], from: monday) == DateComponents(month: 10, day: 26))
    let thursday = Schedule.day(forWeekday: 5, now: now, calendar: calendar)
    #expect(thursday == calendar.startOfDay(for: now))
}
