import PeriodicalCore
import SwiftUI

/// First-run setup: how the user's week is structured, before any blocks are added.
/// Defaults to A/B days that take turns, the most common setup, so Next-Next-Next just works.
struct OnboardingView: View {
    let store: BlockStore
    let clock: Clock
    /// Called with true to go straight to adding the first block.
    let finish: (_ addBlock: Bool) -> Void

    enum Step {
        case structure, switching, names, assign, classDays, done
    }

    @State private var step: Step
    @State private var multiple = true
    @State private var byWeekday = false
    @State private var count = 2
    @State private var names = Array(repeating: "", count: Rotation.maxLength)
    /// Which schedule the reference day (today, or the next school day) runs, when they take turns.
    @State private var referenceIndex = 0
    @State private var classDays: Set<Int>
    /// Schedule index per weekday (Sunday first), when each weekday has its own.
    @State private var weekdayLetters: [Int?] = [nil, 0, 0, 0, 0, 0, nil]
    @FocusState private var focusedName: Int?

    init(store: BlockStore, clock: Clock, step: Step = .structure, byWeekday: Bool = false, finish: @escaping (_ addBlock: Bool) -> Void) {
        self.store = store
        self.clock = clock
        self.finish = finish
        _step = State(initialValue: step)
        _byWeekday = State(initialValue: byWeekday)
        _classDays = State(initialValue: store.settings.classDays)
        // Running setup again starts from what's already there.
        if let rotation = store.settings.rotation ?? store.settings.inactiveRotation {
            _count = State(initialValue: rotation.length)
            _byWeekday = State(initialValue: rotation.isByWeekday)
            _names = State(initialValue: (0..<Rotation.maxLength).map { i in
                rotation.names.flatMap { $0.indices.contains(i) ? $0[i] : nil } ?? ""
            })
            if let letters = rotation.weekdayLetters { _weekdayLetters = State(initialValue: letters) }
        } else if store.settings.rotation == nil, !store.blocks.isEmpty {
            _multiple = State(initialValue: false)
        }
    }

    private var path: [Step] {
        multiple ? [.structure, .switching, .names, .assign, .done] : [.structure, .classDays, .done]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                ForEach(path.indices, id: \.self) { i in
                    Capsule()
                        .fill(Color.primary.opacity(i <= (path.firstIndex(of: step) ?? 0) ? 0.8 : 0.12))
                        .frame(height: 3)
                }
            }
            .accessibilityHidden(true)
            .padding(.bottom, 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.bottom, 14)

            content

            Spacer(minLength: 18)

            footer
        }
        .padding(18)
        .frame(minHeight: 380, alignment: .top)
        .onChange(of: count) { referenceIndex = min(referenceIndex, count - 1) }
    }

    // MARK: - Copy

    private var title: String {
        switch step {
        case .structure: "How does your week work?"
        case .switching: "How do your schedules switch?"
        case .names: "What are they called?"
        case .assign: byWeekday ? "Which days run each one?" : (referenceName == "Today" ? "Which one is today?" : "Which one is \(referenceName)?")
        case .classDays: "Which days do you have class?"
        case .done: "You’re set"
        }
    }

    private var subtitle: String? {
        switch step {
        case .structure: "Periodical counts down to each part of your day. First, the shape of your week."
        case .switching: nil
        case .names: "Keep the letters, or use your school’s names."
        case .assign: byWeekday ? "Click a dot to move a day to that schedule." : "Periodical takes it from there, skipping weekends and days off."
        case .classDays: "New blocks will repeat on these days."
        case .done: summary
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case .structure:
            VStack(spacing: 8) {
                OptionCard(title: "A few schedules",
                           detail: "A/B days, block days, or a late start every Wednesday",
                           systemImage: "square.split.2x1", selected: multiple) { multiple = true }
                OptionCard(title: "Same every day",
                           detail: "Every class day has the same blocks at the same times",
                           systemImage: "square", selected: !multiple) { multiple = false }
            }
        case .switching:
            VStack(spacing: 8) {
                OptionCard(title: "Take turns",
                           detail: "A, B, A, B… one per school day, whatever the weekday",
                           systemImage: "arrow.triangle.2.circlepath", selected: !byWeekday) { byWeekday = false }
                OptionCard(title: "By weekday",
                           detail: "Each weekday always runs the same one, like a late start every Wednesday",
                           systemImage: "calendar", selected: byWeekday) { byWeekday = true }
            }
        case .names:
            SettingsSection("Schedules") {
                ScheduleNameList(
                    length: count,
                    names: Array(names.prefix(count)),
                    setName: { index, text in names[index] = text },
                    setLength: { length in
                        count = length
                        weekdayLetters = weekdayLetters.map { $0.flatMap { $0 < length ? $0 : nil } }
                    },
                    focusedName: $focusedName
                )
            }
        case .assign:
            if byWeekday {
                WeekdayGrid(rotation: rotation) { weekday, index in
                    weekdayLetters[weekday - 1] = weekdayLetters[weekday - 1] == index ? nil : index
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ChipPicker(options: (0..<count).map { ($0, rotation.name($0)) }, selection: $referenceIndex)
                    SettingsSection("School days") {
                        WeekdayPicker(selection: classDays, multiSelect: true, circle: 28) { toggleClassDay($0) }
                    }
                }
            }
        case .classDays:
            WeekdayPicker(selection: classDays, multiSelect: true) { toggleClassDay($0) }
        case .done:
            if let preview = weekPreview {
                WeekPreview(rotation: preview, settings: ScheduleSettings(rotation: preview, daysOff: store.settings.daysOff), now: clock.now)
            }
        }
    }

    private var footer: some View {
        HStack {
            if step == .structure {
                Button("Skip") { skip() }
                    .buttonStyle(QuietButtonStyle())
                    .help("Use A/B days that take turns. You can change this in Settings.")
            } else {
                Button("Back") { move(-1) }
                    .buttonStyle(QuietButtonStyle())
            }
            Spacer()
            if step == .done {
                Button("Add First Block") { save(); finish(true) }
                    .buttonStyle(FilledButtonStyle())
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Next") { move(1) }
                    .buttonStyle(FilledButtonStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canAdvance)
            }
        }
        .font(.system(size: 13))
    }

    // MARK: - State

    private var canAdvance: Bool {
        switch step {
        case .assign: byWeekday ? weekdayLetters.contains { $0 != nil } : !classDays.isEmpty
        case .classDays: !classDays.isEmpty
        default: true
        }
    }

    private func move(_ delta: Int) {
        guard let i = path.firstIndex(of: step), path.indices.contains(i + delta) else { return }
        focusedName = nil
        step = path[i + delta]
        if step == .names { DispatchQueue.main.async { focusedName = 0 } }
    }

    private func toggleClassDay(_ day: Int) {
        if classDays.contains(day) { classDays.remove(day) } else { classDays.insert(day) }
    }

    /// Today, or the next class day when today isn't one.
    private var referenceDay: CalendarDay {
        var day = CalendarDay(clock.now)
        for _ in 0..<7 where !classDays.contains(day.weekday()) {
            day = day.adding(days: 1)
        }
        return day
    }

    private var referenceName: String {
        referenceDay == CalendarDay(clock.now) ? "Today" : referenceDay.date().formatted(.dateTime.weekday(.wide))
    }

    private var rotation: Rotation {
        let trimmed = names.prefix(count).map { $0.trimmingCharacters(in: .whitespaces) }
        return Rotation(
            length: count,
            anchor: referenceDay,
            anchorIndex: referenceIndex,
            schoolDays: classDays.isEmpty ? [2, 3, 4, 5, 6] : classDays,
            weekdayLetters: byWeekday ? weekdayLetters.map { $0.flatMap { $0 < count ? $0 : nil } } : nil,
            names: trimmed.contains { !$0.isEmpty } ? Array(trimmed) : nil
        )
    }

    private var weekPreview: Rotation? { multiple ? rotation : nil }

    private var summary: String {
        guard multiple else {
            return "Same schedule on \(Self.dayList(classDays)). Next, add the blocks in your day, starting with the first one."
        }
        let r = rotation
        let schedules = (0..<count).map(r.name).formatted(.list(type: .and))
        let how = byWeekday ? "\(schedules), each on set weekdays." : "\(schedules) take turns."
        return how + " Next, add the blocks in your day, starting with the first one."
    }

    private static func dayList(_ days: Set<Int>) -> String {
        days.sorted() // Sunday first
            .map { Calendar.current.shortWeekdaySymbols[$0 - 1] }
            .formatted(.list(type: .and))
    }

    private func save() {
        store.configure(rotation: multiple ? rotation : nil, classDays: classDays.isEmpty ? [2, 3, 4, 5, 6] : classDays)
    }

    private func skip() {
        multiple = true
        byWeekday = false
        save()
        finish(false)
    }
}

/// This week, Sunday to Saturday, as the schedule view will show it: school days filled,
/// each with its schedule's initial underneath, and a key to the names.
private struct WeekPreview: View {
    let rotation: Rotation
    let settings: ScheduleSettings
    let now: Date

    var body: some View {
        let today = CalendarDay(now)
        let indices = Dictionary(uniqueKeysWithValues: (1...7).compactMap { weekday -> (Int, Int)? in
            // This calendar week, so the pattern reads in order (A, B, A, B, A).
            let day = today.adding(days: weekday - today.weekday())
            return settings.cycleIndex(for: day).map { (weekday, $0) }
        })

        VStack(alignment: .leading, spacing: 12) {
            WeekdayPicker(
                selection: Set(indices.keys),
                today: today.weekday(),
                captions: indices.mapValues(rotation.shortName),
                toggle: { _ in }
            )
            .allowsHitTesting(false)

            HStack(spacing: 14) {
                ForEach(0..<rotation.length, id: \.self) { index in
                    HStack(spacing: 5) {
                        Text(rotation.shortName(index))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(nsColor: .textBackgroundColor))
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color.primary))
                        Text(rotation.name(index))
                            .font(.system(size: 12))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((1...7).compactMap { weekday in
            indices[weekday].map { "\(Calendar.current.weekdaySymbols[weekday - 1]): \(rotation.name($0))" }
        }.joined(separator: ", "))
    }
}
