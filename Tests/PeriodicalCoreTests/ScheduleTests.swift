import Foundation
import Testing
@testable import PeriodicalCore

private var calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/New_York")!
    return c
}()

private func day(_ month: Int, _ d: Int) -> CalendarDay { CalendarDay(year: 2026, month: month, day: d) }

private func at(_ month: Int, _ d: Int, _ h: Int, _ m: Int) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: d, hour: h, minute: m))!
}

/// A/B rotation where Monday 2026-11-02 is an A day.
private let ab = Rotation(length: 2, anchor: day(11, 2), anchorIndex: 0)

@Test func rotationAlternatesSchoolDaysAndSkipsWeekends() {
    let settings = ScheduleSettings(rotation: ab)
    let letters = (2...9).map { settings.cycleIndex(for: day(11, $0), calendar: calendar) }
    // Mon A, Tue B, Wed A, Thu B, Fri A, Sat –, Sun –, Mon B
    #expect(letters == [0, 1, 0, 1, 0, nil, nil, 1])
}

@Test func rotationCountsBackwardsFromTheAnchor() {
    let settings = ScheduleSettings(rotation: ab)
    #expect(settings.cycleIndex(for: day(10, 30), calendar: calendar) == 1) // Fri
    #expect(settings.cycleIndex(for: day(10, 29), calendar: calendar) == 0) // Thu
}

@Test func daysOffDoNotUseUpALetter() {
    let settings = ScheduleSettings(rotation: ab, daysOff: [DayOff(start: day(11, 4), end: day(11, 4))])
    #expect(settings.cycleIndex(for: day(11, 4), calendar: calendar) == 0) // the A it would have been
    #expect(settings.cycleIndex(for: day(11, 5), calendar: calendar) == 0) // Thu takes Wed's A
    #expect(settings.cycleIndex(for: day(11, 6), calendar: calendar) == 1)
}

@Test func daysOffBeforeTheAnchorAreSkippedToo() {
    let settings = ScheduleSettings(rotation: ab, daysOff: [DayOff(start: day(10, 30), end: day(10, 30))])
    #expect(settings.cycleIndex(for: day(10, 29), calendar: calendar) == 1)
}

@Test func overlappingDaysOffCountOnce() {
    let settings = ScheduleSettings(rotation: ab, daysOff: [
        DayOff(start: day(11, 3), end: day(11, 4)),
        DayOff(start: day(11, 4), end: day(11, 4)),
    ])
    #expect(settings.cycleIndex(for: day(11, 5), calendar: calendar) == 1)
}

@Test func cycleBlocksFallBackToWeekdaysWithoutARotation() {
    let block = TimeBlock(name: "Lab", start: 600, end: 650, weekdays: [3], cycleDays: [1], color: "#000000")
    #expect(block.occurs(on: day(11, 3), settings: ScheduleSettings(), calendar: calendar))
    #expect(!block.occurs(on: day(11, 2), settings: ScheduleSettings(), calendar: calendar))
    // With the rotation, Mon 11-02 is A and Tue 11-03 is B.
    let rotating = ScheduleSettings(rotation: ab)
    #expect(block.occurs(on: day(11, 3), settings: rotating, calendar: calendar))
    #expect(!block.occurs(on: day(11, 4), settings: rotating, calendar: calendar))
}

@Test func nothingIsCurrentOnADayOff() {
    let block = TimeBlock(name: "Math", start: 9 * 60, end: 10 * 60, weekdays: [4], color: "#000000")
    let off = ScheduleSettings(daysOff: [DayOff(start: day(11, 4), end: day(11, 4))])
    #expect(Schedule.current([block], settings: ScheduleSettings(), now: at(11, 4, 8, 0), calendar: calendar) != nil)
    #expect(Schedule.current([block], settings: off, now: at(11, 4, 8, 0), calendar: calendar) == nil)
}

@Test func nextSkipsDaysOffAndLooksAhead() {
    let math = TimeBlock(name: "Math", start: 9 * 60, end: 10 * 60, weekdays: [2, 3, 4, 5, 6], color: "#000000")
    let off = ScheduleSettings(daysOff: [DayOff(start: day(11, 5), end: day(11, 6))])
    // Wednesday after school: Thu and Fri are off, so next is Monday.
    let next = Schedule.next([math], settings: off, after: at(11, 4, 15, 0), calendar: calendar)
    #expect(next?.start == at(11, 9, 9, 0))
}

@Test func calendarDayEncodesAsADateString() throws {
    let data = try JSONEncoder().encode(DayOff(start: day(11, 4), end: day(11, 6)))
    #expect(String(decoding: data, as: UTF8.self).contains(#""start":"2026-11-04""#))
    #expect(try JSONDecoder().decode(DayOff.self, from: data) == DayOff(start: day(11, 4), end: day(11, 6)))
}

@Test func oldBlocksWithoutCycleDaysStillDecode() throws {
    let json = ##"[{"id":"9B0C6F9A-3C55-4B8C-9E3A-2F7C1D0E5A11","name":"Econ","start":540,"end":590,"weekdays":[2,4],"color":"#FF3A3A"}]"##
    let blocks = try JSONDecoder().decode([TimeBlock].self, from: Data(json.utf8))
    #expect(blocks.first?.cycleDays == nil)
}

@Test func lettersCanBeFixedByWeekday() {
    // A on Mon, Tue, Thu, Fri; B on Wed; nothing on weekends.
    let fixed = Rotation(length: 2, anchor: day(11, 2), weekdayLetters: [nil, 0, 0, 1, 0, 0, nil])
    let settings = ScheduleSettings(rotation: fixed, daysOff: [DayOff(start: day(11, 3), end: day(11, 3))])
    let letters = (2...9).map { settings.cycleIndex(for: day(11, $0), calendar: calendar) }
    // Days off don't shift anything: Wednesday is always B.
    #expect(letters == [0, 0, 1, 0, 0, nil, nil, 0])
}

@Test func weekdayLettersPastTheCycleLengthAreIgnored() {
    let fixed = Rotation(length: 2, anchor: day(11, 2), weekdayLetters: [nil, 0, 1, 2, 0, 1, nil])
    #expect(ScheduleSettings(rotation: fixed).cycleIndex(for: day(11, 4), calendar: calendar) == nil)
}

@Test func aDayCanRunADifferentSchedule() {
    let a = TimeBlock(name: "Chem", start: 540, end: 590, weekdays: [], cycleDays: [0], color: "#000000")
    let b = TimeBlock(name: "Art", start: 540, end: 590, weekdays: [], cycleDays: [1], color: "#000000")
    var settings = ScheduleSettings(rotation: ab)
    #expect(Schedule.blocks([a, b], on: day(11, 4), settings: settings, calendar: calendar).map(\.name) == ["Chem"])
    settings.overrides = [DayOverride(day: day(11, 4), letter: 1)]
    #expect(Schedule.blocks([a, b], on: day(11, 4), settings: settings, calendar: calendar).map(\.name) == ["Art"])
    // A one-day swap doesn't move the rest of the rotation.
    #expect(settings.cycleIndex(for: day(11, 5), calendar: calendar) == 1)
}

@Test func aDayCanHaveItsOwnBlocks() {
    let usual = TimeBlock(name: "Chem", start: 540, end: 590, weekdays: [4], color: "#000000")
    let assembly = TimeBlock(name: "Assembly", start: 480, end: 540, weekdays: [], color: "#000000")
    let settings = ScheduleSettings(overrides: [DayOverride(day: day(11, 4), blocks: [usual, assembly])])
    #expect(Schedule.blocks([usual], on: day(11, 4), settings: settings, calendar: calendar).map(\.name) == ["Assembly", "Chem"])
    #expect(Schedule.usualBlocks([usual], on: day(11, 4), settings: settings, calendar: calendar).map(\.name) == ["Chem"])
    #expect(Schedule.blocks([usual], on: day(11, 11), settings: settings, calendar: calendar).map(\.name) == ["Chem"])
}

@Test func settingsWithoutNewerFieldsStillDecode() throws {
    let json = #"{"daysOff":[]}"#
    let settings = try JSONDecoder().decode(ScheduleSettings.self, from: Data(json.utf8))
    #expect(settings.overrides.isEmpty && settings.classDays == [2, 3, 4, 5, 6])
}

@Test func rotationNamesFallBackToLetters() {
    let named = Rotation(length: 2, anchor: day(11, 2), names: ["Regular", " "])
    #expect(named.name(0) == "Regular" && named.name(1) == "B Day")
    #expect(named.shortName(0) == "R" && named.shortName(1) == "B")
    let clash = Rotation(length: 2, anchor: day(11, 2), names: ["Regular", "Rally"])
    #expect(clash.shortName(1) == "B")
}

@Test func shortNamesWorkBeforeARotationExists() {
    #expect(Rotation.shortNames(length: 2, names: ["Regular", "Advisory"]) == ["R", "A"])
    #expect(Rotation.shortNames(length: 2, names: nil) == ["A", "B"])
    #expect(Rotation.shortNames(length: 2, names: ["Advisory", "Assembly"]) == ["A", "B"])
}

@Test func oneScheduleShowsEachBlockOnceUsingItsFirstScheduleTimes() {
    let group = UUID()
    let chemA = TimeBlock(name: "Chem", start: 540, end: 590, weekdays: [2, 3, 4, 5, 6], cycleDays: [0], color: "#000000", groupID: group)
    let chemB = TimeBlock(name: "Chem", start: 600, end: 650, weekdays: [2, 3, 4, 5, 6], cycleDays: [1], color: "#000000", groupID: group)
    let labB = TimeBlock(name: "Lab", start: 700, end: 750, weekdays: [2, 3, 4, 5, 6], cycleDays: [1], color: "#000000")
    let homeroom = TimeBlock(name: "Homeroom", start: 480, end: 495, weekdays: [2, 3, 4, 5, 6], color: "#000000")
    let blocks = [chemB, homeroom, chemA, labB]

    let single = Schedule.blocks(blocks, on: day(11, 4), settings: ScheduleSettings(), calendar: calendar)
    #expect(single.map(\.name) == ["Homeroom", "Chem", "Lab"])
    #expect(single.first { $0.name == "Chem" }?.start == 540)

    // Turning the rotation back on shows each schedule's own times again.
    let rotating = Schedule.blocks(blocks, on: day(11, 3), settings: ScheduleSettings(rotation: ab), calendar: calendar)
    #expect(rotating.map(\.name) == ["Homeroom", "Chem", "Lab"])
    #expect(rotating.first { $0.name == "Chem" }?.start == 600)
}

@Test func inactiveRotationRoundTrips() throws {
    let settings = ScheduleSettings(inactiveRotation: Rotation(length: 3, anchor: day(11, 2), names: ["Regular", "Advisory", "Late"]))
    let decoded = try JSONDecoder().decode(ScheduleSettings.self, from: JSONEncoder().encode(settings))
    #expect(decoded.inactiveRotation?.length == 3 && decoded.rotation == nil)
}
