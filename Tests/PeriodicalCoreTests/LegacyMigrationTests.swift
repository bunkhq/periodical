import Foundation
import Testing
@testable import PeriodicalCore

private var calendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "America/New_York")!
    return c
}()

/// Wednesday.
private let today = CalendarDay(year: 2026, month: 11, day: 4)
private func day(_ d: Int) -> CalendarDay { CalendarDay(year: 2026, month: 11, day: d) }
private func block(_ name: String, _ start: Int, _ end: Int, _ weekdays: Set<Int>, _ color: String = "#34C759") -> TimeBlock {
    TimeBlock(name: name, start: start, end: end, weekdays: weekdays, color: color)
}
private func names(_ blocks: [TimeBlock], on d: CalendarDay, _ settings: ScheduleSettings) -> [String] {
    Schedule.blocks(blocks, on: d, settings: settings, calendar: calendar).map { "\($0.name) \($0.start)" }
}

/// The exact `timeblocks.json` from Periodical 0.3 that this upgrade has to carry over.
private let realOldFile = """
[
  {
    "color" : "#7B4AE2",
    "end" : 536,
    "id" : "93180AA5-FEC4-4E00-A4D0-A6DDA18CFFFF",
    "name" : "Intro to Computer Science",
    "start" : 445,
    "weekdays" : [3, 5, 6, 2]
  }
]
"""

@Test func realOldDataMovesOverUnchanged() throws {
    let old = try JSONDecoder().decode([TimeBlock].self, from: Data(realOldFile.utf8))
    let result = LegacyMigration.migrate(old, settings: ScheduleSettings(version: 1), today: today, calendar: calendar)

    // One lineup (Mon, Tue, Thu, Fri), so it stays a single schedule on those days.
    #expect(result.settings.rotation == nil)
    #expect(result.settings.classDays == [2, 3, 5, 6])
    #expect(result.settings.version == ScheduleSettings.currentVersion)
    #expect(result.blocks.count == 1)
    let cs = result.blocks[0]
    #expect(cs.id == old[0].id && cs.groupID == old[0].id)
    #expect((cs.name, cs.start, cs.end, cs.color, cs.weekdays) == ("Intro to Computer Science", 445, 536, "#7B4AE2", [2, 3, 5, 6]))
    for d in [2, 3, 5, 6] {
        #expect(names(result.blocks, on: day(d), result.settings) == ["Intro to Computer Science 445"])
    }
    #expect(names(result.blocks, on: day(4), result.settings).isEmpty)
    #expect(result.summary?.contains("Mon, Tue, Thu, and Fri") == true)
}

@Test func aLateStartWednesdayBecomesItsOwnSchedule() {
    // How a late-start school looked in 0.3: separate copies of each class for Wednesday.
    let old = [
        block("Computer Science", 445, 536, [2, 3, 5, 6], "#7B4AE2"),
        block("Chemistry", 541, 632, [2, 3, 5, 6]),
        block("Computer Science", 540, 600, [4], "#7B4AE2"),
        block("Chemistry", 605, 665, [4]),
        block("Advisory", 670, 700, [4], "#FF9500"),
    ]
    let result = LegacyMigration.migrate(old, settings: ScheduleSettings(version: 1), today: today, calendar: calendar)
    let rotation = try! #require(result.settings.rotation)

    #expect(rotation.length == 2 && rotation.isByWeekday)
    #expect(rotation.weekdayLetters == [nil, 0, 0, 1, 0, 0, nil])
    #expect(rotation.name(0) == "A Day", "\(rotation.names ?? [])")
    #expect(rotation.name(1) == "Wednesday", "\(rotation.names ?? [])")

    // Same name on both schedules: one block (shared group ID), its own times on each.
    let cs = result.blocks.filter { $0.name == "Computer Science" }
    #expect(cs.count == 2 && Set(cs.map(\.groupKey)).count == 1)
    #expect(cs.first { $0.cycleDays == [0] }?.start == 445)
    #expect(cs.first { $0.cycleDays == [1] }?.start == 540)
    #expect(result.blocks.filter { $0.name == "Advisory" }.first?.cycleDays == [1])

    // Every day shows exactly what it did before.
    for d in 1...7 {
        let before = old.filter { $0.weekdays.contains(day(d).weekday(calendar: calendar)) }
            .sorted { $0.start < $1.start }.map { "\($0.name) \($0.start)" }
        #expect(names(result.blocks, on: day(d), result.settings) == before, "day \(d)")
    }
}

@Test func sameTimesOnEverySchedulesMergeIntoOneBlock() {
    let old = [
        block("Homeroom", 480, 495, [2, 3, 4, 5, 6]),
        block("Math", 500, 550, [2, 4, 6]),
        block("Art", 500, 550, [3, 5]),
    ]
    let result = LegacyMigration.migrate(old, settings: ScheduleSettings(version: 1), today: today, calendar: calendar)
    let rotation = try! #require(result.settings.rotation)
    #expect(rotation.weekdayLetters == [nil, 0, 1, 0, 1, 0, nil])
    // Homeroom is the same on both schedules, so it's a single block on both.
    let homeroom = result.blocks.filter { $0.name == "Homeroom" }
    #expect(homeroom.count == 1 && homeroom[0].cycleDays == [0, 1])
}

@Test func copiesOfOneBlockPerDayBecomeOneBlock() {
    // 0.3 users sometimes made the same block once per weekday.
    let old = (2...6).map { block("Lunch", 690, 720, [$0]) }
    let result = LegacyMigration.migrate(old, settings: ScheduleSettings(version: 1), today: today, calendar: calendar)
    #expect(result.settings.rotation == nil)
    #expect(result.blocks.count == 1 && result.blocks[0].weekdays == [2, 3, 4, 5, 6])
}

@Test func aNameTwiceInADayStaysTwoBlocks() {
    let old = [block("Break", 600, 610, [2, 3, 4, 5, 6]), block("Break", 720, 730, [2, 3, 4, 5, 6])]
    let result = LegacyMigration.migrate(old, settings: ScheduleSettings(version: 1), today: today, calendar: calendar)
    #expect(result.blocks.count == 2 && Set(result.blocks.map(\.groupKey)).count == 2)
}

@Test func tooManyDifferentDaysStayOnWeekdays() {
    let old = (1...7).map { block("Shift", 400 + $0 * 10, 500 + $0 * 10, [$0]) }
    let result = LegacyMigration.migrate(old, settings: ScheduleSettings(version: 1), today: today, calendar: calendar)
    #expect(result.settings.rotation == nil)
    // Still one block, with its own time on each weekday.
    #expect(Set(result.blocks.map(\.groupKey)).count == 1 && result.blocks.count == 7)
    #expect(names(result.blocks, on: day(4), result.settings) == ["Shift 440"])
}

@Test func currentDataIsLeftAlone() {
    let current = [TimeBlock(name: "Chem", start: 540, end: 590, weekdays: [2], cycleDays: [0], color: "#000000", groupID: UUID())]
    let result = LegacyMigration.migrate(current, settings: ScheduleSettings(version: 1, rotation: Rotation(length: 2, anchor: today)), today: today, calendar: calendar)
    #expect(result.blocks == current && result.summary == nil && result.settings.version == ScheduleSettings.currentVersion)
}

@Test func realOldDataWithASeparateWednesdayBecomesTwoSchedules() throws {
    // The real 0.3 block plus a Wednesday copy at different times, as 0.3 would have stored it.
    var old = try JSONDecoder().decode([TimeBlock].self, from: Data(realOldFile.utf8))
    let wednesday = TimeBlock(id: UUID(), name: "Intro to Computer Science", start: 540, end: 600, weekdays: [4], color: "#7B4AE2")
    old.append(wednesday)
    let result = LegacyMigration.migrate(old, settings: ScheduleSettings(version: 1), today: today, calendar: calendar)
    let rotation = try #require(result.settings.rotation)

    #expect(rotation.length == 2)
    #expect(rotation.weekdayLetters == [nil, 0, 0, 1, 0, 0, nil])
    #expect(rotation.name(1) == Calendar.current.weekdaySymbols[3])
    // One block, same ID on both schedules, each keeping its own times and original record ID.
    #expect(Set(result.blocks.map(\.groupKey)) == [old[0].id])
    #expect(result.blocks.first { $0.cycleDays == [0] }.map { ($0.id, $0.start, $0.end) } ?? (UUID(), 0, 0) == (old[0].id, 445, 536))
    #expect(result.blocks.first { $0.cycleDays == [1] }.map { ($0.id, $0.start, $0.end) } ?? (UUID(), 0, 0) == (wednesday.id, 540, 600))
    #expect(names(result.blocks, on: day(4), result.settings) == ["Intro to Computer Science 540"])
    #expect(names(result.blocks, on: day(5), result.settings) == ["Intro to Computer Science 445"])
}
