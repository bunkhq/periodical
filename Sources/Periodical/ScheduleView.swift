import PeriodicalCore
import SwiftUI

/// The day as a timeline: start and end times on a rail, the running (or next) block large,
/// breaks between blocks, a red line at the current time, and earlier blocks folded away.
struct ScheduleView: View {
    let store: BlockStore
    let clock: Clock
    @Binding var weekday: Int
    let add: () -> Void
    /// Adds a block to one day's own times.
    let addToDay: (CalendarDay) -> Void
    /// The day is set when the block is one of that day's own times.
    let edit: (TimeBlock, CalendarDay?) -> Void
    let duplicate: (TimeBlock, CalendarDay?) -> Void
    let settings: () -> Void
    let dismiss: () -> Void

    @State private var showEarlier = false

    private static let maxListHeight: CGFloat = 400
    private static let undoWindow: TimeInterval = 8

    var body: some View {
        let now = clock.now
        let today = CalendarDay(now)
        let day = CalendarDay(Schedule.day(forWeekday: weekday, now: now))
        let blocks = Schedule.blocks(store.blocks, on: day, settings: store.settings)
        let timeline = Timeline(blocks: blocks, day: day, today: today, now: now, settings: store.settings, showEarlier: showEarlier)
        let customTimes = store.settings.override(for: day)?.blocks != nil

        VStack(spacing: 12) {
            header(day: day, today: today)

            WeekdayPicker(
                selection: [weekday],
                today: today.weekday(),
                captions: rotationCaptions(now: now),
                toggle: { weekday = $0; showEarlier = false }
            )

            if let note = store.migrationNote {
                MigrationBanner(note: note, review: settings, dismiss: store.dismissMigrationNote)
            }

            if let off = store.settings.dayOff(containing: day) {
                DayOffBanner(off: off, day: day, isPast: day < today) { store.resume(on: day) }
            }
            if let override = store.settings.override(for: day), !override.isEmpty {
                ChangedDayBanner(override: override, settings: store.settings) {
                    store.resetTimes(on: day)
                    store.swapSchedule(on: day, to: nil)
                }
            }

            if store.blocks.isEmpty && !customTimes {
                FirstRunEmptyState()
            } else if blocks.isEmpty {
                emptyDay(day: day, today: today, now: now)
            } else {
                list(timeline)
                if timeline.isDoneForToday {
                    doneForToday(now: now)
                }
            }

            if let deleted = store.recentlyDeleted, now.timeIntervalSince(deleted.at) < Self.undoWindow {
                UndoBar(name: deleted.blocks.first?.name ?? "", undo: store.undoDelete)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if store.blocks.isEmpty && !customTimes {
                Button(action: add) {
                    Label("Add Your First Block", systemImage: "plus")
                }
                .buttonStyle(FilledButtonStyle(fullWidth: true))
            } else {
                Button { customTimes ? addToDay(day) : add() } label: {
                    Label(customTimes ? "Add to This Day" : "Add Block", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(OutlinedButtonStyle())
            }
        }
        .padding(14)
        .animation(.easeOut(duration: 0.2), value: store.recentlyDeleted?.at)
        .background {
            // Keyboard shortcuts for a window with no menu bar.
            Group {
                Button("", action: dismiss).keyboardShortcut(.cancelAction)
                Button("") { customTimes ? addToDay(day) : add() }.keyboardShortcut("n")
                Button("", action: settings).keyboardShortcut(",")
                Button("") {
                    // Only while the Undo bar is showing, so ⌘Z never restores something the user can't see.
                    if let deleted = store.recentlyDeleted, clock.now.timeIntervalSince(deleted.at) < Self.undoWindow {
                        store.undoDelete()
                    }
                }
                .keyboardShortcut("z")
                Button("") { step(-1) }.keyboardShortcut(.leftArrow, modifiers: [])
                Button("") { step(1) }.keyboardShortcut(.rightArrow, modifiers: [])
                Button("") { NSApp.terminate(nil) }.keyboardShortcut("q")
            }
            .hidden()
        }
    }

    private func step(_ delta: Int) {
        weekday = (weekday - 1 + delta + 7) % 7 + 1
        showEarlier = false
    }

    // MARK: - Header

    private func header(day: CalendarDay, today: CalendarDay) -> some View {
        let offset = today.days(to: day)
        let title = switch offset {
        case 0: "Today"
        case 1: "Tomorrow"
        default: day.date().formatted(.dateTime.weekday(.wide))
        }
        var subtitle = day.date().formatted(.dateTime.month(.abbreviated).day())
        if let rotation = store.settings.rotation, let index = store.settings.cycleIndex(for: day) {
            subtitle += " · \(rotation.name(index))"
        }

        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer()
            dayMenu(day: day)
            IconButton(systemImage: "gearshape", label: "Settings (⌘,)", action: settings)
        }
    }

    /// One-day changes: run another schedule, change times for just this day, or take it off.
    private func dayMenu(day: CalendarDay) -> some View {
        let customTimes = store.settings.override(for: day)?.blocks != nil
        let off = store.settings.isDayOff(day)
        return Menu {
            if let rotation = store.settings.rotation {
                let usual = store.settings.usualCycleIndex(for: day)
                let current = store.settings.cycleIndex(for: day)
                Section("Run this day as") {
                    ForEach(0..<rotation.length, id: \.self) { i in
                        Toggle(rotation.name(i) + (i == usual ? " (usual)" : ""), isOn: Binding(
                            get: { current == i },
                            set: { _ in store.swapSchedule(on: day, to: i == usual ? nil : i) }
                        ))
                    }
                }
                .disabled(customTimes)
                Divider()
            }
            if customTimes {
                Button("Use Usual Times Again") { store.resetTimes(on: day) }
            } else {
                Button("Change Times for This Day Only…") { store.customizeTimes(on: day) }
            }
            Divider()
            if off {
                Button("Turn Countdowns Back On") { store.resume(on: day) }
            } else {
                Button("Take This Day Off") { store.addDayOff(DayOff(start: day, end: day)) }
            }
        } label: {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .frame(width: 26, height: 26)
        .help("Change this day")
        .accessibilityLabel("Change this day")
    }

    /// Rotation letters under each weekday circle for the week the circles show.
    private func rotationCaptions(now: Date) -> [Int: String] {
        guard store.settings.rotation != nil else { return [:] }
        var captions: [Int: String] = [:]
        for weekday in 1...7 {
            let day = CalendarDay(Schedule.day(forWeekday: weekday, now: now))
            if let index = store.settings.cycleIndex(for: day) {
                captions[weekday] = store.settings.rotation?.shortName(index)
            }
        }
        return captions
    }

    // MARK: - List

    @ViewBuilder
    private func list(_ timeline: Timeline) -> some View {
        let rows = VStack(spacing: Timeline.spacing) {
            ForEach(timeline.rows) { row in
                rowView(row, timeline: timeline)
            }
        }
        if timeline.estimatedHeight <= Self.maxListHeight {
            rows
        } else {
            ScrollViewReader { proxy in
                ScrollView { rows }
                    .scrollIndicators(.never)
                    .frame(height: Self.maxListHeight)
                    .onAppear {
                        if let focus = timeline.focusID { proxy.scrollTo(focus, anchor: .center) }
                    }
            }
        }
    }

    @ViewBuilder
    private func rowView(_ row: Timeline.Row, timeline: Timeline) -> some View {
        switch row.kind {
        case .block(let block, let style):
            // On a day with its own times, changes stay on that day.
            let ownDay = store.settings.override(for: timeline.day)?.blocks != nil ? timeline.day : nil
            BlockRow(
                block: block,
                style: style,
                now: timeline.now,
                day: timeline.day,
                edit: { edit(block, ownDay) },
                duplicate: { duplicate(block, ownDay) },
                delete: { store.delete(block, on: ownDay) }
            )
        case .gap(let minutes):
            RailRow {
                Text("\(DurationFormat.length(minutes: minutes)) break")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .frame(height: 14)
        case .now:
            NowLine()
        case .earlier(let count, let expanded):
            RailRow {
                Button {
                    showEarlier.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                        Text(expanded ? "Hide earlier blocks" : "\(count) earlier block\(count == 1 ? "" : "s") ended")
                        Spacer()
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Empty and end states

    private func emptyDay(day: CalendarDay, today: CalendarDay, now: Date) -> some View {
        let name = switch today.days(to: day) {
        case 0: "today"
        case 1: "tomorrow"
        default: "on " + day.date().formatted(.dateTime.weekday(.wide))
        }
        return VStack(spacing: 4) {
            Text("Nothing \(name)")
                .font(.system(size: 13, weight: .medium))
            if day == today, let next = Schedule.next(store.blocks, settings: store.settings, after: now) {
                Text("Next: \(next.block.name), \(RelativeDay.string(for: next.start, now: now))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 72)
    }

    private func doneForToday(now: Date) -> some View {
        VStack(spacing: 2) {
            Text("Done for today")
                .font(.system(size: 13, weight: .medium))
            if let next = Schedule.next(store.blocks, settings: store.settings, after: now) {
                Text("Next: \(next.block.name), \(RelativeDay.string(for: next.start, now: now))")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Timeline model

/// The rows for one day, worked out once per render.
struct Timeline {
    enum Style: Equatable {
        /// The running block, or the next one when nothing is running. Shown large with a live timer.
        case focus(BlockPhase)
        /// Later today: a compact row with time until it starts.
        case upcoming(seconds: Int)
        case ended
        /// Another day: a compact row with the block's length.
        case planned
        /// A day off: shown, but greyed.
        case skipped
    }

    enum Kind {
        case block(TimeBlock, Style)
        case gap(minutes: Int)
        case now
        case earlier(count: Int, expanded: Bool)
    }

    struct Row: Identifiable {
        let id: String
        let kind: Kind
    }

    static let spacing: CGFloat = 6
    static let railWidth: CGFloat = 58
    /// Shorter gaps are passing time; labelling every one turns into noise.
    static let minimumLabeledBreak = 10

    let day: CalendarDay
    let now: Date
    private(set) var rows: [Row] = []
    private(set) var focusID: String?
    private(set) var isDoneForToday = false

    init(blocks: [TimeBlock], day: CalendarDay, today: CalendarDay, now: Date, settings: ScheduleSettings, showEarlier: Bool) {
        self.day = day
        self.now = now
        let isLive = day == today && !settings.isDayOff(day)
        let dayStart = day.date()

        let phases = blocks.map { isLive ? $0.phase(on: dayStart, now: now) : nil }
        // The most recently started running block, else the first one still to come.
        let focusIndex = phases.lastIndex { if case .active = $0 { true } else { false } }
            ?? phases.firstIndex { if case .upcoming = $0 { true } else { false } }
        let endedCount = phases.filter { $0 == .passed }.count
        let foldEnded = isLive && endedCount >= 2
        let nowIndex = isLive && !phases.contains { if case .active = $0 { true } else { false } }
            ? (phases.firstIndex { if case .upcoming = $0 { true } else { false } } ?? blocks.count)
            : nil

        var previousEnd: Int?
        if foldEnded {
            rows.append(Row(id: "earlier", kind: .earlier(count: endedCount, expanded: showEarlier)))
        }
        for (i, block) in blocks.enumerated() {
            let phase = phases[i]
            if i == nowIndex {
                rows.append(Row(id: "now", kind: .now))
            } else if let previousEnd, block.start - previousEnd >= Self.minimumLabeledBreak, !(foldEnded && !showEarlier && phase == .passed) {
                rows.append(Row(id: "gap-\(block.id)", kind: .gap(minutes: block.start - previousEnd)))
            }
            previousEnd = max(previousEnd ?? block.end, block.end)

            if foldEnded && !showEarlier && phase == .passed { continue }
            let style: Style
            if !isLive {
                style = settings.isDayOff(day) ? .skipped : .planned
            } else if i == focusIndex, let phase {
                style = .focus(phase)
            } else if case .upcoming(let seconds) = phase {
                style = .upcoming(seconds: seconds)
            } else if case .active(let seconds) = phase {
                // Overlapping blocks: the one not in focus still counts down to its end.
                style = .upcoming(seconds: seconds)
            } else {
                style = .ended
            }
            let id = block.id.uuidString
            if i == focusIndex { focusID = id }
            rows.append(Row(id: id, kind: .block(block, style)))
        }
        if nowIndex == blocks.count, !blocks.isEmpty {
            rows.append(Row(id: "now", kind: .now))
            isDoneForToday = true
        }
    }

    var estimatedHeight: CGFloat {
        let heights = rows.map { row -> CGFloat in
            switch row.kind {
            case .block(_, .focus(.active)): 73
            case .block(_, .focus): 62
            case .block: 36
            case .gap: 14
            case .now: 10
            case .earlier: 28
            }
        }
        return heights.reduce(0, +) + CGFloat(max(rows.count - 1, 0)) * Self.spacing
    }
}

// MARK: - Rows

/// Leaves the rail column empty and puts `content` in the card column.
private struct RailRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: Timeline.railWidth, height: 1)
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct NowLine: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("Now")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(nsColor: .systemRed))
                .frame(width: Timeline.railWidth, alignment: .trailing)
            HStack(spacing: 0) {
                Circle().frame(width: 7, height: 7)
                Rectangle().frame(height: 1.5)
            }
            .foregroundStyle(Color(nsColor: .systemRed))
        }
        .frame(height: 10)
        .accessibilityElement()
        .accessibilityLabel("Now, \(Date().formatted(date: .omitted, time: .shortened))")
    }
}

private struct BlockRow: View {
    let block: TimeBlock
    let style: Timeline.Style
    let now: Date
    let day: CalendarDay
    let edit: () -> Void
    let duplicate: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(TimeParser.format(minutes: block.start))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(TimeParser.format(minutes: block.end))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .monospacedDigit()
            .lineLimit(1)
            .frame(width: Timeline.railWidth, alignment: .trailing)
            .padding(.top, 4)
            .accessibilityHidden(true)

            Button(action: edit) { card }
                .buttonStyle(CardButtonStyle())
                .contextMenu {
                    Button("Edit…", action: edit)
                    Button("Duplicate…", action: duplicate)
                    Divider()
                    Button("Delete “\(block.name)”", role: .destructive, action: delete)
                }
                .help("Click to edit · Right-click for more")
                .accessibilityLabel(accessibilityLabel)
                .accessibilityHint("Edits the block")
                .accessibilityAction(named: "Duplicate", duplicate)
                .accessibilityAction(named: "Delete", delete)
        }
    }

    private var isMuted: Bool { style == .ended || style == .skipped }

    private var foreground: Color {
        isMuted ? .secondary : .foreground(onHex: block.color)
    }

    @ViewBuilder
    private var card: some View {
        Group {
            if case .focus(let phase) = style {
                focusCard(phase)
            } else {
                compactCard
            }
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isMuted ? AnyShapeStyle(Color.primary.opacity(0.07)) : AnyShapeStyle(Color(hex: block.color)))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func focusCard(_ phase: BlockPhase) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(block.name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            HStack(spacing: 7) {
                Hourglass(kind: isActive ? .active : .starting)
                    .fill(foreground, style: FillStyle(eoFill: true))
                    .frame(width: 14, height: 17.5)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(countdown(phase))
                        .font(.system(size: 24, weight: .bold))
                        .monospacedDigit()
                    Text(isActive ? "left" : "to start")
                        .font(.system(size: 12, weight: .medium))
                        .opacity(0.85)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            if isActive {
                progressBar
                    .padding(.top, 6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, isActive ? 11 : 10)
    }

    /// How much of the running block has gone by.
    private var progressBar: some View {
        let start = block.interval(on: day.date()).start
        let fraction = min(max(now.timeIntervalSince(start) / Double(block.minutes * 60), 0), 1)
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(foreground.opacity(0.3))
                Capsule().fill(foreground).frame(width: max(geo.size.width * fraction, 3))
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }

    private var compactCard: some View {
        HStack(spacing: 8) {
            Text(block.name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 0)
            if let trailing {
                Text(trailing)
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .opacity(0.85)
                    .lineLimit(1)
                    .layoutPriority(1)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
    }

    private var isActive: Bool {
        if case .focus(.active) = style { true } else { false }
    }

    private func countdown(_ phase: BlockPhase) -> String {
        switch phase {
        case .upcoming(let seconds), .active(let seconds): DurationFormat.string(seconds: seconds)
        case .passed: "Ended"
        }
    }

    private var trailing: String? {
        switch style {
        case .upcoming(let seconds): "in " + Self.roughly(seconds: seconds)
        case .planned: DurationFormat.length(minutes: block.minutes)
        case .ended, .skipped, .focus: nil
        }
    }

    /// Minutes only, so compact rows don't tick every second.
    private static func roughly(seconds: Int) -> String {
        seconds < 60 ? "<1 min" : DurationFormat.length(minutes: Int((Double(seconds) / 60).rounded(.up)))
    }

    private var accessibilityLabel: String {
        let range = "\(TimeParser.format(minutes: block.start)) to \(TimeParser.format(minutes: block.end))"
        let status: String = switch style {
        case .focus(.active(let s)): "ends in \(DurationFormat.string(seconds: s))"
        case .focus(.upcoming(let s)): "starts in \(DurationFormat.string(seconds: s))"
        case .focus(.passed), .ended: "ended"
        case .upcoming(let s): "starts in \(Self.roughly(seconds: s))"
        case .planned: DurationFormat.length(minutes: block.minutes)
        case .skipped: "day off"
        }
        return "\(block.name), \(range), \(status)"
    }
}

/// Dims slightly on hover and press so cards read as clickable.
private struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Hoverable(pressed: configuration.isPressed) { configuration.label }
    }

    private struct Hoverable<Label: View>: View {
        let pressed: Bool
        @ViewBuilder let label: Label
        @State private var hovering = false

        var body: some View {
            label
                .brightness(pressed ? -0.08 : (hovering ? -0.03 : 0))
                .onHover { hovering = $0 }
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

// MARK: - Banners

private struct DayOffBanner: View {
    let off: DayOff
    let day: CalendarDay
    let isPast: Bool
    let resume: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("Day off")
                    .font(.system(size: 13, weight: .semibold))
                Text(off.start == off.end ? "No countdowns" : "Off \(RelativeDay.range(off))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !isPast {
                Button("Resume", action: resume)
                    .buttonStyle(QuietButtonStyle(color: .primary))
                    .font(.system(size: 12, weight: .semibold))
                    .help("Turn countdowns back on from this day")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.06)))
        .accessibilityElement(children: .combine)
    }
}

/// Shown once after upgrading from an older version: what moved where, with a way to check it.
private struct MigrationBanner: View {
    let note: String
    let review: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your schedule moved over")
                        .font(.system(size: 13, weight: .semibold))
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(spacing: 14) {
                Spacer()
                Button("Dismiss", action: dismiss)
                    .buttonStyle(QuietButtonStyle())
                Button("Review in Settings") {
                    dismiss()
                    review()
                }
                .buttonStyle(QuietButtonStyle(color: .primary))
                .fontWeight(.semibold)
            }
            .font(.system(size: 12))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.06)))
        .accessibilityElement(children: .contain)
    }
}

/// Shown on a day running another schedule or its own times, with a way back to normal.
private struct ChangedDayBanner: View {
    let override: DayOverride
    let settings: ScheduleSettings
    let reset: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: override.blocks != nil ? "pencil.circle.fill" : "arrow.triangle.swap")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Reset", action: reset)
                .buttonStyle(QuietButtonStyle(color: .primary))
                .font(.system(size: 12, weight: .semibold))
                .help("Go back to this day’s usual schedule")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.06)))
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        if override.blocks != nil { return "Custom times" }
        guard let rotation = settings.rotation, let letter = override.letter else { return "Changed" }
        return "Running \(rotation.name(letter))"
    }

    private var detail: String {
        if override.blocks != nil { return "Only this day. Click a block to change it." }
        guard let rotation = settings.rotation else { return "" }
        return settings.usualCycleIndex(for: override.day).map { "Usually \(rotation.name($0))" } ?? "Usually no school"
    }
}

private struct UndoBar: View {
    let name: String
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("Deleted “\(name)”")
                .lineLimit(1)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: undo) {
                Text("Undo ⌘Z").fontWeight(.semibold)
            }
            .buttonStyle(QuietButtonStyle(color: .primary))
        }
        .font(.system(size: 12))
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.06)))
        .accessibilityElement(children: .contain)
    }
}

private struct FirstRunEmptyState: View {
    var body: some View {
        VStack(spacing: 8) {
            Hourglass(kind: .starting)
                .fill(Color.secondary, style: FillStyle(eoFill: true))
                .frame(width: 20, height: 25)
                .accessibilityHidden(true)
            Text("Your schedule is empty")
                .font(.system(size: 13, weight: .semibold))
            Text("Add your classes or meetings and the menu bar will count down to each one.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 12)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
    }
}
