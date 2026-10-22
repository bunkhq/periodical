// Draws the app icon (same artwork as assets/icon.svg) into a .icns: swift scripts/make-icon.swift <out.icns>
// AppKit's SVG renderer drops `dy` and font weights, so the artwork is drawn directly.
import AppKit

let args = CommandLine.arguments
guard args.count == 2 else {
    FileHandle.standardError.write("usage: make-icon.swift <out.icns>\n".data(using: .utf8)!)
    exit(1)
}

/// Red rounded square with a white semibold "P", in a 64-unit box like the SVG.
func drawIcon(in rect: NSRect) {
    let unit = rect.width / 64
    NSColor(srgbRed: 0xdc / 255.0, green: 0x26 / 255.0, blue: 0x26 / 255.0, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect, xRadius: 14 * unit, yRadius: 14 * unit).fill()
    let text = NSAttributedString(string: "P", attributes: [
        .font: NSFont.systemFont(ofSize: 32 * unit, weight: .semibold),
        .foregroundColor: NSColor.white,
    ])
    let line = CTLineCreateWithAttributedString(text)
    let glyphs = CTLineGetImageBounds(line, nil)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.textPosition = CGPoint(x: rect.midX - glyphs.midX, y: rect.midY - glyphs.midY)
    CTLineDraw(line, ctx)
}

let iconset = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathComponent("icon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// macOS icon grid: the artwork sits inside a 824/1024 box with a little shadow-free margin.
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = points * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let inset = CGFloat(px) * 100 / 1024
        drawIcon(in: NSRect(x: 0, y: 0, width: px, height: px).insetBy(dx: inset, dy: inset))
        NSGraphicsContext.restoreGraphicsState()
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", args[1]]
try task.run()
task.waitUntilExit()
exit(task.terminationStatus)
