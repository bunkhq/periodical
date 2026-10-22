import PeriodicalCore
import SwiftUI

/// One-question-at-a-time form: name → start → end → days → color.
struct AddBlockFlow: View {
    let clock: Clock
    let finish: (TimeBlock?) -> Void

    private enum Step: Int, CaseIterable {
        case name, start, end, days, color
    }

    @State private var step = Step.name
    @State private var name = ""
    @State private var startText = ""
    @State private var endText = ""
    @State private var start: Int?
    @State private var weekdays: Set<Int>
    @State private var color: String?
    @State private var error: String?
    @FocusState private var fieldFocused: Bool

    init(clock: Clock, initialWeekday: Int, finish: @escaping (TimeBlock?) -> Void) {
        self.clock = clock
        self.finish = finish
        _weekdays = State(initialValue: [initialWeekday])
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(Step.allCases, id: \.self) { s in
                    Capsule()
                        .fill(Color.primary.opacity(s.rawValue <= step.rawValue ? 0.8 : 0.12))
                        .frame(height: 3)
                }
            }

            Spacer(minLength: 20)

            VStack(alignment: .leading, spacing: 10) {
                Text(prompt)
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                input
            }

            Spacer(minLength: 20)

            HStack {
                if step == .name {
                    Button("Cancel") { finish(nil) }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Back", action: back)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(step == .color ? "Add" : "Next", action: next)
                    .buttonStyle(FilledButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdvance)
            }
            .font(.system(size: 13))
        }
        .padding(18)
        .frame(height: 360)
        .background {
            Button("") { finish(nil) }.keyboardShortcut(.cancelAction).hidden()
        }
        .onAppear(perform: focusField)
        .onChange(of: step) { focusField() }
    }

    // MARK: - Steps

    private var prompt: String {
        switch step {
        case .name: "What’s the timeblock called?"
        case .start: "When does it start?"
        case .end: "When does it end?"
        case .days: "Which days does it repeat?"
        case .color: "Pick a color"
        }
    }

    @ViewBuilder
    private var input: some View {
        switch step {
        case .name:
            field("e.g. Econ & Personal Finance", text: $name)
            hint(nil)
        case .start:
            field("e.g. 9am, in 30 minutes, 14:31", text: $startText)
            hint(timeHint(for: startText))
        case .end:
            field("e.g. 10:15, 45 minutes after, 50", text: $endText)
            hint(timeHint(for: endText, reference: start))
        case .days:
            WeekdayPicker(selection: weekdays) { day in
                if weekdays.contains(day) { weekdays.remove(day) } else { weekdays.insert(day) }
            }
            hint(weekdays.isEmpty ? Text("Pick at least one day") : nil)
        case .color:
            ColorGrid(selection: $color)
        }
    }

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
    }

    private func timeHint(for text: String, reference: Int? = nil) -> Text? {
        _ = clock.now // Re-evaluate relative times ("in 30 minutes") every second.
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        if let minutes = TimeParser.parse(text, reference: reference) {
            return Text(TimeParser.format(minutes: minutes)).bold()
        }
        return Text("Not sure what time that is")
    }

    private var canAdvance: Bool {
        switch step {
        case .name: !name.trimmingCharacters(in: .whitespaces).isEmpty
        case .start: TimeParser.parse(startText) != nil
        case .end: TimeParser.parse(endText, reference: start) != nil
        case .days: !weekdays.isEmpty
        case .color: color != nil
        }
    }

    // MARK: - Navigation

    private func next() {
        guard canAdvance else { return }
        error = nil
        switch step {
        case .name:
            step = .start
        case .start:
            // Lock relative times in at the moment the step is confirmed.
            start = TimeParser.parse(startText)
            step = .end
        case .end:
            guard let start, let end = TimeParser.parse(endText, reference: start) else { return }
            guard end > start else {
                error = "Must end after it starts (\(TimeParser.format(minutes: start)))"
                return
            }
            step = .days
        case .days:
            step = .color
        case .color:
            guard let start, let end = TimeParser.parse(endText, reference: start), let color else { return }
            finish(TimeBlock(
                name: name.trimmingCharacters(in: .whitespaces),
                start: start,
                end: end,
                weekdays: weekdays,
                color: color
            ))
        }
    }

    private func back() {
        error = nil
        if let previous = Step(rawValue: step.rawValue - 1) { step = previous }
    }

    private func focusField() {
        guard step == .name || step == .start || step == .end else { return }
        DispatchQueue.main.async { fieldFocused = true }
    }
}

private struct ColorGrid: View {
    @Binding var selection: String?

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
            ForEach(Palette.colors, id: \.self) { hex in
                Button { selection = hex } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 30, height: 30)
                        .overlay {
                            if selection == hex {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.foreground(onHex: hex))
                            }
                        }
                        .padding(3)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(selection == hex ? 0.8 : 0), lineWidth: 2))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
