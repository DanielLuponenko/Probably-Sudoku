import SwiftUI
import CoreText

/// The approved DlA identity: one continuous camera move into the final i's dot.
struct StudioSplashView: View {
    var reduceMotion: Bool
    var isReadyToAnimate = true
    var onFinished: () -> Void

    @State private var startedAt: Date?
    @State private var hasFinished = false
    @State private var terminalTime: TimeInterval = 0

    private var heldTime: TimeInterval? {
        #if DEBUG && targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-studioSplashTime"),
           index + 1 < arguments.count, let time = Double(arguments[index + 1]), time.isFinite {
            return max(0, min(time, DLALogo.duration))
        }
        if arguments.contains("-holdStudioSplash") { return 0 }
        #endif
        return nil
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 120,
                                    paused: startedAt == nil || heldTime != nil || hasFinished)) { timeline in
                Canvas(opaque: true, rendersAsynchronously: true) { context, size in
                    let elapsed = heldTime ?? (hasFinished
                        ? terminalTime
                        : startedAt.map { timeline.date.timeIntervalSince($0) } ?? 0)
                    DLALogo.draw(in: &context, size: size, elapsed: elapsed, reduceMotion: reduceMotion)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("D L A Game Studio. This is not an i.")
            .task(id: [isReadyToAnimate, reduceMotion]) {
                guard isReadyToAnimate, heldTime == nil, !hasFinished else { return }
                // Do not spend the first part of this clock compiling the room
                // or rasterizing its covers. Its first GPU-completed frame is ready.
                startedAt = .now
                do {
                    let handoff = reduceMotion ? DLALogo.reducedDuration : DLALogo.handoffTime(for: geometry.size)
                    terminalTime = handoff
                    try await Task.sleep(for: .seconds(handoff))
                } catch { return }
                guard !Task.isCancelled, !hasFinished else { return }
                hasFinished = true
                // Reveal the already prepared scene at dot coverage, without a white hold.
                onFinished()
            }
        }
        .ignoresSafeArea()
    }
}

/// Cached glyph outlines stay sharp at 4,500x without rasterizing the logo or loading a web view.
enum DLALogo {
    static let duration: TimeInterval = 3.8
    static let reducedDuration: TimeInterval = 1.4
    static let ink = Color(hex: 0x11100F)
    static let cream = Color(hex: 0xFFF4D7)
    static let red = Color(hex: 0xEE2632)
    static let inscription = "This is not an i"

    static func smooth(_ value: Double) -> Double {
        let x = min(1, max(0, value))
        return x * x * x * (x * (x * 6 - 15) + 10)
    }

    static func camera(elapsed: TimeInterval, size: CGSize, reduceMotion: Bool = false) -> CGAffineTransform {
        let progress = reduceMotion ? 0 : min(1, max(0, (elapsed - 0.35) / 3.2))
        let aim = smooth(progress / 0.68)
        let rotation = smooth(progress / 0.66) * .pi / 2
        let zoom = exp(log(4_500) * pow(progress, 2.3))
        let fit = min(size.width / 740, size.height / 625)
        let focus = CGPoint(x: 500 + (dotCenter.x - 500) * aim,
                            y: 312.5 + (dotCenter.y - 312.5) * aim)
        return CGAffineTransform(translationX: size.width / 2, y: size.height / 2)
            .rotated(by: rotation)
            .scaledBy(x: fit * zoom, y: fit * zoom)
            .translatedBy(x: -focus.x, y: -focus.y)
    }

    /// First instant the dot fills this viewport; the remaining zoom is invisible.
    static func handoffTime(for size: CGSize) -> TimeInterval {
        guard size.width > 0, size.height > 0 else { return 3.55 }
        let corners = [CGPoint.zero, CGPoint(x: size.width, y: 0),
                       CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
        var lower = 0.35
        var upper = 3.55
        for _ in 0..<24 {
            let middle = (lower + upper) / 2
            let projected = dot.applying(camera(elapsed: middle, size: size))
            if corners.allSatisfy({ projected.contains($0) }) { upper = middle }
            else { lower = middle }
        }
        return upper
    }

    static func draw(in context: inout GraphicsContext, size: CGSize, elapsed: TimeInterval, reduceMotion: Bool) {
        let bounds = Path(CGRect(origin: .zero, size: size))
        context.fill(bounds, with: .color(ink))
        var logo = context
        logo.concatenate(camera(elapsed: elapsed, size: size, reduceMotion: reduceMotion))
        logo.fill(d, with: .color(cream), style: FillStyle(eoFill: true))
        logo.fill(a, with: .color(cream), style: FillStyle(eoFill: true))
        logo.fill(l, with: .color(red))
        logo.fill(lettering.path, with: .color(cream), style: FillStyle(eoFill: true))
        logo.fill(subtitle, with: .color(cream), style: FillStyle(eoFill: true))
        if reduceMotion {
            // No rotation or magnification for Reduce Motion; keep the same cream handoff.
            context.fill(bounds, with: .color(cream.opacity(smooth((elapsed - 1.0) / 0.4))))
        }
    }

    private static let base = CGAffineTransform(a: 0.9, b: 0, c: 0, d: 0.9, tx: 245, ty: 174)
    static let l = Path(CGRect(x: 256, y: 0, width: 52, height: 233)).applying(base)
    static let d: Path = {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0)); p.addLine(to: CGPoint(x: 77, y: 0))
        p.addQuadCurve(to: CGPoint(x: 174, y: 99), control: CGPoint(x: 174, y: 0))
        p.addLine(to: CGPoint(x: 174, y: 134))
        p.addQuadCurve(to: CGPoint(x: 77, y: 233), control: CGPoint(x: 174, y: 233))
        p.addLine(to: CGPoint(x: 0, y: 233)); p.closeSubpath()
        p.move(to: CGPoint(x: 52, y: 52)); p.addLine(to: CGPoint(x: 52, y: 181))
        p.addLine(to: CGPoint(x: 77, y: 181))
        p.addQuadCurve(to: CGPoint(x: 122, y: 134), control: CGPoint(x: 122, y: 181))
        p.addLine(to: CGPoint(x: 122, y: 99))
        p.addQuadCurve(to: CGPoint(x: 77, y: 52), control: CGPoint(x: 122, y: 52))
        p.closeSubpath()
        return p.applying(base)
    }()
    static let a: Path = {
        var p = Path()
        let outside: [CGPoint] = [(65.0, 0.0), (109, 0), (174, 233), (122, 233),
                                  (108, 185), (66, 185), (52, 233), (0, 233)].map { CGPoint(x: $0.0, y: $0.1) }
        p.addLines(outside); p.closeSubpath()
        p.move(to: CGPoint(x: 87, y: 58)); p.addLine(to: CGPoint(x: 60, y: 135))
        p.addLine(to: CGPoint(x: 114, y: 135)); p.closeSubpath()
        return p.applying(CGAffineTransform(translationX: 390, y: 0)).applying(base)
    }()

    private static let lettering: (path: Path, lastGlyph: CGPath) = {
        let outlines = textOutlines(inscription, font: "ArialMT", size: 15, baseline: 5)
        let transform = CGAffineTransform(a: 0, b: -0.9, c: 0.9, d: 0, tx: 498.8, ty: 278.4)
        var copy = transform
        return (Path(outlines.path).applying(transform), outlines.lastGlyph.copy(using: &copy)!)
    }()

    /// The dot is a separate contour of the final i, found from the same outline we draw.
    static let dot: Path = {
        let contours = subpaths(of: lettering.lastGlyph)
        // The inscription is rotated -90 degrees; the dot is its leftmost contour.
        return Path(contours.min { $0.boundingBoxOfPath.midX < $1.boundingBoxOfPath.midX }!)
    }()
    static let dotCenter = CGPoint(x: dot.boundingRect.midX, y: dot.boundingRect.midY)
    private static let subtitle: Path = {
        let outlines = textOutlines("G A M E   S T U D I O", font: "Courier", size: 22, baseline: 0)
        return Path(outlines.path).applying(CGAffineTransform(a: 0.9, b: 0, c: 0, d: 0.9, tx: 501.5, ty: 445.8))
    }()

    private static func textOutlines(_ text: String, font name: String, size: CGFloat, baseline: CGFloat) -> (path: CGPath, lastGlyph: CGPath) {
        let font = CTFontCreateWithName(name as CFString, size, nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]))
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        let path = CGMutablePath()
        var last = CGPath(rect: .zero, transform: nil)
        for run in CTLineGetGlyphRuns(line) as! [CTRun] {
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            for index in 0..<count {
                var transform = CGAffineTransform(a: 1, b: 0, c: 0, d: -1,
                                                 tx: positions[index].x - width / 2, ty: baseline - positions[index].y)
                if let glyph = CTFontCreatePathForGlyph(font, glyphs[index], &transform) {
                    path.addPath(glyph)
                    last = glyph
                }
            }
        }
        return (path, last)
    }

    private static func subpaths(of path: CGPath) -> [CGPath] {
        var contours: [CGPath] = []
        var current = CGMutablePath()
        path.applyWithBlock { pointer in
            let element = pointer.pointee
            switch element.type {
            case .moveToPoint: current = CGMutablePath(); current.move(to: element.points[0])
            case .addLineToPoint: current.addLine(to: element.points[0])
            case .addQuadCurveToPoint: current.addQuadCurve(to: element.points[1], control: element.points[0])
            case .addCurveToPoint: current.addCurve(to: element.points[2], control1: element.points[0], control2: element.points[1])
            case .closeSubpath: current.closeSubpath(); contours.append(current.copy()!)
            @unknown default: break
            }
        }
        return contours
    }
}

#Preview {
    StudioSplashView(reduceMotion: false, onFinished: {})
}
