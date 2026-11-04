import PeriodicalCore
import SwiftUI

// MARK: - Day pickers

struct WeekdayPicker: View {
    let selection: Set<Int>
    var today: Int? = nil
    /// Small labels under each circle, e.g. the rotation letter for that day.
    var captions: [Int: String] = [:]
    /// Spoken as "selected" when picking one day to view, as "on" when toggling repeat days.
    var multiSelect = false
    var circle: CGFloat = 32
    let toggle: (Int) -> Void

    private static let letters = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...7, id: \.self) { day in
                let selected = selection.contains(day)
                Button { toggle(day) } label: {
                    VStack(spacing: 3) {
                        Text(Self.letters[day - 1])
                            .font(.system(size: circle < 30 ? 11 : 13, weight: selected || day == today ? .bold : .regular))
                            .foregroundStyle(selected ? Color(nsColor: .textBackgroundColor) : .primary)
                            .frame(width: circle, height: circle)
                            .background(Circle().fill(selected ? Color.primary : Color.primary.opacity(0.06)))
                            .overlay(Circle().strokeBorder(Color.primary.opacity(day == today && !selected ? 0.5 : 0), lineWidth: 1.5))
                        if !captions.isEmpty {
                            Text(captions[day] ?? " ")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .help(Calendar.current.weekdaySymbols[day - 1])
                .accessibilityLabel(accessibilityLabel(day))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func accessibilityLabel(_ day: Int) -> String {
        var label = Calendar.current.weekdaySymbols[day - 1]
        if let caption = captions[day] { label += ", \(caption)" }
        if day == today { label += ", today" }
        if multiSelect { label += selection.contains(day) ? ", on" : ", off" }
        return label
    }
}

/// The rotation's schedules as toggles (or a single choice): `A Day  B Day`.
struct CyclePicker: View {
    let rotation: Rotation
    let selection: Set<Int>
    let toggle: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<rotation.length, id: \.self) { index in
                let selected = selection.contains(index)
                Button { toggle(index) } label: {
                    Text(rotation.name(index))
                        .font(.system(size: 13, weight: selected ? .bold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(selected ? Color(nsColor: .textBackgroundColor) : .primary)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(Capsule().fill(selected ? Color.primary : Color.primary.opacity(0.06)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(rotation.name(index))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

// MARK: - Color

struct ColorGrid: View {
    @Binding var selection: String?
    var columns = 6
    var swatch: CGFloat = 30

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 6) {
            ForEach(Palette.swatches, id: \.hex) { color in
                let selected = selection?.caseInsensitiveCompare(color.hex) == .orderedSame
                Button { selection = color.hex } label: {
                    Circle()
                        .fill(Color(hex: color.hex))
                        // Keeps black on a dark panel (and pale colors on a light one) visible.
                        .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
                        .frame(width: swatch, height: swatch)
                        .overlay {
                            if selected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: swatch * 0.4, weight: .bold))
                                    .foregroundStyle(Color.foreground(onHex: color.hex))
                            }
                        }
                        .padding(3)
                        .overlay(Circle().strokeBorder(Color.primary.opacity(selected ? 0.8 : 0), lineWidth: 2))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(color.name)
                .accessibilityLabel(color.name)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

// MARK: - Text

struct PanelTextField: View {
    let placeholder: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var height: CGFloat = 40
    var size: CGFloat = 15

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: size))
            .focused(focused)
            .padding(.horizontal, 10)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.05)))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(focused.wrappedValue ? 0.4 : 0.15), lineWidth: 1)
            )
    }
}

enum TimeHint {
    /// What a time field's text parses to, or a nudge toward something that will.
    static func text(for input: String, reference: Int? = nil, isEnd: Bool) -> (text: String, ok: Bool)? {
        guard !input.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        if let minutes = TimeParser.parse(input, reference: reference) {
            return (TimeParser.format(minutes: minutes), true)
        }
        return (isEnd ? "Try 10:15 or 45 minutes after" : "Try 9am, 14:30, or noon", false)
    }

    /// `9:05 AM` with the narrow no-break space macOS puts before AM swapped for a plain one, for editing.
    static func editable(_ minutes: Int) -> String {
        TimeParser.format(minutes: minutes).replacingOccurrences(of: "\u{202F}", with: " ")
    }
}

/// One choice from a few, as a row of capsules: the selected one filled, like the schedule chips.
struct ChipPicker<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 5) {
            ForEach(options.indices, id: \.self) { i in
                let option = options[i]
                let selected = option.value == selection
                Button { selection = option.value } label: {
                    Text(option.label)
                        .font(.system(size: 12, weight: selected ? .semibold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(selected ? Color(nsColor: .textBackgroundColor) : .primary)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 28)
                        .background(Capsule().fill(selected ? Color.primary : Color.primary.opacity(0.06)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}

/// A setting that's on or off: the whole row toggles, with a small switch drawn in the app's colors.
struct ToggleRow: View {
    let title: String
    var detail: String? = nil
    @Binding var isOn: Bool
    @State private var hovering = false

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13))
                    if let detail {
                        Text(detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? Color.primary : Color.primary.opacity(0.15))
                    Circle()
                        .fill(Color(nsColor: .textBackgroundColor))
                        .padding(2)
                }
                .frame(width: 30, height: 18)
                .animation(.easeOut(duration: 0.15), value: isOn)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color.primary.opacity(hovering ? 0.03 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

/// Rows grouped on a soft card, separated by hairlines.
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// A large, selectable answer in a setup question.
struct OptionCard: View {
    let title: String
    let detail: String
    let systemImage: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 17))
                    .frame(width: 22)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(selected ? Color.primary : Color.primary.opacity(0.25))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(selected ? 0.07 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(selected ? 0.6 : 0.1), lineWidth: selected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Buttons

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
    var fullWidth = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(nsColor: .textBackgroundColor))
            .padding(.horizontal, 16)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: fullWidth ? 36 : 32)
            .background(
                RoundedRectangle(cornerRadius: fullWidth ? 10 : 8, style: .continuous)
                    .fill(Color.primary.opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.25))
            )
            .contentShape(Rectangle())
    }
}

/// Plain text button for secondary actions: Cancel, Back, Undo.
struct QuietButtonStyle: ButtonStyle {
    var color: Color = .secondary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(color)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

/// Square icon button for the panel header.
struct IconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.primary.opacity(hovering ? 0.08 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - Panel shape

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
