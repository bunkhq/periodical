import Foundation
import PeriodicalCore

/// Where a block repeats, as numbered "slots": rotation schedules (0 = A Day) or `Calendar` weekdays.
/// A class is one group of blocks, one per distinct time, together covering its slots.
struct Slots {
    enum Kind: Equatable {
        case schedule, weekday
    }

    let kind: Kind
    let rotation: Rotation?

    /// Every slot in display order: A, B, C… or Sunday through Saturday, so the weekend bookends the week.
    var all: [Int] {
        kind == .schedule ? Array(0..<(rotation?.length ?? 0)) : Array(1...7)
    }

    func ordered(_ slots: Set<Int>) -> [Int] {
        all.filter(slots.contains)
    }

    func name(_ slot: Int) -> String {
        kind == .schedule
            ? rotation?.name(slot) ?? Rotation.defaultName(slot)
            : Calendar.current.weekdaySymbols[slot - 1]
    }

    /// `schedule` or `day`, for copy.
    var noun: String { kind == .schedule ? "schedule" : "day" }

    func slots(of block: TimeBlock) -> Set<Int> {
        kind == .schedule ? (block.cycleDays ?? []) : block.weekdays
    }

    /// Repeats by schedule when a rotation is set up and the group uses one.
    /// With a rotation, blocks are always placed on schedules; weekdays are only for a single schedule.
    static func kind(of group: [TimeBlock], rotation: Rotation?) -> Kind {
        rotation != nil ? .schedule : .weekday
    }

    /// Each slot's times across a group.
    func times(of group: [TimeBlock]) -> [Int: TimeRange] {
        var times: [Int: TimeRange] = [:]
        // Without a rotation, a block's per-schedule copies all cover the same weekdays; use the one that shows.
        let members = kind == .weekday && rotation == nil ? Schedule.withoutScheduleCopies(group) : group
        // A weekday block (made before schedules, or with one schedule) counts as being on every schedule.
        // Schedule-specific blocks go last so their own times win.
        for block in members.sorted(by: { ($0.cycleDays == nil ? 0 : 1) < ($1.cycleDays == nil ? 0 : 1) }) {
            let covered = kind == .schedule && block.cycleDays == nil ? Set(all) : slots(of: block)
            for slot in covered { times[slot] = TimeRange(start: block.start, end: block.end) }
        }
        return times
    }

    /// One block per distinct time, all sharing `key` so they edit as one.
    /// Reuses `ids` in order so existing blocks keep theirs.
    func makeBlocks(name: String, color: String, times: [Int: TimeRange], key: UUID, ids: [UUID] = [], schoolDays: Set<Int>) -> [TimeBlock] {
        BlockGroups.make(name: name, color: color, times: times, order: all, bySchedule: kind == .schedule,
                         key: key, ids: ids, schoolDays: schoolDays)
    }

    /// Another block that meets in one of `slots` at an overlapping time.
    func overlap(in blocks: [TimeBlock], slots: Set<Int>, range: TimeRange, excludingGroup key: UUID?) -> TimeBlock? {
        let visible = rotation == nil ? Schedule.withoutScheduleCopies(blocks) : blocks
        return visible.first { other in
            guard other.groupKey != key, other.start < range.end, range.start < other.end else { return false }
            let otherUsesSchedules = rotation != nil && other.cycleDays != nil
            switch (kind, otherUsesSchedules) {
            case (.schedule, true): return !(other.cycleDays ?? []).isDisjoint(with: slots)
            case (.weekday, false): return !other.weekdays.isDisjoint(with: slots)
            // A weekday block and a schedule block meet on most school days.
            default: return true
            }
        }
    }
}
