import SwiftUI

/// The hourglass icons (16×20 viewBox). Fill with `eoFill` so the sand cut-out shows through.
struct Hourglass: Shape {
    enum Kind {
        /// `assets/TimeIcon.svg`: sand settled at the bottom. Upcoming blocks.
        case starting
        /// `assets/Active.svg`: sand still at the top. The block running now.
        case active
    }

    var kind: Kind = .starting

    func path(in rect: CGRect) -> Path {
        var p = Path()
        // Outer glass
        p.move(to: CGPoint(x: 1.33333, y: 0))
        p.addCurve(to: CGPoint(x: 0, y: 1.25), control1: CGPoint(x: 0.595833, y: 0), control2: CGPoint(x: 0, y: 0.558594))
        p.addCurve(to: CGPoint(x: 1.33333, y: 2.5), control1: CGPoint(x: 0, y: 1.94141), control2: CGPoint(x: 0.595833, y: 2.5))
        p.addLine(to: CGPoint(x: 1.33333, y: 2.92969))
        p.addCurve(to: CGPoint(x: 3.2875, y: 7.34766), control1: CGPoint(x: 1.33333, y: 4.58594), control2: CGPoint(x: 2.0375, y: 6.17578))
        p.addLine(to: CGPoint(x: 6.11667, y: 10))
        p.addLine(to: CGPoint(x: 3.2875, y: 12.6523))
        p.addCurve(to: CGPoint(x: 1.33333, y: 17.0703), control1: CGPoint(x: 2.0375, y: 13.8242), control2: CGPoint(x: 1.33333, y: 15.4141))
        p.addLine(to: CGPoint(x: 1.33333, y: 17.5))
        p.addCurve(to: CGPoint(x: 0, y: 18.75), control1: CGPoint(x: 0.595833, y: 17.5), control2: CGPoint(x: 0, y: 18.0586))
        p.addCurve(to: CGPoint(x: 1.33333, y: 20), control1: CGPoint(x: 0, y: 19.4414), control2: CGPoint(x: 0.595833, y: 20))
        p.addLine(to: CGPoint(x: 14.6667, y: 20))
        p.addCurve(to: CGPoint(x: 16, y: 18.75), control1: CGPoint(x: 15.4042, y: 20), control2: CGPoint(x: 16, y: 19.4414))
        p.addCurve(to: CGPoint(x: 14.6667, y: 17.5), control1: CGPoint(x: 16, y: 18.0586), control2: CGPoint(x: 15.4042, y: 17.5))
        p.addLine(to: CGPoint(x: 14.6667, y: 17.0703))
        p.addCurve(to: CGPoint(x: 12.7125, y: 12.6523), control1: CGPoint(x: 14.6667, y: 15.4141), control2: CGPoint(x: 13.9625, y: 13.8242))
        p.addLine(to: CGPoint(x: 9.88333, y: 10))
        p.addLine(to: CGPoint(x: 12.7125, y: 7.34766))
        p.addCurve(to: CGPoint(x: 14.6667, y: 2.92969), control1: CGPoint(x: 13.9625, y: 6.17578), control2: CGPoint(x: 14.6667, y: 4.58594))
        p.addLine(to: CGPoint(x: 14.6667, y: 2.5))
        p.addCurve(to: CGPoint(x: 16, y: 1.25), control1: CGPoint(x: 15.4042, y: 2.5), control2: CGPoint(x: 16, y: 1.94141))
        p.addCurve(to: CGPoint(x: 14.6667, y: 0), control1: CGPoint(x: 16, y: 0.558594), control2: CGPoint(x: 15.4042, y: 0))
        p.closeSubpath()

        // Sand cut-out. Active.svg is TimeIcon.svg's cut-out flipped top to bottom.
        var sand = Path()
        sand.move(to: CGPoint(x: 12, y: 17.0703))
        sand.addLine(to: CGPoint(x: 12, y: 17.5))
        sand.addLine(to: CGPoint(x: 4, y: 17.5))
        sand.addLine(to: CGPoint(x: 4, y: 17.0703))
        sand.addCurve(to: CGPoint(x: 5.17083, y: 14.418), control1: CGPoint(x: 4, y: 16.0742), control2: CGPoint(x: 4.42083, y: 15.1211))
        sand.addLine(to: CGPoint(x: 8, y: 11.7656))
        sand.addLine(to: CGPoint(x: 10.8292, y: 14.418))
        sand.addCurve(to: CGPoint(x: 12, y: 17.0703), control1: CGPoint(x: 11.5792, y: 15.1211), control2: CGPoint(x: 12, y: 16.0742))
        sand.closeSubpath()

        p.addPath(kind == .active ? sand.applying(CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 20)) : sand)

        return p.applying(
            CGAffineTransform(translationX: rect.minX, y: rect.minY)
                .scaledBy(x: rect.width / 16, y: rect.height / 20)
        )
    }
}
