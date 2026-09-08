import SwiftUI
import ProbablySudokuEngine

/// The page owns the space; this isolated clock owns only decorative ink.
/// No frame tick is published to the game model or surrounding layout.
struct BookAmbientBackground: View {
    let book: Book
    var isActive: Bool = true
    var presentation: BookAmbientPresentation = .pageMargins

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.bossMotionIsActive) private var presentationMotionIsActive
    @AppStorage(AppPreferences.Key.ambientMotion) private var ambientMotion = true
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var motionClock = BossMotionClock()

    private var animates: Bool {
        BookAmbientMotionPolicy.shouldAnimate(
            isActive: isActive && ambientMotion && presentationMotionIsActive, sceneIsActive: scenePhase == .active,
            reduceMotion: reduceMotion, lowPower: lowPower)
    }

    var body: some View {
        let theme = BookPresentationTheme(book: book)
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !animates)) { _ in
            let elapsed = motionClock.elapsed(at: ProcessInfo.processInfo.systemUptime)
            switch presentation {
            case .pageMargins: BookAmbientArtwork(theme: theme, time: elapsed)
            case .interlude: BookInterludeArtwork(book: book, time: elapsed)
            case .livingScene: BookLivingSceneArtwork(book: book, time: elapsed)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .onAppear {
            motionClock.setRunning(animates, at: ProcessInfo.processInfo.systemUptime)
        }
        .onChange(of: animates) { _, active in
            motionClock.setRunning(active, at: ProcessInfo.processInfo.systemUptime)
        }
        .onDisappear {
            motionClock.setRunning(false, at: ProcessInfo.processInfo.systemUptime)
        }
    }
}

enum BookAmbientPresentation { case pageMargins, interlude, livingScene }

/// Places ornamental ink outside the reading column without changing its size.
struct BookPageMarginPlacement: ViewModifier {
    func body(content: Content) -> some View {
        content
            .mask {
                HStack(spacing: 0) {
                    Rectangle().frame(width: Volume.pageContentInsets.leading - 2)
                    Spacer(minLength: 0)
                    Rectangle().frame(width: Volume.pageContentInsets.trailing - 2)
                }
            }
            // The background receives the reading-column proposal, not the
            // whole sheet. Expand only this decoration into PageSurface's
            // existing padding; leave a two-point gap beside all content.
            .padding(.leading, -Volume.pageContentInsets.leading)
            .padding(.trailing, -Volume.pageContentInsets.trailing)
    }
}

/// Compatibility for result-page callers: the richer artwork uses exactly the
/// height provided by that page, just like the dedicated briefing vignette.
struct BookInterludeAnimation: View {
    let book: Book
    var isActive: Bool = true

    var body: some View {
        BookLivingScene(book: book, isActive: isActive)
    }
}

struct BookInterludeArtwork: View {
    let book: Book
    var time: TimeInterval = 0

    var body: some View {
        BookLivingSceneArtwork(book: book, time: time)
    }
}

/// Stateless artwork is shared by the live surface and deterministic render
/// tests. Ink is clipped to the outside 18 points, leaving every central label,
/// card and board untouched even on the smallest supported phone.
struct BookAmbientArtwork: View {
    let theme: BookPresentationTheme
    var time: TimeInterval = 0

    static func marginWidth(for size: CGSize) -> CGFloat {
        min(18, max(0, size.width * 0.055))
    }

    var body: some View {
        Canvas { context, size in
            let margin = Self.marginWidth(for: size)
            var clip = Path()
            clip.addRect(CGRect(x: 0, y: 0, width: margin, height: size.height))
            clip.addRect(CGRect(x: size.width - margin, y: 0, width: margin, height: size.height))
            context.clip(to: clip)

            let phase = time.isFinite ? max(0, time) : 0
            // Two deliberately cropped pieces of stationery, not four tiny
            // repeated symbols. The scene in its own slot carries the action;
            // these larger edge fragments tie the entire page to that Book.
            for side in 0..<2 {
                var edge = context
                edge.opacity = 0.43
                edge.translateBy(x: side == 0 ? 0 : size.width,
                                 y: size.height * (side == 0 ? 0.24 : 0.73))
                edge.scaleBy(x: side == 0 ? 1 : -1, y: 1)
                edge.translateBy(x: sin(phase * 0.55 + Double(side)) * 2,
                                 y: cos(phase * 0.4 + Double(side)) * 7)
                drawEdge(in: &edge, phase: phase + Double(side) * 2.1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawEdge(in context: inout GraphicsContext, phase: Double) {
        var path = Path()
        let sway = CGFloat(sin(phase * 0.8))
        switch theme.book {
        case .probably:
            // Three long playing-card corners peek out from the binding.
            for sheet in 0..<3 {
                let y = CGFloat(sheet) * 26 - 58
                path.addRoundedRect(in: CGRect(x: -27, y: y, width: 34 + CGFloat(sheet) * 4,
                                              height: 74), cornerSize: CGSize(width: 3, height: 3))
            }
        case .slightlyHarder:
            for coin in 0..<3 {
                let y = CGFloat(coin) * 34 - 43 + sway * CGFloat(coin + 1) * 3
                path.addEllipse(in: CGRect(x: -19, y: y, width: 34, height: 34))
                path.addEllipse(in: CGRect(x: -15, y: y + 4, width: 26, height: 26))
            }
        case .noPressure:
            path.move(to: CGPoint(x: 1, y: -63)); path.addLine(to: CGPoint(x: 12, y: -63))
            path.addLine(to: CGPoint(x: 12, y: 43)); path.addLine(to: CGPoint(x: 6.5, y: 62))
            path.addLine(to: CGPoint(x: 1, y: 43)); path.closeSubpath()
            line(&path, from: CGPoint(x: 6.5, y: -50), to: CGPoint(x: 6.5, y: 43))
            line(&path, from: CGPoint(x: 1, y: -51), to: CGPoint(x: 12, y: -51))
            line(&path, from: CGPoint(x: 1, y: 43), to: CGPoint(x: 12, y: 43))
        case .bites:
            path.move(to: CGPoint(x: -25, y: -66)); path.addLine(to: CGPoint(x: 15, y: -66))
            for notch in 0..<6 {
                let y = CGFloat(notch) * 21 - 62
                path.addLine(to: CGPoint(x: 15, y: y)); path.addLine(to: CGPoint(x: 5, y: y + 8))
                path.addLine(to: CGPoint(x: 14, y: y + 15))
            }
            path.addLine(to: CGPoint(x: -25, y: 66)); path.closeSubpath()
        case .genuinely:
            path.move(to: CGPoint(x: 0, y: 65))
            path.addCurve(to: CGPoint(x: 3, y: -63), control1: CGPoint(x: 21 + sway * 5, y: 22),
                          control2: CGPoint(x: -17, y: -21))
            for leaf in 0..<5 {
                let y = CGFloat(leaf) * 25 - 59
                path.addEllipse(in: CGRect(x: leaf.isMultiple(of: 2) ? -12 : 2,
                                           y: y, width: 20, height: 14))
            }
        case .snackBreak:
            for curl in 0..<3 {
                let x = CGFloat(curl) * 8 - 1
                path.move(to: CGPoint(x: x, y: 58))
                path.addCurve(to: CGPoint(x: x + sway * 5, y: -63),
                              control1: CGPoint(x: x - 19 - sway * 8, y: 18),
                              control2: CGPoint(x: x + 17 + sway * 7, y: -19))
            }
        case .trustMe:
            path.addRect(CGRect(x: -19, y: -61, width: 31, height: 122))
            let y = sway * 41
            path.addRoundedRect(in: CGRect(x: -12, y: y - 16, width: 28, height: 32),
                                cornerSize: CGSize(width: 4, height: 4))
            for rib in 0..<4 {
                line(&path, from: CGPoint(x: 0, y: y - 10 + CGFloat(rib) * 6),
                     to: CGPoint(x: 11, y: y - 10 + CGFloat(rib) * 6))
            }
        case .overthinking:
            for bracket in 0..<3 {
                let x = CGFloat(bracket) * 6, y = CGFloat(bracket) * 12
                path.move(to: CGPoint(x: -8, y: -62 + y)); path.addLine(to: CGPoint(x: x, y: -62 + y))
                path.addLine(to: CGPoint(x: x, y: 62 - y)); path.addLine(to: CGPoint(x: -8, y: 62 - y))
            }
        case .smallVictories:
            path.move(to: CGPoint(x: -5, y: 64))
            path.addQuadCurve(to: CGPoint(x: 0, y: -65), control: CGPoint(x: 20 + sway * 4, y: 1))
            for leaf in 0..<7 {
                let y = CGFloat(leaf) * 17 - 56
                path.move(to: CGPoint(x: 4, y: y + 13))
                path.addQuadCurve(to: CGPoint(x: 15, y: y), control: CGPoint(x: 17, y: y + 9))
                path.addQuadCurve(to: CGPoint(x: 4, y: y + 13), control: CGPoint(x: 3, y: y + 2))
            }
        case .rainyDay:
            for drop in 0..<9 {
                let p = (phase * 0.20 + Double(drop) * 0.117).truncatingRemainder(dividingBy: 1)
                let x = CGFloat(drop % 3) * 7, y = CGFloat(p) * 126 - 63
                line(&path, from: CGPoint(x: x + 3, y: y), to: CGPoint(x: x - 2, y: y + 16))
            }
        case .secondThoughts:
            path.addRect(CGRect(x: -34, y: -62 - sway * 9, width: 44, height: 109))
            path.addRect(CGRect(x: -30, y: -43 + sway * 9, width: 44, height: 109))
            for rule in 0..<6 {
                line(&path, from: CGPoint(x: -11, y: CGFloat(rule) * 14 - 30 + sway * 9),
                     to: CGPoint(x: 8, y: CGFloat(rule) * 14 - 30 + sway * 9))
            }
        case .wellEarned:
            for notch in 0..<36 {
                let a = Double(notch) * .pi / 18
                let radius: CGFloat = notch.isMultiple(of: 2) ? 44 : 40
                let point = CGPoint(x: -28 + CGFloat(cos(a)) * radius, y: CGFloat(sin(a)) * radius)
                if notch == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            for crumb in 0..<4 {
                path.addEllipse(in: CGRect(x: CGFloat(crumb % 2) * 8 + 1,
                                           y: 48 + CGFloat(crumb) * 8 + sway * 3, width: 3, height: 3))
            }
        }
        context.stroke(path, with: .color(theme.buttonFill),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
    }

    private func line(_ path: inout Path, from start: CGPoint, to end: CGPoint) {
        path.move(to: start)
        path.addLine(to: end)
    }

}
