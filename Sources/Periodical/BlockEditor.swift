import PeriodicalCore
import SwiftUI

/// Edits one block on a day that has its own times. Other days aren't affected, so there are no
/// schedules to pick. Regular blocks use `GroupEditor`.
struct BlockEditor: View {
    let store: BlockStore
    let clock: Clock
    let original: TimeBlock
    let isNew: Bool
    let day: CalendarDay
    let done: () -> Void

    @State private var name: String
    @State private var startText: String
    @State private var endText: String
    @State private var color: String?
    @FocusState private var nameFocused: Bool
    @FocusState private var startFocused: Bool
    @FocusState private var endFocused: Bool

    init(store: BlockStore, clock: Clock, block: TimeBlock, isNew: Bool, day: CalendarDay, done: @escaping () -> Void) {
        self.store = store
        self.clock = clock
        self.original = block
        self.isNew = isNew
        self.day = day
        self.done = done
        // A blank block (adding to one day) starts with empty fields rather than midnight.
        let blank = block.name.isEmpty && block.start == block.end
        _name = State(initialValue: block.name)
        _startText = State(initialValue: blank ? "" : TimeHint.editable(block.start))
        _endText = State(initialValue: blank ? "" : TimeHint.editable(block.end))
        _color = State(initialValue: block.color)
    }

    var body: some View {
        let _ = clock.now // Keeps relative times like "in 30 minutes" current.
        let start = TimeParser.parse(startText)
        let end = TimeParser.parse(endText, reference: start)

        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(isNew && original.name.isEmpty ? "Add Block" : (isNew ? "Duplicate Block" : "Edit Block"))
                    .font(.system(size: 15, weight: .bold))
                Text("Only \(RelativeDay.heading(for: day)). Other days keep their usual times.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            labeled("Name") {
                PanelTextField(placeholder: "e.g. Assembly", text: $name, focused: $nameFocused, height: 34, size: 13)
            }

            HStack(alignment: .top, spacing: 10) {
                labeled("Starts") {
                    PanelTextField(placeholder: "9am", text: $startText, focused: $startFocused, height: 34, size: 13)
                    hint(echo(TimeHint.text(for: startText, isEnd: false), of: startText))
                }
                labeled("Ends") {
                    PanelTextField(placeholder: "45 minutes after", text: $endText, focused: $endFocused, height: 34, size: 13)
                    hint(echo(endHint(start: start, end: end), of: endText))
                }
            }

            if let overlap = overlap(start: start, end: end) {
                Text("Overlaps \(overlap.name)")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }

            labeled("Color") {
                ColorGrid(selection: $color, columns: 10, swatch: 20)
            }

            HStack(spacing: 14) {
                if !isNew {
                    Button("Delete") {
                        store.delete(original, on: day)
                        done()
                    }
                    .buttonStyle(QuietButtonStyle(color: Color(nsColor: .systemRed)))
                }
                Spacer()
                Button("Cancel", action: done)
                    .buttonStyle(QuietButtonStyle())
                Button(isNew ? "Add" : "Save") { save(start: start, end: end) }
                    .buttonStyle(FilledButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave(start: start, end: end))
            }
            .font(.system(size: 13))
        }
        .padding(16)
        .background {
            Button("", action: done).keyboardShortcut(.cancelAction).hidden()
        }
        .onAppear {
            if isNew { DispatchQueue.main.async { nameFocused = true } }
        }
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func hint(_ result: (text: String, ok: Bool)?) -> some View {
        Text(result?.text ?? " ")
            .font(.system(size: 11, weight: result?.ok == true ? .semibold : .regular))
            .foregroundStyle(result?.ok == false ? Color(nsColor: .systemRed) : .secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Hides the parsed time when it says exactly what was typed.
    private func echo(_ result: (text: String, ok: Bool)?, of input: String) -> (text: String, ok: Bool)? {
        guard let result, result.ok else { return result }
        let typed = input.trimmingCharacters(in: .whitespaces).lowercased()
        return result.text.replacingOccurrences(of: "\u{202F}", with: " ").lowercased() == typed ? nil : result
    }

    private func endHint(start: Int?, end: Int?) -> (text: String, ok: Bool)? {
        if let start, let end, end <= start {
            return ("Must end after \(TimeParser.format(minutes: start))", false)
        }
        return TimeHint.text(for: endText, reference: start, isEnd: true)
    }

    private func overlap(start: Int?, end: Int?) -> TimeBlock? {
        guard let start, let end, end > start else { return nil }
        return Schedule.blocks(store.blocks, on: day, settings: store.settings)
            .first { $0.id != original.id && $0.start < end && start < $0.end }
    }

    private func canSave(start: Int?, end: Int?) -> Bool {
        guard let start, let end, end > start, color != nil else { return false }
        return !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save(start: Int?, end: Int?) {
        guard canSave(start: start, end: end), let start, let end, let color else { return }
        var block = original
        block.name = name.trimmingCharacters(in: .whitespaces)
        block.start = start
        block.end = end
        block.color = color
        if isNew { store.add(block, on: day) } else { store.update(block, on: day) }
        done()
    }
}
