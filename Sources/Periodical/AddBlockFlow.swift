import PeriodicalCore
import SwiftUI

/// One question at a time: name → schedules → same times? → start/end (once, or per schedule) → color.
///
/// The name field autocompletes existing block names (Return or Tab accepts). Returning on an existing
/// name asks whether to add times to that block (keeping its color, so the color step is skipped) or
/// make a separate one. ↑/↓ pick, Return continues, Esc goes back to the name.
struct AddBlockFlow: View {
    let clock: Clock
    let store: BlockStore
    let finish: () -> Void

    enum Step: Hashable {
        case name, slots, sameTimes
        /// Nil asks once for every slot; a slot asks for that schedule (or weekday) alone.
        case start(Int?), end(Int?)
        case color
    }

    @State private var step: Step
    @State private var name: String
    /// Whether to add times to the existing block with this name, when there is one.
    @State private var reuse = true
    /// Showing the reuse question for an existing name, with the keyboard on its options.
    @State private var choosing = false
    @State private var kind: Slots.Kind
    @State private var slots: Set<Int>
    @State private var sameTimes: Bool
    @State private var startTexts: [Int?: String] = [:]
    @State private var endTexts: [Int?: String] = [:]
    /// Starts locked in when their step is confirmed, so "in 30 minutes" doesn't drift.
    @State private var starts: [Int?: Int] = [:]
    @State private var color: String?
    @State private var error: String?
    @FocusState private var fieldFocused: Bool

    /// Starts on every schedule (or every class day), with an unused color picked.
    /// `name`, `step`, and `sameTimes` let snapshots open partway through.
    init(clock: Clock, store: BlockStore, day: CalendarDay, name: String = "", step: Step = .name, sameTimes: Bool = true, finish: @escaping () -> Void) {
        self.clock = clock
        self.store = store
        self.finish = finish
        _name = State(initialValue: name)
        _step = State(initialValue: step)
        _sameTimes = State(initialValue: sameTimes)
        let rotation = store.settings.rotation
        let kind: Slots.Kind = rotation == nil ? .weekday : .schedule
        _kind = State(initialValue: kind)
        _slots = State(initialValue: kind == .schedule ? Set(0..<(rotation?.length ?? 2)) : store.settings.classDays)
        _color = State(initialValue: Palette.suggestion(avoiding: store.blocks.map(\.color)))
    }

    private var naming: Slots { Slots(kind: kind, rotation: store.settings.rotation) }

    private var path: [Step] {
        var path: [Step] = [.name, .slots]
        let ordered = naming.ordered(slots)
        if ordered.count > 1 { path.append(.sameTimes) }
        if sameTimes || ordered.count <= 1 {
            path += [.start(nil), .end(nil)]
        } else {
            for slot in ordered { path += [.start(slot), .end(slot)] }
        }
        if !reusing { path.append(.color) }
        return path
    }

    var body: some View {
        let path = path
        let index = path.firstIndex(of: step) ?? 0

        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(path.indices, id: \.self) { i in
                    Capsule()
                        .fill(Color.primary.opacity(i <= index ? 0.8 : 0.12))
                        .frame(height: 3)
                }
            }
            .accessibilityHidden(true)

            Spacer(minLength: 16)

            VStack(alignment: .leading, spacing: 10) {
                context
                Text(prompt)
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                input
            }

            Spacer(minLength: 16)

            HStack {
                Button(step == .name ? "Cancel" : "Back") { step == .name ? finish() : back() }
                    .buttonStyle(QuietButtonStyle())
                Spacer()
                Button(step == path.last ? "Add" : "Next", action: next)
                    .buttonStyle(FilledButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdvance)
            }
            .font(.system(size: 13))
        }
        .padding(18)
        .frame(minHeight: 360)
        .background { shortcuts }
        .onAppear(perform: focusField)
        .onChange(of: step) { focusField() }
    }

    private var shortcuts: some View {
        Group {
            Button("") {
                // Esc on the reuse question goes back to editing the name; otherwise it cancels.
                if choosing {
                    choosing = false
                    fieldFocused = true
                } else {
                    finish()
                }
            }
            .keyboardShortcut(.cancelAction)
            if choosing {
                Button("") { reuse = true }.keyboardShortcut(.upArrow, modifiers: [])
                Button("") { reuse = false }.keyboardShortcut(.downArrow, modifiers: [])
            }
            if step == .sameTimes {
                Button("") { sameTimes = true }.keyboardShortcut(.upArrow, modifiers: [])
                Button("") { sameTimes = false }.keyboardShortcut(.downArrow, modifiers: [])
            }
        }
        .hidden()
    }

    // MARK: - Copy

    /// What the question is about: the reused block, and which schedule a time is for.
    @ViewBuilder
    private var context: some View {
        if reusing, step != .name, let match {
            HStack(spacing: 6) {
                Circle().fill(Color(hex: match.color)).frame(width: 9, height: 9)
                Text("New times for “\(match.name)”")
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
        }
        switch step {
        case .start(let slot?), .end(let slot?):
            let ordered = naming.ordered(slots)
            SlotBadge(
                title: naming.name(slot),
                detail: "\((ordered.firstIndex(of: slot) ?? 0) + 1) of \(ordered.count)",
                // Only a reused block's color is settled at this point.
                color: reusing ? match?.color : nil
            )
        case .start(nil), .end(nil):
            if slots.count > 1 {
                SlotBadge(title: naming.ordered(slots).map(naming.name).formatted(.list(type: .and)), detail: nil, color: reusing ? match?.color : nil)
            }
        default:
            EmptyView()
        }
    }

    private var prompt: String {
        switch step {
        case .name: return "What’s the block called?"
        case .slots: return kind == .schedule ? "Which schedules is it on?" : "Which days is it on?"
        case .sameTimes: return "Same times on every \(naming.noun)?"
        case .start(let slot): return "When does it start" + (slot.map { " on \(naming.name($0))" } ?? "") + "?"
        case .end(let slot): return "When does it end" + (slot.map { " on \(naming.name($0))" } ?? "") + "?"
        case .color: return "Pick a color"
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var input: some View {
        switch step {
        case .name:
            nameField
            if choosing, let match {
                ReuseChoice(match: match, rotating: store.settings.rotation != nil, reuse: $reuse)
                Text("↑↓ to choose · Return to continue")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else if let completion {
                hint(Text("Return to use “\(completion)”"))
            } else {
                hint(nil)
            }
        case .slots:
            slotPicker
            hint(slotHint)
        case .sameTimes:
            VStack(spacing: 8) {
                OptionCard(title: "Yes, same times", detail: "One start and end for \(naming.ordered(slots).map(naming.name).formatted(.list(type: .and)))",
                           systemImage: "equal", selected: sameTimes) { sameTimes = true }
                OptionCard(title: "No, they’re different", detail: "Set times for each \(naming.noun) next",
                           systemImage: "square.split.1x2", selected: !sameTimes) { sameTimes = false }
            }
            Text("↑↓ to choose · Return to continue")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        case .start(let slot):
            field(placeholder(start: true, slot: slot), text: textBinding(start: true, slot: slot))
            hint(timeHint(for: startTexts[slot] ?? "", isEnd: false))
        case .end(let slot):
            field(placeholder(start: false, slot: slot), text: textBinding(start: false, slot: slot))
            if let overlap = overlap(for: slot) {
                hint(Text("Overlaps \(overlap.name)").foregroundStyle(.orange))
            } else {
                hint(timeHint(for: endTexts[slot] ?? "", reference: starts[slot], isEnd: true))
            }
        case .color:
            ColorGrid(selection: $color)
        }
    }

    @ViewBuilder
    private var slotPicker: some View {
        if kind == .schedule, let rotation = store.settings.rotation {
            CyclePicker(rotation: rotation, selection: slots) { toggleSlot($0) }
        } else {
            WeekdayPicker(selection: slots, multiSelect: true) { toggleSlot($0) }
        }
    }

    private var slotHint: Text? {
        if slots.isEmpty { return Text("Pick at least one \(naming.noun)") }
        guard reusing, let match else { return nil }
        let existing = naming.ordered(Set(naming.times(of: store.group(of: match)).keys))
        guard !existing.isEmpty else { return nil }
        return Text("Already on \(existing.map(naming.name).formatted(.list(type: .and))). Picking one again replaces its times.")
    }

    // MARK: - Name

    /// The name field, with the rest of a matching existing name shown faintly after the caret.
    private var nameField: some View {
        field("e.g. Econ & Personal Finance", text: $name)
            .overlay(alignment: .leading) {
                if let completion {
                    (Text(name).foregroundColor(.clear) + Text(completion.dropFirst(name.count)).foregroundColor(.secondary.opacity(0.6)))
                        .font(.system(size: 15))
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .onKeyPress(.tab) {
                guard completion != nil else { return .ignored }
                acceptCompletion()
                return .handled
            }
            .onChange(of: name) { choosing = false }
            .accessibilityHint(completion.map { "Return fills in \($0)" } ?? "")
    }

    /// Regular blocks, one per group, oldest first.
    private var namedBlocks: [TimeBlock] {
        var seen = Set<String>()
        return store.blocks.filter { seen.insert($0.name.lowercased()).inserted }
    }

    /// An existing block with exactly this name.
    private var match: TimeBlock? {
        let typed = name.trimmingCharacters(in: .whitespaces)
        guard !typed.isEmpty else { return nil }
        return namedBlocks.first { $0.name.caseInsensitiveCompare(typed) == .orderedSame }
    }

    /// The first existing name that starts with what's typed (and is longer), for inline autocomplete.
    private var completion: String? {
        guard step == .name, !choosing, !name.isEmpty, !name.hasPrefix(" ") else { return nil }
        let typed = name.lowercased()
        return namedBlocks.map(\.name).first { $0.count > name.count && $0.lowercased().hasPrefix(typed) }
    }

    private var reusing: Bool { match != nil && reuse }

    private func acceptCompletion() {
        guard let completion else { return }
        name = completion
        askAboutReuse()
    }

    /// Moves the keyboard from the text field to the reuse options.
    private func askAboutReuse() {
        // Set after the name change, which clears `choosing`.
        DispatchQueue.main.async {
            reuse = true
            choosing = true
            fieldFocused = false
        }
    }

    /// Matches the existing block's kind and color, and starts on the schedules it isn't on yet.
    private func applyReuse() {
        guard let match else { return }
        let group = store.group(of: match)
        kind = Slots.kind(of: group, rotation: store.settings.rotation)
        color = match.color
        let covered = Set(naming.times(of: group).keys)
        let open = Set(naming.all).subtracting(covered)
        slots = open.isEmpty ? covered : open
    }

    // MARK: - Fields

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 15))
            .focused($fieldFocused)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.05)))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(fieldFocused ? 0.4 : 0.15), lineWidth: 1)
            )
            .onChange(of: text.wrappedValue) { error = nil }
    }

    private func textBinding(start: Bool, slot: Int?) -> Binding<String> {
        Binding(
            get: { (start ? startTexts : endTexts)[slot] ?? "" },
            set: { if start { startTexts[slot] = $0 } else { endTexts[slot] = $0 } }
        )
    }

    /// Suggests the previous schedule's time, so a second schedule is quick to fill in.
    private func placeholder(start: Bool, slot: Int?) -> String {
        let ordered = naming.ordered(slots)
        if let slot, let i = ordered.firstIndex(of: slot), i > 0,
           let text = (start ? startTexts : endTexts)[ordered[i - 1]], !text.isEmpty {
            return "\(naming.name(ordered[i - 1])) was \(text)"
        }
        return start ? "e.g. 9am, in 30 minutes, 14:31" : "e.g. 10:15, 45 minutes after, 50"
    }

    private func hint(_ text: Text?) -> some View {
        Group {
            if let error {
                Text(error).foregroundStyle(.red)
            } else if let text {
                text.foregroundStyle(.secondary)
            } else {
                Text(" ")
            }
        }
        .font(.system(size: 12))
        .frame(maxWidth: .infinity, minHeight: 16, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func timeHint(for text: String, reference: Int? = nil, isEnd: Bool) -> Text? {
        _ = clock.now // Re-evaluate relative times ("in 30 minutes") every second.
        guard let result = TimeHint.text(for: text, reference: reference, isEnd: isEnd) else { return nil }
        return result.ok ? Text(result.text).bold() : Text(result.text)
    }

    private func overlap(for slot: Int?) -> TimeBlock? {
        guard let start = starts[slot], let end = TimeParser.parse(endTexts[slot] ?? "", reference: start), end > start else { return nil }
        return naming.overlap(in: store.blocks, slots: slot.map { [$0] } ?? slots, range: TimeRange(start: start, end: end),
                              excludingGroup: reusing ? match?.groupKey : nil)
    }

    // MARK: - Navigation

    private var canAdvance: Bool {
        switch step {
        case .name: !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .slots: !slots.isEmpty
        case .sameTimes: true
        case .start(let slot): TimeParser.parse(startTexts[slot] ?? "") != nil
        case .end(let slot): TimeParser.parse(endTexts[slot] ?? "", reference: starts[slot]) != nil
        case .color: color != nil
        }
    }

    private func next() {
        guard canAdvance else { return }
        error = nil
        switch step {
        case .name:
            // Return on a partial name fills it in; on an existing name, asks what to do with it first.
            if completion != nil {
                acceptCompletion()
                return
            }
            if match != nil && !choosing {
                askAboutReuse()
                return
            }
            choosing = false
            if reusing { applyReuse() }
        case .start(let slot):
            // Lock relative times in at the moment the step is confirmed.
            starts[slot] = TimeParser.parse(startTexts[slot] ?? "")
        case .end(let slot):
            guard let start = starts[slot], let end = TimeParser.parse(endTexts[slot] ?? "", reference: start) else { return }
            guard end > start else {
                error = "Must end after it starts (\(TimeParser.format(minutes: start)))"
                return
            }
        default:
            break
        }
        let path = path
        guard let i = path.firstIndex(of: step) else { return }
        if i + 1 < path.count {
            step = path[i + 1]
        } else {
            save()
        }
    }

    private func back() {
        error = nil
        let path = path
        if let i = path.firstIndex(of: step), i > 0 { step = path[i - 1] }
    }

    private func save() {
        guard let color else { return }
        var times: [Int: TimeRange] = [:]
        for slot in slots {
            let key: Int? = sameTimes || slots.count == 1 ? nil : slot
            guard let start = starts[key], let end = TimeParser.parse(endTexts[key] ?? "", reference: start) else { return }
            times[slot] = TimeRange(start: start, end: end)
        }
        let schoolDays = store.settings.rotation?.schoolDays ?? store.settings.classDays
        if reusing, let match {
            // New times replace the old ones on the same schedules; the rest of the block stays.
            let group = store.group(of: match)
            let merged = naming.times(of: group).merging(times) { _, new in new }
            store.replaceGroup(match.groupKey, with: naming.makeBlocks(
                name: match.name, color: match.color, times: merged, key: match.groupKey, ids: group.map(\.id), schoolDays: schoolDays))
        } else {
            store.add(naming.makeBlocks(
                name: name.trimmingCharacters(in: .whitespaces), color: color, times: times, key: UUID(), schoolDays: schoolDays))
        }
        finish()
    }

    private func toggleSlot(_ slot: Int) {
        if slots.contains(slot) { slots.remove(slot) } else { slots.insert(slot) }
    }

    private func focusField() {
        switch step {
        case .name, .start, .end: DispatchQueue.main.async { fieldFocused = true }
        default: fieldFocused = false
        }
    }
}

/// Which schedule (or weekday) a time question is about, so it's never ambiguous.
struct SlotBadge: View {
    let title: String
    let detail: String?
    var color: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .lineLimit(1)
                .foregroundStyle(color.map { Color.foreground(onHex: $0) } ?? Color(nsColor: .textBackgroundColor))
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Capsule().fill(color.map { Color(hex: $0) } ?? Color.primary))
            if let detail {
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Asks whether a typed name means the existing block or a new one that happens to share it.
private struct ReuseChoice: View {
    let match: TimeBlock
    let rotating: Bool
    @Binding var reuse: Bool

    var body: some View {
        VStack(spacing: 6) {
            option(
                selected: reuse,
                title: "Add times to your “\(match.name)”",
                detail: rotating ? "Same color, on another schedule" : "Same color, on other days"
            ) { reuse = true }
            option(selected: !reuse, title: "Make a separate block", detail: "With its own color") { reuse = false }
        }
        .padding(.top, 2)
    }

    private func option(selected: Bool, title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(selected ? Color.primary : Color.primary.opacity(0.3))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if selected && reuse {
                    Circle().fill(Color(hex: match.color)).frame(width: 12, height: 12)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(selected ? 0.07 : 0.025))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(selected ? 0.9 : 0), lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
