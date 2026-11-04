// Draws the app icon (same artwork as assets/icon.svg) into a .icns: swift scripts/make-icon.swift <out.icns>
// AppKit's SVG renderer drops gradients, masks, and filters, so the artwork is drawn directly with Core Graphics.
// Coordinates are the SVG's 1024-unit grid with y pointing down.
import AppKit

let args = CommandLine.arguments
guard args.count == 2 else {
    FileHandle.standardError.write("usage: make-icon.swift <out.icns>\n".data(using: .utf8)!)
    exit(1)
}

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func gradient(_ stops: [(CGFloat, CGColor)]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: stops.map(\.1) as CFArray,
               locations: stops.map(\.0))!
}

/// A soft blob standing in for a blurred ellipse: a radial gradient squashed to `rx` by `ry`, rotated by `degrees`.
func blob(_ ctx: CGContext, center: CGPoint, rx: CGFloat, ry: CGFloat, degrees: CGFloat = 0, color: UInt32, alpha: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: degrees * .pi / 180)
    ctx.scaleBy(x: rx, y: ry)
    ctx.drawRadialGradient(gradient([(0, rgb(color, alpha)), (0.5, rgb(color, alpha * 0.6)), (1, rgb(color, 0))]),
                           startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 1, options: [])
    ctx.restoreGState()
}

func ellipse(_ ctx: CGContext, center: CGPoint, rx: CGFloat, ry: CGFloat, degrees: CGFloat = 0, color: CGColor) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: degrees * .pi / 180)
    ctx.setFillColor(color)
    ctx.fillEllipse(in: CGRect(x: -rx, y: -ry, width: rx * 2, height: ry * 2))
    ctx.restoreGState()
}

/// Dot, the period with eyes, on a yellow tile. `px` is the bitmap's edge length.
/// At 32px and below Dot is drawn larger and simpler so the face survives: at 16px the eyes are plain white
/// and the smile and highlights are left out.
func drawIcon(_ ctx: CGContext, px: CGFloat) {
    let unit = px / 1024
    let small = px <= 32, tiny = px <= 16
    ctx.translateBy(x: 0, y: px)
    ctx.scaleBy(x: unit, y: -unit)

    // Tile with its drop shadow. Shadow offsets ignore the CTM, so they are in device pixels, y up.
    let tile = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185.4, cornerHeight: 185.4, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10 * unit), blur: 24 * unit, color: rgb(0x000000, 0.24))
    ctx.addPath(tile)
    ctx.setFillColor(rgb(0xFFD030))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tile)
    ctx.clip()
    ctx.drawLinearGradient(gradient([(0, rgb(0xFFE45A)), (1, rgb(0xFFC00C))]),
                           start: CGPoint(x: 0, y: 100), end: CGPoint(x: 0, y: 924), options: [])
    ctx.drawRadialGradient(gradient([(0, rgb(0xFFF6B8, 0.7)), (1, rgb(0xFFF6B8, 0))]),
                           startCenter: CGPoint(x: 347, y: 248), startRadius: 0,
                           endCenter: CGPoint(x: 347, y: 248), endRadius: 618, options: [])

    let center = CGPoint(x: 530, y: 540), r: CGFloat = 250
    let ball = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)

    // Contact shadow on the tile.
    blob(ctx, center: CGPoint(x: 540, y: 802), rx: 250, ry: 64, color: 0x9A6200, alpha: 0.5)

    if small {
        ctx.translateBy(x: center.x, y: center.y)
        ctx.scaleBy(x: 1.16, y: 1.16)
        ctx.translateBy(x: -center.x, y: -center.y)
    }

    // Body: glossy ink, lit from the top left.
    ctx.saveGState()
    ctx.addEllipse(in: ball)
    ctx.clip()
    let light = CGPoint(x: 460, y: 440)
    ctx.drawRadialGradient(gradient([(0, rgb(0x55555C)), (0.5, rgb(0x232326)), (1, rgb(0x0B0B0C))]),
                           startCenter: light, startRadius: 0, endCenter: light, endRadius: 390,
                           options: [.drawsAfterEndLocation])

    // Rim light: yellow bounce from the tile along the lower right edge.
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.drawRadialGradient(gradient([(0.72, rgb(0xFFC21A, 0)), (1, rgb(0xFFC21A, 0.7))]),
                           startCenter: center, startRadius: 0, endCenter: center, endRadius: r, options: [])
    ctx.setBlendMode(.destinationIn)
    ctx.drawLinearGradient(gradient([(0.45, rgb(0xFFFFFF, 0)), (1, rgb(0xFFFFFF, 1))]),
                           start: CGPoint(x: ball.minX + 0.15 * ball.width, y: ball.minY + 0.1 * ball.height),
                           end: CGPoint(x: ball.minX + 0.85 * ball.width, y: ball.minY + 0.95 * ball.height),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.endTransparencyLayer()
    ctx.restoreGState()

    // Specular highlights.
    if !tiny {
        blob(ctx, center: CGPoint(x: 430, y: 390), rx: 118, ry: 64, degrees: -38, color: 0xFFFFFF, alpha: 0.2)
        ellipse(ctx, center: CGPoint(x: 404, y: 372), rx: 30, ry: 14, degrees: -38, color: rgb(0xFFFFFF, 0.5))
    }

    // Eyes, glancing up and to the right.
    // At 16px the eyes spread apart and grow only taller, so a pixel of ink stays between them.
    let grow: CGFloat = small ? 1.12 : 1
    let eyes: [CGFloat] = tiny ? [462, 638] : [478, 622]
    for x in eyes {
        let rx: CGFloat = tiny ? 54 : 54 * grow, ry: CGFloat = tiny ? 70 * 1.25 : 70 * grow
        let eye = CGRect(x: x - rx, y: 506 - ry, width: rx * 2, height: ry * 2)
        ctx.saveGState()
        ctx.addEllipse(in: eye)
        ctx.clip()
        ctx.drawLinearGradient(gradient([(0.55, rgb(0xFFFFFF)), (1, rgb(0xE4E4EC))]),
                               start: CGPoint(x: 0, y: eye.minY), end: CGPoint(x: 0, y: eye.maxY),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
        if tiny { continue }
        ellipse(ctx, center: CGPoint(x: x + 15, y: 499), rx: 31 * grow, ry: 31 * grow, color: rgb(0x0B0B0C))
        ellipse(ctx, center: CGPoint(x: x + 25, y: 487), rx: 10, ry: 10, color: rgb(0xFFFFFF))
    }

    // Smile.
    if !tiny {
        ctx.move(to: CGPoint(x: 520, y: 626))
        ctx.addQuadCurve(to: CGPoint(x: 584, y: 626), control: CGPoint(x: 552, y: 656))
        ctx.setStrokeColor(rgb(0xFFFFFF))
        ctx.setLineWidth(17)
        ctx.setLineCap(.round)
        ctx.strokePath()
    }
    ctx.restoreGState()
}

let iconset = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)
    .appendingPathComponent("icon.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

// macOS icon grid: the tile sits inside an 824/1024 box, leaving room for its shadow.
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = points * scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        drawIcon(NSGraphicsContext.current!.cgContext, px: CGFloat(px))
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
