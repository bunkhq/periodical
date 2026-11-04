import PeriodicalCore
import SwiftUI

/// Settings in four short pages so nothing scrolls: Schedule, Days off, Reminders, General.
/// Built from the app's own pieces (capsule chips, weekday circles, soft cards) rather than stock controls.
struct SettingsView: View {
    let store: BlockStore
    let clock: Clock
    @Bindable var prefs: Preferences
    let alerts: EndAlerts
    let back: () -> Void
    let runSetup: () -> Void

    enum Page: String, CaseIterable {
        case schedule = "Schedule"
        case daysOff = "Days off"
        case reminders = "Reminders"
        case general = "General"
    }

    @State private var page = Page.schedule
    /// Opens Days off with the calendar showing (for snapshots).
    private let showCalendar: Bool
    @State private var launchAtLogin = LoginItem.isEnabled
    @Namespace private var tabs

    init(store: BlockStore, clock: Clock, prefs: Preferences, alerts: EndAlerts, page: Page = .schedule, showCalendar: Bool = false,
         back: @escaping () -> Void, runSetup: @escaping () -> Void) {
        self.showCalendar = showCalendar
        self.store = store
        self.clock = clock
        self.prefs = prefs
        self.alerts = alerts
        self.back = back
        self.runSetup = runSetup
        _page = State(initialValue: page)
    }

    var body: some View {
        let today = CalendarDay(clock.now)

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 4) {
                IconButton(systemImage: "chevron.left", label: "Back to schedule (Esc)", action: back)
                    .padding(.leading, -6)
                Text("Settings")
                    .font(.system(size: 15, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
            }

            tabBar

            Group {
                switch page {
                case .schedule: SchedulePage(store: store, clock: clock, today: today)
                case .daysOff: DaysOffPage(store: store, today: today, picking: showCalendar)
                case .reminders: remindersPage
                case .general: generalPage
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background {
            Group {
                Button("", action: back).keyboardShortcut(.cancelAction)
                ForEach(Array(Page.allCases.enumerated()), id: \.offset) { i, p in
                    Button("") { select(p) }.keyboardShortcut(KeyEquivalent(Character("\(i + 1)")))
                }
            }
            .hidden()
        }
        .onAppear { alerts.refreshPermission() }
    }

    private func select(_ next: Page) {
        withAnimation(.easeOut(duration: 0.18)) { page = next }
    }

    /// Page tabs: plain labels, the current one sitting on a soft capsule that slides between them.
    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(Array(Page.allCases.enumerated()), id: \.offset) { i, p in
                let selected = p == page
                Button { select(p) } label: {
                    Text(p.rawValue)
                        .font(.system(size: 12, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 26)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Color.primary.opacity(0.08))
                                    .matchedGeometryEffect(id: "tab", in: tabs)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("\(p.rawValue) (⌘\(i + 1))")
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(2)
        .background(Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1))
    }

    // MARK: - Reminders

    private var remindersPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection("Remind me before a block ends") {
                ChipPicker(
                    options: Preferences.endAlertChoices.map { ($0, $0 == 0 ? "Off" : "\($0) min") },
                    selection: Binding(
                        get: { prefs.endAlertMinutes },
                        set: { minutes in
                            prefs.endAlertMinutes = minutes
                            if minutes > 0 { alerts.requestPermission() }
                        }
                    )
                )
                .accessibilityLabel("Remind me before a block ends")
            }

            if prefs.endAlertMinutes > 0 {
                if alerts.permission == .denied {
                    Banner(
                        systemImage: "bell.slash",
                        title: "Notifications are off",
                        detail: "A chime plays instead. Turn them on to see which block is ending.",
                        action: ("Turn On…", alerts.openSystemSettings)
                    )
                }
                Button("Send a Test Reminder") { alerts.sendTest(minutes: prefs.endAlertMinutes) }
                    .buttonStyle(CompactOutlinedButtonStyle())
            }

            Footnote(prefs.endAlertMinutes == 0
                     ? "Pick a time to get a notification as the running block winds down."
                     : "You’ll get a notification \(prefs.endAlertMinutes) minute\(prefs.endAlertMinutes == 1 ? "" : "s") before each block ends, naming what’s next.")
        }
    }

    // MARK: - General

    private var generalPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection("Menu bar") {
                MenuBarPreview(prefs: prefs, block: Schedule.current(store.blocks, settings: store.settings, now: clock.now)?.0)
                SettingsCard {
                    ToggleRow(title: "Show block name", detail: "Next to the countdown", isOn: $prefs.showNameInMenuBar)
                    Divider().padding(.leading, 12)
                    ToggleRow(title: "Fill with block color", detail: "Color the whole menu bar button", isOn: $prefs.fillMenuBarButton)
                }
            }

            SettingsSection("App") {
                SettingsCard {
                    ToggleRow(title: "Open at login", isOn: Binding(
                        get: { launchAtLogin },
                        set: { on in
                            LoginItem.set(on)
                            launchAtLogin = LoginItem.isEnabled
                        }
                    ))
                    Divider().padding(.leading, 12)
                    Button(action: runSetup) {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Run setup again")
                                    .font(.system(size: 13))
                                Text("Your blocks stay")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Schedule

private struct SchedulePage: View {
    let store: BlockStore
    let clock: Clock
    let today: CalendarDay
    @FocusState private var focusedName: Int?

    var body: some View {
        let rotation = store.settings.rotation

        VStack(alignment: .leading, spacing: 16) {
            SettingsSection("Your week") {
                ChipPicker(
                    options: [(false, "Same every day"), (true, "A few schedules")],
                    selection: Binding(get: { rotation != nil }, set: setRotating)
                )
            }

            if let rotation {
                SettingsSection("How they switch") {
                    ChipPicker(
                        options: [(false, "Take turns"), (true, "By weekday")],
                        selection: Binding(get: { rotation.isByWeekday }, set: { setByWeekday($0, rotation) })
                    )
                }

                SettingsSection("Schedules") {
                    ScheduleNameList(
                        length: rotation.length,
                        names: rotation.names ?? [],
                        setName: { index, text in
                            var next = rotation
                            var names = rotation.names ?? []
                            while names.count < rotation.length { names.append("") }
                            names[index] = text
                            next.names = names
                            store.setRotation(next)
                        },
                        setLength: { setLength($0, rotation) },
                        focusedName: $focusedName
                    )
                }

                if rotation.isByWeekday {
                    SettingsSection("Which days run each") {
                        WeekdayGrid(rotation: rotation) { weekday, index in
                            var next = rotation
                            var letters = rotation.weekdayLetters ?? Array(repeating: nil, count: 7)
                            letters[weekday - 1] = rotation.letter(forWeekday: weekday) == index ? nil : index
                            next.weekdayLetters = letters
                            store.setRotation(next)
                        }
                    }
                    Footnote("Each weekday always runs the same schedule. Click a dot to move a day.")
                } else {
                    SettingsSection("\(referenceName) is") {
                        ChipPicker(
                            options: (0..<rotation.length).map { ($0, rotation.name($0)) },
                            selection: Binding(get: { current }, set: { index in
                                var next = rotation
                                next.anchor = reference
                                next.anchorIndex = index
                                store.setRotation(next)
                            })
                        )
                    }
                    SettingsSection("School days") {
                        WeekdayPicker(selection: rotation.schoolDays, multiSelect: true, circle: 28) { day in
                            var next = rotation
                            if next.schoolDays.contains(day) { next.schoolDays.remove(day) } else { next.schoolDays.insert(day) }
                            guard !next.schoolDays.isEmpty else { return }
                            // Re-anchor so the reference day keeps its schedule.
                            next.anchor = reference
                            next.anchorIndex = current
                            store.setRotation(next)
                        }
                    }
                    Footnote("Each school day takes the next schedule. Weekends and days off are skipped.")
                }
            } else {
                SettingsSection("Class days") {
                    WeekdayPicker(selection: store.settings.classDays, multiSelect: true) { day in
                        var days = store.settings.classDays
                        if days.contains(day) { days.remove(day) } else { days.insert(day) }
                        if !days.isEmpty { store.setClassDays(days) }
                    }
                }
                Footnote(store.settings.inactiveRotation == nil
                         ? "New blocks repeat on these days."
                         : "New blocks repeat on these days. Your schedules are saved; switch back to bring them and their times back.")
            }
        }
    }

    /// The day whose schedule the user sets: today, or the next school day on a weekend.
    private var reference: CalendarDay {
        var day = today
        let schoolDays = store.settings.rotation?.schoolDays ?? [2, 3, 4, 5, 6]
        for _ in 0..<7 where !schoolDays.contains(day.weekday()) {
            day = day.adding(days: 1)
        }
        return day
    }

    private var referenceName: String {
        reference == today ? "Today" : reference.date().formatted(.dateTime.weekday(.wide))
    }

    private var current: Int {
        store.settings.cycleIndex(for: reference) ?? 0
    }

    private func setLength(_ length: Int, _ rotation: Rotation) {
        var next = rotation
        next.length = length
        // Keep the reference day's schedule where it is while the cycle grows or shrinks.
        next.anchor = reference
        next.anchorIndex = min(current, length - 1)
        next.weekdayLetters = rotation.weekdayLetters?.map { $0.flatMap { $0 < length ? $0 : nil } }
        if let names = rotation.names { next.names = Array(names.prefix(length)) }
        store.setRotation(next)
    }

    private func setRotating(_ on: Bool) {
        store.setRotating(on, fresh: Rotation(length: 2, anchor: reference, schoolDays: store.settings.classDays))
    }

    private func setByWeekday(_ byWeekday: Bool, _ rotation: Rotation) {
        var next = rotation
        if byWeekday {
            // Start from the schedules the coming week already has, so nothing jumps.
            next.weekdayLetters = (1...7).map { weekday in
                store.settings.cycleIndex(for: CalendarDay(Schedule.day(forWeekday: weekday, now: clock.now)))
            }
        } else {
            next.weekdayLetters = nil
            next.anchor = reference
            next.anchorIndex = current
        }
        store.setRotation(next)
    }
}

/// Each schedule as a row with its letter and an editable name; add or remove at the end.
/// Used in Settings and setup, which supply how names and the count are saved.
struct ScheduleNameList: View {
    let length: Int
    let names: [String]
    let setName: (Int, String) -> Void
    let setLength: (Int) -> Void
    var focusedName: FocusState<Int?>.Binding

    var body: some View {
        // The same initials shown under the weekday circles (R, A for Regular and Advisory).
        let initials = Rotation.shortNames(length: length, names: names)
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<length, id: \.self) { index in
                HStack(spacing: 8) {
                    Text(initials[index])
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(nsColor: .textBackgroundColor))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.primary))
                        .accessibilityHidden(true)
                    TextField(Rotation.defaultName(index), text: Binding(
                        get: { names.indices.contains(index) ? names[index] : "" },
                        set: { setName(index, $0) }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused(focusedName, equals: index)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.05)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(focusedName.wrappedValue == index ? 0.4 : 0.1), lineWidth: 1)
                    )
                    .accessibilityLabel("Name for schedule \(Rotation.label(index))")
                    if index == length - 1 && length > 2 {
                        IconButton(systemImage: "minus.circle", label: "Remove schedule \(Rotation.label(index))") { setLength(length - 1) }
                    } else {
                        Color.clear.frame(width: 26, height: 26)
                    }
                }
            }
            if length < Rotation.maxLength {
                Button { setLength(length + 1) } label: {
                    Label("Add a schedule", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(QuietButtonStyle())
                .padding(.leading, 32)
                .padding(.top, 2)
            }
        }
    }
}

/// Schedules down the side, weekdays across the top (Sunday to Saturday, so the weekend bookends the
/// week); each day's dot sits under the schedule it runs. Used in Settings and setup.
struct WeekdayGrid: View {
    let rotation: Rotation
    let toggle: (_ weekday: Int, _ index: Int) -> Void

    private static let order = Array(1...7)
    private static let nameWidth: CGFloat = 74

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Color.clear.frame(width: Self.nameWidth, height: 1)
                ForEach(Self.order, id: \.self) { day in
                    Text(Calendar.current.veryShortWeekdaySymbols[day - 1])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach(0..<rotation.length, id: \.self) { index in
                HStack(spacing: 0) {
                    Text(rotation.name(index))
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                        .frame(width: Self.nameWidth, alignment: .leading)
                    ForEach(Self.order, id: \.self) { day in
                        let on = rotation.letter(forWeekday: day) == index
                        Button { toggle(day, index) } label: {
                            Circle()
                                .fill(on ? Color.primary : Color.primary.opacity(0.06))
                                .overlay(Circle().strokeBorder(Color.primary.opacity(on ? 0 : 0.12), lineWidth: 1))
                                .frame(width: 22, height: 22)
                                .frame(maxWidth: .infinity, minHeight: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(Calendar.current.weekdaySymbols[day - 1]) runs \(rotation.name(index))")
                        .accessibilityValue(on ? "On" : "Off")
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
    }
}

// MARK: - Days off

private struct DaysOffPage: View {
    let store: BlockStore
    let today: CalendarDay

    @State private var picking = false
    @State private var month: CalendarDay
    @State private var rangeStart: CalendarDay?
    @State private var rangeEnd: CalendarDay?

    init(store: BlockStore, today: CalendarDay, picking: Bool = false) {
        self.store = store
        self.today = today
        _picking = State(initialValue: picking)
        _month = State(initialValue: CalendarDay(year: today.year, month: today.month, day: 1))
    }

    var body: some View {
        let upcoming = store.settings.daysOff.filter { $0.end >= today }.sorted { $0.start < $1.start }
        let tomorrow = today.adding(days: 1)

        VStack(alignment: .leading, spacing: 16) {
            SettingsSection("Take off") {
                HStack(spacing: 6) {
                    quickChip(today, label: "Today")
                    quickChip(tomorrow, label: "Tomorrow")
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { picking.toggle() }
                    } label: {
                        Label("Dates…", systemImage: "calendar")
                            .font(.system(size: 12, weight: picking ? .semibold : .regular))
                            .lineLimit(1)
                            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 28)
                            .background(Capsule().strokeBorder(Color.primary.opacity(picking ? 0.6 : 0.2), lineWidth: 1))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if picking {
                VStack(alignment: .leading, spacing: 10) {
                    RangeCalendar(month: $month, start: $rangeStart, end: $rangeEnd, today: today, daysOff: store.settings.daysOff)
                    HStack {
                        Text(selectionLabel)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Add") { addRange() }
                            .buttonStyle(FilledButtonStyle())
                            .disabled(rangeStart == nil)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            SettingsSection("Coming up") {
                if upcoming.isEmpty {
                    Text("No days off planned")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
                } else {
                    SettingsCard {
                        ForEach(Array(upcoming.enumerated()), id: \.element) { i, off in
                            if i > 0 { Divider().padding(.leading, 12) }
                            DayOffRow(off: off, today: today) { store.removeDayOff(off) }
                        }
                    }
                }
            }

            Footnote("No countdowns on days off." + (skipsLetters ? " Schedules that take turns skip them." : ""))
        }
    }

    private var skipsLetters: Bool {
        store.settings.rotation.map { !$0.isByWeekday } ?? false
    }

    /// A one-day toggle chip: filled while that day is off.
    private func quickChip(_ day: CalendarDay, label: String) -> some View {
        let off = store.settings.isDayOff(day)
        return Button {
            if off { store.resume(on: day) } else { store.addDayOff(DayOff(start: day, end: day)) }
        } label: {
            HStack(spacing: 4) {
                if off { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
                Text(label)
            }
            .font(.system(size: 12, weight: off ? .semibold : .regular))
            .lineLimit(1)
            .foregroundStyle(off ? Color(nsColor: .textBackgroundColor) : .primary)
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 28)
            .background(Capsule().fill(off ? Color.primary : Color.primary.opacity(0.06)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(off ? "Turn \(label.lowercased())’s countdowns back on" : "Take \(label.lowercased()) off")
        .accessibilityLabel("\(label) off")
        .accessibilityValue(off ? "On" : "Off")
    }

    private var selectionLabel: String {
        guard let rangeStart else { return "Click the first day off" }
        let off = DayOff(start: rangeStart, end: rangeEnd ?? rangeStart)
        let days = off.start.days(to: off.end) + 1
        return rangeEnd == nil
            ? "\(RelativeDay.range(off)) · click a last day, or Add"
            : "\(RelativeDay.range(off)) · \(days) days"
    }

    private func addRange() {
        guard let rangeStart else { return }
        store.addDayOff(DayOff(start: rangeStart, end: rangeEnd ?? rangeStart))
        self.rangeStart = nil
        rangeEnd = nil
        withAnimation(.easeOut(duration: 0.18)) { picking = false }
    }
}

private struct DayOffRow: View {
    let off: DayOff
    let today: CalendarDay
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(RelativeDay.range(off))
                    .font(.system(size: 13))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            IconButton(systemImage: "xmark", label: "Remove \(RelativeDay.range(off))", action: remove)
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
    }

    private var detail: String {
        let days = off.start.days(to: off.end) + 1
        let length = days == 1 ? "1 day" : "\(days) days"
        if off.contains(today) { return "Now · " + length }
        let until = today.days(to: off.start)
        return until == 1 ? "Tomorrow · \(length)" : "In \(until) days · \(length)"
    }
}

/// A month of day circles (like the weekday circles) for picking a run of days off:
/// click the first day, then the last.
private struct RangeCalendar: View {
    @Binding var month: CalendarDay
    @Binding var start: CalendarDay?
    @Binding var end: CalendarDay?
    let today: CalendarDay
    let daysOff: [DayOff]

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(month.date().formatted(.dateTime.month(.wide).year()))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                IconButton(systemImage: "chevron.left", label: "Previous month") { shift(-1) }
                    .disabled(month <= CalendarDay(year: today.year, month: today.month, day: 1))
                IconButton(systemImage: "chevron.right", label: "Next month") { shift(1) }
            }
            .padding(.bottom, 2)

            HStack(spacing: 0) {
                ForEach(weekdayOrder, id: \.self) { day in
                    Text(calendar.veryShortWeekdaySymbols[day - 1])
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(weeks, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(week.indices, id: \.self) { i in
                        cell(week[i])
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
    }

    @ViewBuilder
    private func cell(_ day: CalendarDay?) -> some View {
        if let day {
            let past = day < today
            let endpoint = day == start || day == (end ?? start)
            let inRange = isInRange(day)
            let off = daysOff.contains { $0.contains(day) }
            Button { pick(day) } label: {
                Text("\(day.day)")
                    .font(.system(size: 12, weight: endpoint || day == today ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(endpoint ? Color(nsColor: .textBackgroundColor) : (past ? Color.secondary.opacity(0.5) : .primary))
                    .frame(width: 28, height: 28)
                    .background {
                        if endpoint {
                            Circle().fill(Color.primary)
                        } else if inRange {
                            Circle().fill(Color.primary.opacity(0.12))
                        }
                    }
                    .overlay {
                        if day == today && !endpoint { Circle().strokeBorder(Color.primary.opacity(0.5), lineWidth: 1.5) }
                    }
                    .overlay(alignment: .bottom) {
                        // Days already off get a small mark under the number.
                        if off && !endpoint {
                            Capsule().fill(Color.secondary).frame(width: 8, height: 2).offset(y: -3)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(past)
            .accessibilityLabel(day.date().formatted(date: .complete, time: .omitted) + (off ? ", already off" : ""))
            .accessibilityAddTraits(endpoint || inRange ? .isSelected : [])
        } else {
            Color.clear.frame(maxWidth: .infinity, minHeight: 30)
        }
    }

    /// Sunday first and Saturday last, matching the weekday circles everywhere else.
    private var weekdayOrder: [Int] { Array(1...7) }

    private var weeks: [[CalendarDay?]] {
        let first = month.date()
        let count = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let lead = month.weekday() - 1
        var cells: [CalendarDay?] = Array(repeating: nil, count: lead)
        cells += (1...count).map { CalendarDay(year: month.year, month: month.month, day: $0) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    private func isInRange(_ day: CalendarDay) -> Bool {
        guard let start, let end else { return false }
        return start <= day && day <= end
    }

    private func pick(_ day: CalendarDay) {
        if start == nil || end != nil || day < start! {
            start = day
            end = nil
        } else {
            end = day
        }
    }

    private func shift(_ months: Int) {
        let date = calendar.date(byAdding: .month, value: months, to: month.date())!
        month = CalendarDay(date)
    }
}

// MARK: - Menu bar preview

/// What the menu bar button looks like with the current settings, using the running block when there is one.
private struct MenuBarPreview: View {
    let prefs: Preferences
    let block: TimeBlock?

    var body: some View {
        let sample = block ?? TimeBlock(name: "Chemistry", start: 0, end: 0, weekdays: [], color: "#34C759")
        let pill = MenuBarPill(icon: .active, timer: "12m 4s", title: sample.name, color: sample.color,
                               fillsButton: prefs.fillMenuBarButton, showsTitle: prefs.showNameInMenuBar)
        let image = pill.image()

        HStack(spacing: 10) {
            Spacer()
            Image(nsImage: image)
                .padding(.horizontal, prefs.fillMenuBarButton ? 4 : 0)
                .padding(.vertical, prefs.fillMenuBarButton ? 2 : 0)
                .background {
                    if prefs.fillMenuBarButton { Capsule().fill(Color(hex: sample.color)) }
                }
            // Stand-ins for the menu bar's other icons, so the button reads in place.
            ForEach(["wifi", "battery.75percent"], id: \.self) { name in
                Image(systemName: name)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Text(Date().formatted(date: .omitted, time: .shortened))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.06)))
        .animation(.easeOut(duration: 0.15), value: prefs.fillMenuBarButton)
        .animation(.easeOut(duration: 0.15), value: prefs.showNameInMenuBar)
        .accessibilityElement()
        .accessibilityLabel("Menu bar preview")
    }
}

// MARK: - Layout pieces

/// A small grey label above a group of controls, like the editor's field labels.
struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Footnote: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct Banner: View {
    let systemImage: String
    let title: String
    let detail: String
    let action: (String, () -> Void)

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 18)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Button(action.0, action: action.1)
                .buttonStyle(QuietButtonStyle(color: .primary))
                .font(.system(size: 12, weight: .semibold))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.06)))
    }
}

/// Smaller outlined button for settings rows.
struct CompactOutlinedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 12)
            .frame(minHeight: 26)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.08 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.35), lineWidth: 1)
            )
            .contentShape(Rectangle())
    }
}
