import PeriodicalCore
import SwiftUI

enum PanelRoute: Equatable {
    case onboarding
    case schedule
    case add
    /// `isNew` for a block that hasn't been saved yet (a duplicate, or one added to a single day).
    /// `day` is set when the block belongs to that day's own times rather than the regular schedule.
    case edit(TimeBlock, isNew: Bool, day: CalendarDay?)
    case settings
}

struct ContentView: View {
    let store: BlockStore
    let clock: Clock
    let prefs: Preferences
    let alerts: EndAlerts
    let layout: PanelLayout
    let dismiss: () -> Void

    @State private var route: PanelRoute
    @State private var weekday = Calendar.current.component(.weekday, from: Date())
    @Environment(\.colorScheme) private var colorScheme

    init(store: BlockStore, clock: Clock, prefs: Preferences, alerts: EndAlerts, layout: PanelLayout, route: PanelRoute, dismiss: @escaping () -> Void) {
        self.store = store
        self.clock = clock
        self.prefs = prefs
        self.alerts = alerts
        self.layout = layout
        self.dismiss = dismiss
        _route = State(initialValue: route)
    }

    /// The date the weekday circles point at: today, or that weekday's next occurrence.
    private var selectedDay: CalendarDay {
        CalendarDay(Schedule.day(forWeekday: weekday, now: clock.now))
    }

    var body: some View {
        Group {
            switch route {
            case .onboarding:
                OnboardingView(store: store, clock: clock) { addBlock in
                    prefs.hasOnboarded = true
                    route = addBlock ? .add : .schedule
                }
            case .schedule:
                ScheduleView(
                    store: store,
                    clock: clock,
                    weekday: $weekday,
                    add: { route = .add },
                    addToDay: { day in
                        route = .edit(TimeBlock(name: "", start: 0, end: 0, weekdays: [], color: Palette.suggestion(avoiding: store.blocks.map(\.color))), isNew: true, day: day)
                    },
                    edit: { route = .edit($0, isNew: false, day: $1) },
                    duplicate: { block, day in
                        if let day {
                            var copy = block
                            copy.id = UUID()
                            route = .edit(copy, isNew: true, day: day)
                        } else {
                            // The editor copies the whole group and saves it as a new block.
                            route = .edit(block, isNew: true, day: nil)
                        }
                    },
                    settings: { route = .settings },
                    dismiss: dismiss
                )
            case .add:
                AddBlockFlow(clock: clock, store: store, day: selectedDay) { route = .schedule }
            case .edit(let block, let isNew, let day?):
                BlockEditor(store: store, clock: clock, block: block, isNew: isNew, day: day) { route = .schedule }
            case .edit(let block, let isNew, nil):
                GroupEditor(store: store, clock: clock, block: block, isNew: isNew) { route = .schedule }
            case .settings:
                SettingsView(store: store, clock: clock, prefs: prefs, alerts: alerts, back: { route = .schedule }, runSetup: { route = .onboarding })
            }
        }
        .frame(width: 320)
        .padding(.top, Bubble.arrowHeight)
        .background(Bubble(arrowX: layout.arrowX).fill(colorScheme == .dark ? Color(white: 0.12) : .white))
        .clipShape(Bubble(arrowX: layout.arrowX))
        .overlay(
            Bubble(arrowX: layout.arrowX, inset: 0.5)
                .stroke(Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.1), lineWidth: 1)
        )
    }
}
