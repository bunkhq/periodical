import Foundation

/// A block's start and end, in minutes since midnight.
public struct TimeRange: Hashable, Sendable {
    public var start: Int
    public var end: Int

    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }
}

/// Builds the stored blocks for one class: one block per distinct time, all sharing a group ID.
public enum BlockGroups {
    /// - Parameters:
    ///   - times: each slot's times. Slots are rotation schedules (0 = A) when `bySchedule`, else weekdays.
    ///   - order: slots in display order, so blocks come out in a stable order.
    ///   - ids: existing block IDs to reuse, in order, so blocks keep theirs where possible.
    ///   - schoolDays: weekdays schedule blocks fall back to if the rotation is turned off.
    public static func make(
        name: String,
        color: String,
        times: [Int: TimeRange],
        order: [Int],
        bySchedule: Bool,
        key: UUID,
        ids: [UUID] = [],
        schoolDays: Set<Int>
    ) -> [TimeBlock] {
        var byTime: [(range: TimeRange, slots: Set<Int>)] = []
        for slot in order where times[slot] != nil {
            let range = times[slot]!
            if let i = byTime.firstIndex(where: { $0.range == range }) {
                byTime[i].slots.insert(slot)
            } else {
                byTime.append((range, [slot]))
            }
        }
        return byTime.enumerated().map { i, entry in
            TimeBlock(
                id: i < ids.count ? ids[i] : UUID(),
                name: name,
                start: entry.range.start,
                end: entry.range.end,
                weekdays: bySchedule ? schoolDays : entry.slots,
                cycleDays: bySchedule ? entry.slots : nil,
                color: color,
                groupID: key
            )
        }
    }
}
