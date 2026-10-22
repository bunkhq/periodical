import PeriodicalCore
import SwiftUI

struct ContentView: View {
    let store: BlockStore
    let clock: Clock
    let layout: PanelLayout
    let dismiss: () -> Void

    @State private var weekday = Calendar.current.component(.weekday, from: Date())
    @State private var isAdding = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Group {
            if isAdding {
                AddBlockFlow(clock: clock, initialWeekday: weekday) { block in
                    if let block { store.add(block) }
                    isAdding = false
                }
            } else {
                ScheduleView(store: store, clock: clock, weekday: $weekday, add: { isAdding = true }, dismiss: dismiss)
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

// MARK: - Schedule

private struct ScheduleView: View {
    let store: BlockStore
    let clock: Clock
    @Binding var weekday: Int
    let add: () -> Void
    let dismiss: () -> Void

    var body: some View {
        let now = clock.now
        let today = Calendar.current.component(.weekday, from: now)
        let blocks = Schedule.blocks(store.blocks, onWeekday: weekday)

        VStack(spacing: 14) {
            WeekdayPicker(
                selection: [weekday],
                today: today,
                toggle: { weekday = $0 }
            )

            if blocks.isEmpty {
                Text("No timeblocks")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 72)
            } else {
                let cards = VStack(spacing: 8) {
                    ForEach(blocks) { block in
                        BlockCard(block: block, phase: weekday == today ? block.phase(on: now, now: now) : nil)
                            .contextMenu {
                                Button("Delete “\(block.name)”", role: .destructive) { store.delete(block) }
                            }
                    }
                }
                if blocks.count <= 5 {
                    cards
                } else {
                    // Five and a half cards tall, so the cut-off one hints at scrolling.
                    ScrollView { cards }
                        .scrollIndicators(.never)
                        .frame(height: 410)
                }
            }

            Button(action: add) {
                Label("Add Timeblock", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(OutlinedButtonStyle())
        }
        .padding(14)
        .background {
            // Keyboard shortcuts for a window with no menu bar.
            Button("", action: dismiss).keyboardShortcut(.cancelAction).hidden()
            Button("", action: add).keyboardShortcut("n").hidden()
            Button("") { NSApp.terminate(nil) }.keyboardShortcut("q").hidden()
        }
    }
}

private struct BlockCard: View {
    let block: TimeBlock
    /// Nil for days other than today, which show start and end times instead of a timer.
    let phase: BlockPhase?

    var body: some View {
        let passed = phase == .passed
        let foreground = passed ? Color.secondary : Color.foreground(onHex: block.color)

        VStack(alignment: .leading, spacing: 2) {
            Text(block.name)
                .font(.system(size: 13))
                .lineLimit(1)
            HStack(spacing: 7) {
                if let icon {
                    Hourglass(kind: icon)
                        .fill(foreground, style: FillStyle(eoFill: true))
                        .frame(width: 14, height: 17.5)
                }
                Text(label)
                    .font(.system(size: 24, weight: .bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(passed ? AnyShapeStyle(Color.primary.opacity(0.07)) : AnyShapeStyle(Color(hex: block.color)))
        )
        .help(range)
    }

    private var range: String {
        "\(TimeParser.format(minutes: block.start)) – \(TimeParser.format(minutes: block.end))"
    }

    private var icon: Hourglass.Kind? {
        switch phase {
        case .upcoming: .starting
        case .active: .active
        case .passed, nil: nil
        }
    }

    private var label: String {
        switch phase {
        case .upcoming(let seconds), .active(let seconds): DurationFormat.string(seconds: seconds)
        case .passed: "Ended"
        case nil: range
        }
    }
}

// MARK: - Shared controls

struct WeekdayPicker: View {
    let selection: Set<Int>
    var today: Int? = nil
    let toggle: (Int) -> Void

    private static let letters = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...7, id: \.self) { day in
                let selected = selection.contains(day)
                Button { toggle(day) } label: {
                    Text(Self.letters[day - 1])
                        .font(.system(size: 13, weight: selected || day == today ? .bold : .regular))
                        .foregroundStyle(selected ? Color(nsColor: .textBackgroundColor) : .primary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(selected ? Color.primary : Color.primary.opacity(0.06)))
                        .overlay(Circle().strokeBorder(Color.primary.opacity(day == today && !selected ? 0.5 : 0), lineWidth: 1.5))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .help(Calendar.current.weekdaySymbols[day - 1])
            }
        }
    }
}

struct OutlinedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.primary)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.08 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.35), lineWidth: 1.5)
            )
    }
}

struct FilledButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(nsColor: .textBackgroundColor))
            .padding(.horizontal, 16)
            .frame(minHeight: 32)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.25))
            )
    }
}

/// Rounded panel outline with an arrow on top pointing at the menu bar button.
struct Bubble: Shape {
    static let arrowHeight: CGFloat = 9
    static let arrowWidth: CGFloat = 20
    static let cornerRadius: CGFloat = 14

    /// Arrow tip, in points from the panel's left edge.
    var arrowX: CGFloat
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: inset, dy: inset)
        let r = Self.cornerRadius - inset
        let half = Self.arrowWidth / 2
        let body = CGRect(x: rect.minX, y: rect.minY + Self.arrowHeight, width: rect.width, height: rect.height - Self.arrowHeight)
        let tip = min(max(arrowX, body.minX + r + half), body.maxX - r - half)

        var p = Path()
        p.move(to: CGPoint(x: body.minX + r, y: body.minY))
        p.addLine(to: CGPoint(x: tip - half, y: body.minY))
        p.addLine(to: CGPoint(x: tip - 1.6, y: rect.minY + 1.2))
        p.addQuadCurve(to: CGPoint(x: tip + 1.6, y: rect.minY + 1.2), control: CGPoint(x: tip, y: rect.minY - 0.4))
        p.addLine(to: CGPoint(x: tip + half, y: body.minY))
        p.addArc(tangent1End: CGPoint(x: body.maxX, y: body.minY), tangent2End: CGPoint(x: body.maxX, y: body.maxY), radius: r)
        p.addArc(tangent1End: CGPoint(x: body.maxX, y: body.maxY), tangent2End: CGPoint(x: body.minX, y: body.maxY), radius: r)
        p.addArc(tangent1End: CGPoint(x: body.minX, y: body.maxY), tangent2End: CGPoint(x: body.minX, y: body.minY), radius: r)
        p.addArc(tangent1End: CGPoint(x: body.minX, y: body.minY), tangent2End: CGPoint(x: tip, y: body.minY), radius: r)
        p.closeSubpath()
        return p
    }
}
