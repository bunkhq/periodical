import PeriodicalCore
import SwiftUI

/// Edits a block as a whole: its name, color, the schedules (or weekdays) it's on, and its times,
/// either one start and end for all of them or a row per schedule.
struct GroupEditor: View {
    let store: BlockStore
    let clock: Clock
    /// The block that was clicked; its whole group is edited.
    let original: TimeBlock
    /// For a duplicate: saves as a new block instead of changing the original.
    let isNew: Bool
    let done: () -> Void

    @State private var name: String
    @State private var color: String?
    @State private var kind: Slots.Kind
    @State private var slots: Set<Int>
    @State private var sameTimes: Bool
    @State private var sharedStart: String
    @State private var sharedEnd: String
    @State private var startTexts: [Int: String]
    @State private var endTexts: [Int: String]
    @FocusState private var focus: Field?

    private enum Field: Hashable {
        case name
    }

    init(store: BlockStore, clock: Clock, block: TimeBlock, isNew: Bool, done: @escaping () -> Void) {
        self.store = store
        self.clock = clock
        self.original = block
        self.isNew = isNew
        self.done = done

        let group = store.group(of: block)
        let rotation = store.settings.rotation
        let kind = Slots.kind(of: group, rotation: rotation)
        let naming = Slots(kind: kind, rotation: rotation)
        let times = naming.times(of: group)
        let first = naming.ordered(Set(times.keys)).first.flatMap { times[$0] } ?? TimeRange(start: block.start, end: block.end)

        _name = State(initialValue: block.name)
        _color = State(initialValue: block.color)
        _kind = State(initialValue: kind)
        _slots = State(initialValue: Set(times.keys))
        _sameTimes = State(initialValue: Set(times.values).count <= 1)
        _sharedStart = State(initialValue: TimeHint.editable(first.start))
        _sharedEnd = State(initialValue: TimeHint.editable(first.end))
        _startTexts = State(initialValue: times.mapValues { TimeHint.editable($0.start) })
        _endTexts = State(initialValue: times.mapValues { TimeHint.editable($0.end) })
    }

    private var naming: Slots { Slots(kind: kind, rotation: store.settings.rotation) }

    /// With one schedule, a block that has different times per (parked) schedule only shows its first.
    private var hasHiddenScheduleTimes: Bool {
        guard !isNew, store.settings.rotation == nil else { return false }
        let group = store.group(of: original).filter { $0.cycleDays != nil }
        return Set(group.map { TimeRange(start: $0.start, end: $0.end) }).count > 1
    }

    var body: some View {
        let _ = clock.now // Keeps relative times like "in 30 minutes" current.
        let times = parsedTimes

        VStack(alignment: .leading, spacing: 14) {
            Text(isNew ? "Duplicate Block" : "Edit Block")
                .font(.system(size: 15, weight: .bold))
                .accessibilityAddTraits(.isHeader)

            labeled("Name") {
                TextField("e.g. Econ & Personal Finance", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($focus, equals: .name)
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.05)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(focus == .name ? 0.4 : 0.15), lineWidth: 1)
                    )
            }

            labeled(kind == .schedule ? "Schedules" : "Days") {
                slotPicker
                if hasHiddenScheduleTimes {
                    Text("This block has its own times on each schedule. Saving here sets one time for every day; to keep them, switch back to A few schedules in Settings first.")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            labeled("Times") {
                if slots.count > 1 {
                    Toggle("Same times on every \(naming.noun)", isOn: Binding(get: { sameTimes }, set: setSameTimes))
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                        .font(.system(size: 12))
                }
                if sameTimes || slots.count <= 1 {
                    TimeRow(label: nil, start: $sharedStart, end: $sharedEnd)
                } else {
                    VStack(spacing: 6) {
                        ForEach(naming.ordered(slots), id: \.self) { slot in
                            TimeRow(label: naming.name(slot), start: startBinding(slot), end: endBinding(slot))
                        }
                    }
                }
                status(times: times)
            }

            labeled("Color") {
                ColorGrid(selection: $color, columns: 10, swatch: 20)
            }

            HStack(spacing: 14) {
                if !isNew {
                    Button("Delete") {
                        store.delete(original)
                        done()
                    }
                    .buttonStyle(QuietButtonStyle(color: Color(nsColor: .systemRed)))
                    .help("Deletes it from every \(naming.noun). You can undo.")
                }
                Spacer()
                Button("Cancel", action: done)
                    .buttonStyle(QuietButtonStyle())
                Button(isNew ? "Add" : "Save") { save(times) }
                    .buttonStyle(FilledButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave(times))
            }
            .font(.system(size: 13))
        }
        .padding(16)
        .background {
            Button("", action: done).keyboardShortcut(.cancelAction).hidden()
        }
        .onAppear {
            if isNew { DispatchQueue.main.async { focus = .name } }
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private var slotPicker: some View {
        if let rotation = store.settings.rotation {
            CyclePicker(rotation: rotation, selection: slots) { toggleSlot($0) }
        } else {
            WeekdayPicker(selection: slots, multiSelect: true) { toggleSlot($0) }
        }
    }

    /// The first problem with the times, or an overlap warning.
    @ViewBuilder
    private func status(times: [Int: TimeRange]?) -> some View {
        if slots.isEmpty {
            note("Pick at least one \(naming.noun)", color: .secondary)
        } else if let problem = timeProblem {
            note(problem, color: Color(nsColor: .systemRed))
        } else if let times, let (slot, other) = firstOverlap(times) {
            note("Overlaps \(other.name)" + (slots.count > 1 && !sameTimes ? " on \(naming.name(slot))" : ""), color: .orange)
        }
    }

    private func note(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: - Times

    private func startBinding(_ slot: Int) -> Binding<String> {
        Binding(get: { startTexts[slot] ?? "" }, set: { startTexts[slot] = $0 })
    }

    private func endBinding(_ slot: Int) -> Binding<String> {
        Binding(get: { endTexts[slot] ?? "" }, set: { endTexts[slot] = $0 })
    }

    /// Each slot's parsed times, or nil while any field doesn't parse or ends before it starts.
    private var parsedTimes: [Int: TimeRange]? {
        var times: [Int: TimeRange] = [:]
        for slot in slots {
            let (s, e) = sameTimes || slots.count <= 1 ? (sharedStart, sharedEnd) : (startTexts[slot] ?? "", endTexts[slot] ?? "")
            guard let start = TimeParser.parse(s), let end = TimeParser.parse(e, reference: start), end > start else { return nil }
            times[slot] = TimeRange(start: start, end: end)
        }
        return times
    }

    private var timeProblem: String? {
        let rows: [(String?, String, String)] = sameTimes || slots.count <= 1
            ? [(nil, sharedStart, sharedEnd)]
            : naming.ordered(slots).map { (naming.name($0), startTexts[$0] ?? "", endTexts[$0] ?? "") }
        for (label, s, e) in rows {
            let prefix = label.map { "\($0): " } ?? ""
            guard let start = TimeParser.parse(s) else { return prefix + "start time? Try 9am, 14:30, or noon" }
            guard let end = TimeParser.parse(e, reference: start) else { return prefix + "end time? Try 10:15 or 45 minutes after" }
            if end <= start { return prefix + "must end after \(TimeParser.format(minutes: start))" }
        }
        return nil
    }

    private func firstOverlap(_ times: [Int: TimeRange]) -> (Int, TimeBlock)? {
        let others = isNew ? store.blocks : store.blocks.filter { $0.groupKey != original.groupKey }
        for slot in naming.ordered(slots) {
            guard let range = times[slot] else { continue }
            if let other = naming.overlap(in: others, slots: [slot], range: range, excludingGroup: nil) { return (slot, other) }
        }
        return nil
    }

    private func setSameTimes(_ same: Bool) {
        if same {
            // Keep the first schedule's times for all of them.
            if let first = naming.ordered(slots).first {
                sharedStart = startTexts[first] ?? sharedStart
                sharedEnd = endTexts[first] ?? sharedEnd
            }
        } else {
            for slot in slots {
                startTexts[slot] = sharedStart
                endTexts[slot] = sharedEnd
            }
        }
        sameTimes = same
    }

    private func toggleSlot(_ slot: Int) {
        if slots.contains(slot) {
            slots.remove(slot)
        } else {
            slots.insert(slot)
            // A newly added schedule starts with the shared times, ready to adjust.
            startTexts[slot] = startTexts[slot] ?? sharedStart
            endTexts[slot] = endTexts[slot] ?? sharedEnd
        }
    }

    // MARK: - Saving

    private func canSave(_ times: [Int: TimeRange]?) -> Bool {
        times != nil && !slots.isEmpty && color != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save(_ times: [Int: TimeRange]?) {
        guard canSave(times), let times, let color else { return }
        let schoolDays = store.settings.rotation?.schoolDays ?? store.settings.classDays
        let key = isNew ? UUID() : original.groupKey
        let blocks = naming.makeBlocks(
            name: name.trimmingCharacters(in: .whitespaces),
            color: color,
            times: times,
            key: key,
            ids: isNew ? [] : store.group(of: original).map(\.id),
            schoolDays: schoolDays
        )
        if isNew { store.add(blocks) } else { store.replaceGroup(key, with: blocks) }
        done()
    }
}

/// `A Day   [ 9:00 ] – [ 9:50 ]`, or just the two fields when the times are shared.
private struct TimeRow: View {
    let label: String?
    @Binding var start: String
    @Binding var end: String

    var body: some View {
        HStack(spacing: 6) {
            if let label {
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 74, alignment: .leading)
                    .layoutPriority(1)
                    .help(label)
            }
            field("Start", text: $start, ok: TimeParser.parse(start) != nil)
            Text("–").foregroundStyle(.secondary)
            field("End", text: $end, ok: TimeParser.parse(start).map { s in TimeParser.parse(end, reference: s).map { $0 > s } ?? false } ?? (TimeParser.parse(end) != nil))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label ?? "Times")
    }

    private func field(_ placeholder: String, text: Binding<String>, ok: Bool) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .monospacedDigit()
            .padding(.horizontal, 8)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(0.05)))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(ok || text.wrappedValue.isEmpty ? Color.primary.opacity(0.15) : Color(nsColor: .systemRed).opacity(0.7), lineWidth: 1)
            )
            .accessibilityLabel(placeholder)
    }
}
