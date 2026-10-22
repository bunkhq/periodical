import AppKit
import SwiftUI

enum Palette {
    static let colors: [String] = [
        "#FF3A3A", "#FF6B4A", "#FF9500", "#FFB800", "#FFD60A", "#C7D530",
        "#34C759", "#1FA463", "#0B7A55", "#00C7BE", "#30B0C7", "#32ADE6",
        "#007AFF", "#3F5EFB", "#5856D6", "#7B4AE2", "#AF52DE", "#D14FC4",
        "#FF2D92", "#FF375F", "#C2185B", "#7A1F3D", "#A2845E", "#6D4C3D",
        "#8E8E93", "#6D7B8D", "#48484A", "#1C1C1E", "#2E3A87", "#0F4C5C",
    ]
}

extension Color {
    init(hex: String) {
        self.init(nsColor: NSColor(hex: hex))
    }

    /// White or near-black, whichever reads better on `hex`.
    static func foreground(onHex hex: String) -> Color {
        NSColor(hex: hex).relativeLuminance > 0.55 ? Color.black.opacity(0.85) : .white
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
}
