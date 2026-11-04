import AppKit
import SwiftUI

enum Palette {
    /// Hex and a spoken name for VoiceOver.
    static let swatches: [(hex: String, name: String)] = [
        ("#FF3A3A", "Red"), ("#FF6B4A", "Coral"), ("#FF9500", "Orange"), ("#FFB800", "Amber"), ("#FFD60A", "Yellow"), ("#C7D530", "Lime"),
        ("#34C759", "Green"), ("#1FA463", "Emerald"), ("#0B7A55", "Forest"), ("#00C7BE", "Teal"), ("#30B0C7", "Cyan"), ("#32ADE6", "Sky"),
        ("#007AFF", "Blue"), ("#3F5EFB", "Royal Blue"), ("#5856D6", "Indigo"), ("#7B4AE2", "Violet"), ("#AF52DE", "Purple"), ("#D14FC4", "Orchid"),
        ("#FF2D92", "Pink"), ("#FF375F", "Rose"), ("#C2185B", "Raspberry"), ("#7A1F3D", "Wine"), ("#A2845E", "Tan"), ("#6D4C3D", "Brown"),
        ("#8E8E93", "Gray"), ("#6D7B8D", "Slate"), ("#48484A", "Graphite"), ("#1C1C1E", "Black"), ("#2E3A87", "Navy"), ("#0F4C5C", "Deep Teal"),
    ]

    static var colors: [String] { swatches.map(\.hex) }

    static func name(of hex: String) -> String {
        swatches.first { $0.hex.caseInsensitiveCompare(hex) == .orderedSame }?.name ?? "Custom color"
    }

    /// The first palette color no block uses yet, stepping by seven so neighbors in a day differ in hue.
    static func suggestion(avoiding used: [String]) -> String {
        let taken = Set(used.map { $0.uppercased() })
        let order = (0..<colors.count).map { $0 * 7 % colors.count }
        return order.map { colors[$0] }.first { !taken.contains($0) } ?? colors[0]
    }
}

extension Color {
    init(hex: String) {
        self.init(nsColor: NSColor(hex: hex))
    }

    /// White or near-black, whichever reads better on `hex`.
    static func foreground(onHex hex: String) -> Color {
        Color(nsColor: NSColor.foreground(onHex: hex))
    }
}

extension NSColor {
    convenience init(hex: String) {
        let value = UInt32(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x8E8E93
        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    var relativeLuminance: CGFloat {
        guard let c = usingColorSpace(.sRGB) else { return 0 }
        func linear(_ v: CGFloat) -> CGFloat { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(c.redComponent) + 0.7152 * linear(c.greenComponent) + 0.0722 * linear(c.blueComponent)
    }

    /// White while it keeps at least 3:1 contrast (luminance up to 0.30), else near-black.
    /// Leaning white keeps reds, blues, and purples looking like themselves; past 0.30, white text
    /// on orange, green, teal, or sky fades to about 2:1 and black reads far better.
    static func foreground(onHex hex: String) -> NSColor {
        NSColor(hex: hex).relativeLuminance > 0.30 ? NSColor.black.withAlphaComponent(0.85) : .white
    }
}
