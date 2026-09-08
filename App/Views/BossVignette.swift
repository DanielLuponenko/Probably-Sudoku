import SwiftUI
import ProbablySudokuEngine

extension EnvironmentValues {
    /// The page owner stops decorative ink when a sheet or a page turn covers
    /// it. This is deliberately a coarse flag, never a per-frame clock.
    @Entry var bossMotionIsActive = true
}

/// A visual vocabulary, not another set of Boss rules. Each signature refers
/// to its real restriction; none invents a blocked cell or reveals a solution.
enum BossInkSignature: String, CaseIterable {
    case redaction, edit, eightTicks, mist, doubleStrike, reflection, clueGate
    case crossedToss, receipt, fourWeights, sleepingBookmark, sealedBuffs
    case halfCut, shred, debit, clock, barredPair, rowBrackets, boxBrackets

    init(boss: BossModifier) {
        switch boss {
        case .censor: self = .redaction
        case .editor: self = .edit
        case .deadline: self = .eightTicks
        case .fog: self = .mist
        case .critic: self = .doubleStrike
        case .mirror: self = .reflection
        case .paywall: self = .clueGate
        case .erratum: self = .crossedToss
        case .collector: self = .receipt
        case .heavyLifter: self = .fourWeights
        case .unluckyLucky: self = .sleepingBookmark
        case .buffborger: self = .sealedBuffs
        case .sashimi: self = .halfCut
        case .overPusher: self = .shred
        case .accountant: self = .debit
        case .tikTak: self = .clock
        case .handyDandy: self = .barredPair
        case .grayTheGarry: self = .rowBrackets
        case .garryTheGray: self = .boxBrackets
        }
    }

    var duration: Double {
        switch self {
        case .clock: 6
        case .eightTicks: 8
        case .mist: 14
        case .fourWeights, .sealedBuffs, .clueGate: 11
        case .edit, .crossedToss, .doubleStrike: 7
        default: 10
        }
    }
}

/// The compact route artwork stays a square ink-stained Sudoku, rather than a
/// portrait card or an emblem covering the grid. Its numbers are illustrative,
/// fixed givens from a valid Sudoku, not a preview of the hidden puzzle solution.
struct BossRouteArtwork: View {
    let boss: BossModifier
    var isActive = true
    var reduceMotionOverride: Bool? = nil
    /// A fixed phase for deterministic design proofs; live callers omit it.
    var phaseOverride: Double? = nil

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Image("BossInkStain")
                    .resizable()
                    .interpolation(.high)
                    .frame(width: side, height: side)
                BossRouteGrid()
                    .padding(side * 0.115)
                BossPerimeterVignette(boss: boss, isActive: isActive, surface: .route,
                                      reduceMotionOverride: reduceMotionOverride,
                                      phaseOverride: phaseOverride)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct BossRouteGrid: View {
    // Deliberately static and sparse. Red ink is an editorial accent, not an
    // invented game-state error, and no glyph jumps or fades during a cycle.
    private static let givens: [(index: Int, digit: Int)] = [
        (2, 4), (6, 9), (15, 3), (18, 1), (25, 6), (26, 7),
        (35, 3), (39, 8), (47, 3), (51, 8), (63, 2), (76, 8), (79, 7)
    ]

    var body: some View {
        Canvas { context, size in
            let cell = size.width / 9
            let ivory = Color(red: 0.88, green: 0.85, blue: 0.71)
            for index in 0...9 {
                var rules = Path()
                rules.move(to: CGPoint(x: CGFloat(index) * cell, y: 0))
                rules.addLine(to: CGPoint(x: CGFloat(index) * cell, y: size.height))
                rules.move(to: CGPoint(x: 0, y: CGFloat(index) * cell))
                rules.addLine(to: CGPoint(x: size.width, y: CGFloat(index) * cell))
                context.stroke(rules, with: .color(ivory.opacity(index.isMultiple(of: 3) ? 0.14 : 0.07)),
                               lineWidth: index.isMultiple(of: 3) ? 0.7 : 0.4)
            }
            for given in Self.givens {
                let red = given.index == 18 || given.index == 47
                let glyph = Text(verbatim: String(given.digit))
                    .font(Print.numeral(cell * 0.71, weight: .medium))
                    .foregroundStyle(red ? Color(red: 0.73, green: 0.34, blue: 0.23) : ivory.opacity(0.88))
                context.draw(glyph, at: CGPoint(x: (CGFloat(given.index % 9) + 0.5) * cell,
                                               y: (CGFloat(given.index / 9) + 0.5) * cell))
            }
        }
    }
}

enum BossVignetteSurface {
    case route, gameplay, signature

    var edgeFraction: CGFloat {
        switch self {
        case .route: 0.10
        case .gameplay: 0.030
        case .signature: 0.20
        }
    }
}

/// A small ink seal identifies the Boss before reading the rule. Its glyph
/// stays fixed; the same rule-linked perimeter used on the grid supplies the
/// motion. It takes no layout space from the board and owns no interaction.
struct BossSignatureBadge: View {
    let boss: BossModifier
    var isActive = true
    var side: CGFloat = 26
    var phaseOverride: Double? = nil
    var reduceMotionOverride: Bool? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Paper.pageWarm)
                .overlay {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Paper.ink.opacity(0.24), lineWidth: 0.7)
                }
            Image(systemName: BossBoardDesign(boss: boss).symbol)
                .resizable()
                .scaledToFit()
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(Paper.ink)
                .padding(side * 0.22)
            BossPerimeterVignette(boss: boss, isActive: isActive, surface: .signature,
                                  reduceMotionOverride: reduceMotionOverride,
                                  phaseOverride: phaseOverride)
        }
        .frame(width: side, height: side)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A monotonic decorative clock. Pausing freezes the last accumulated phase;
/// returning from Settings or an interruption never jumps to wall-clock time.
struct BossMotionClock: Equatable {
    private(set) var accumulated: TimeInterval = 0
    private(set) var startedAt: TimeInterval?

    mutating func setRunning(_ running: Bool, at now: TimeInterval) {
        guard now.isFinite else { return }
        if running {
            if startedAt == nil { startedAt = now }
        } else if let start = startedAt {
            accumulated += max(0, now - start)
            startedAt = nil
        }
    }

    func elapsed(at now: TimeInterval) -> TimeInterval {
        guard let start = startedAt, now.isFinite else { return accumulated }
        return accumulated + max(0, now - start)
    }

    func phase(at now: TimeInterval, duration: TimeInterval) -> Double {
        guard duration.isFinite, duration > 0 else { return 0 }
        return elapsed(at: now).truncatingRemainder(dividingBy: duration) / duration
    }
}

/// Only this tiny Canvas receives the clock. The 81 cells, their hit targets,
/// score and static ink image never subscribe to ambient animation updates.
struct BossPerimeterVignette: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.bossMotionIsActive) private var presentationIsActive
    @AppStorage(AppPreferences.Key.ambientMotion) private var ambientMotion = true
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var motionClock = BossMotionClock()
    let boss: BossModifier
    var isActive = true
    var surface: BossVignetteSurface = .gameplay
    var urgent = false
    var reduceMotionOverride: Bool? = nil
    var phaseOverride: Double? = nil

    private var runs: Bool {
        phaseOverride == nil && isActive && presentationIsActive && ambientMotion && scenePhase == .active
            && !(reduceMotionOverride ?? reduceMotion) && !lowPower
    }

    var body: some View {
        Group {
            if let phaseOverride {
                BossPerimeterDrawing(boss: boss, phase: phaseOverride, surface: surface, urgent: urgent)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !runs)) { _ in
                    let signature = BossInkSignature(boss: boss)
                    let phase = motionClock.phase(at: ProcessInfo.processInfo.systemUptime,
                                                  duration: signature.duration)
                    BossPerimeterDrawing(boss: boss, phase: phase, surface: surface, urgent: urgent)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            let updated = ProcessInfo.processInfo.isLowPowerModeEnabled
            if lowPower != updated { lowPower = updated }
        }
        .onChange(of: runs, initial: true) { _, active in
            motionClock.setRunning(active, at: ProcessInfo.processInfo.systemUptime)
        }
        .onDisappear {
            motionClock.setRunning(false, at: ProcessInfo.processInfo.systemUptime)
        }
    }
}

/// Testable, deterministic phase renderer. A hard perimeter clip prevents any
/// motif—even a wide clock hand or moving receipt line—from touching digits.
struct BossPerimeterDrawing: View {
    let boss: BossModifier
    var phase: Double
    var surface: BossVignetteSurface = .gameplay
    var urgent = false

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            guard side > 0 else { return }
            let bounds = CGRect(x: 0, y: 0, width: side, height: side)
            let edge = side * surface.edgeFraction
            var ring = Path(bounds)
            ring.addRect(bounds.insetBy(dx: edge, dy: edge))
            context.clip(to: ring, style: FillStyle(eoFill: true))
            let design = BossBoardDesign(boss: boss)
            let ink: Color = switch surface {
            case .route: Color(red: 0.78, green: 0.70, blue: 0.52).opacity(0.42)
            case .gameplay: (urgent ? Paper.redPencil : design.ink).opacity(urgent ? 0.62 : 0.42)
            case .signature: Paper.ink.opacity(0.92)
            }
            let step = CGFloat(phase * 2 * .pi)
            let breathe = (sin(step) + 1) * 0.5
            let width = surface == .signature ? max(1, side * 0.045) : max(0.8, side * 0.003)
            let outerFraction: CGFloat = switch surface {
            case .route: 0.068
            case .gameplay: 0.012
            case .signature: 0.045
            }
            let outer = side * outerFraction
            let inner = max(outer + width, edge - width)
            let span = side - 2 * outer

            func line(_ points: [CGPoint], color: Color = ink, weight: CGFloat = width) {
                guard let first = points.first else { return }
                var path = Path()
                path.move(to: first)
                for point in points.dropFirst() { path.addLine(to: point) }
                context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: weight, lineCap: .round))
            }
            func topLine(_ start: CGFloat, _ end: CGFloat, y: CGFloat = outer,
                         color: Color = ink, weight: CGFloat = width) {
                line([CGPoint(x: side * start, y: y), CGPoint(x: side * end, y: y)], color: color, weight: weight)
            }
            func box(_ rect: CGRect, color: Color = ink, weight: CGFloat = width) {
                context.stroke(Path(rect), with: .color(color), lineWidth: weight)
            }

            switch BossInkSignature(boss: boss) {
            case .redaction:
                for index in 0..<4 {
                    let x = side * (0.13 + CGFloat(index) * 0.2)
                    let length = side * (index == 1 ? 0.11 + 0.03 * breathe : 0.11)
                    line([CGPoint(x: x, y: outer), CGPoint(x: x + length, y: outer)],
                         color: index == 1 ? Paper.redPencil.opacity(0.62) : ink,
                         weight: width * (index == 1 ? 2.5 : 1.5))
                }
            case .edit:
                topLine(0.11, 0.86, y: inner)
                let x = side * (0.17 + 0.62 * breathe)
                line([CGPoint(x: x - edge * 0.2, y: outer), CGPoint(x: x, y: inner),
                      CGPoint(x: x + edge * 0.2, y: outer)], color: Paper.editorBlue.opacity(0.65))
            case .eightTicks:
                for index in 0..<8 {
                    let x = side * (0.15 + CGFloat(index) * 0.1)
                    let intensity = 0.4 + 0.6 * (sin(step - CGFloat(index) * .pi / 4) + 1) / 2
                    line([CGPoint(x: x, y: outer), CGPoint(x: x, y: inner)], color: ink.opacity(intensity))
                }
            case .mist:
                for band in 0..<3 {
                    var fog = Path()
                    let y = outer + CGFloat(band) * width * 2
                    fog.move(to: CGPoint(x: outer, y: y))
                    fog.addCurve(to: CGPoint(x: side - outer, y: y),
                                 control1: CGPoint(x: side * 0.3, y: y + edge * sin(step + CGFloat(band))),
                                 control2: CGPoint(x: side * 0.7, y: y - edge * sin(step + CGFloat(band))))
                    context.stroke(fog, with: .color(ink.opacity(0.7)), lineWidth: width * 1.5)
                }
            case .doubleStrike:
                for offset in [CGFloat.zero, width * 3] {
                    topLine(0.13, 0.32 + breathe * 0.15, y: outer + offset)
                    topLine(0.63, 0.87, y: outer + offset)
                }
            case .reflection:
                let x = side * (0.1 + 0.25 * breathe)
                line([CGPoint(x: x, y: outer), CGPoint(x: x + side * 0.22, y: outer)])
                line([CGPoint(x: side - x, y: side - outer),
                      CGPoint(x: side - x - side * 0.22, y: side - outer)])
                box(bounds.insetBy(dx: outer, dy: outer), color: ink.opacity(0.25))
            case .clueGate:
                for index in 0..<5 {
                    let x = side * (0.2 + CGFloat(index) * 0.15)
                    line([CGPoint(x: x, y: outer), CGPoint(x: x, y: inner)], weight: width * 1.6)
                }
                topLine(0.2, 0.8, y: outer + (inner - outer) * breathe)
            case .crossedToss:
                topLine(0.17, 0.83, y: inner)
                let x = side * 0.5
                let spread = edge * (0.3 + 0.15 * breathe)
                line([CGPoint(x: x - spread, y: outer), CGPoint(x: x + spread, y: inner)])
                line([CGPoint(x: x + spread, y: outer), CGPoint(x: x - spread, y: inner)])
            case .receipt:
                for index in 0..<7 {
                    let y = side * (0.15 + CGFloat(index) * 0.105)
                    let length = edge * (index == 5 ? 0.8 : 0.35 + 0.25 * breathe)
                    line([CGPoint(x: side - outer, y: y), CGPoint(x: side - outer - length, y: y)])
                }
                line([CGPoint(x: side - inner, y: side * 0.79), CGPoint(x: side - outer, y: side * 0.83)])
            case .fourWeights:
                for index in 0..<4 {
                    let inset = outer + CGFloat(index) * (inner - outer) / 4
                    box(bounds.insetBy(dx: inset, dy: inset), color: ink.opacity(0.4 + breathe * 0.35),
                        weight: width * (index == 0 ? 1.7 : 0.75))
                }
            case .sleepingBookmark:
                for index in 0..<5 {
                    let x = side * (0.16 + CGFloat(index) * 0.15)
                    let depth = index == 2 ? edge * (0.24 + breathe * 0.25) : edge * 0.35
                    let tint = ink.opacity(index == 2 ? 0.22 : 0.85)
                    line([CGPoint(x: x, y: outer), CGPoint(x: x, y: outer + depth),
                          CGPoint(x: x + edge * 0.15, y: outer + depth * 0.65),
                          CGPoint(x: x + edge * 0.3, y: outer + depth),
                          CGPoint(x: x + edge * 0.3, y: outer)], color: tint)
                }
            case .sealedBuffs:
                for index in 0..<3 {
                    let x = side * (0.18 + CGFloat(index) * 0.25)
                    let rect = CGRect(x: x, y: outer, width: side * 0.13, height: inner - outer)
                    box(rect)
                    line([CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.minY)],
                         color: ink.opacity(0.55 + breathe * 0.3))
                }
            case .halfCut:
                let gap = edge * (0.2 + breathe * 0.4)
                topLine(0.1, 0.5 - gap / side, y: outer)
                topLine(0.5 + gap / side, 0.9, y: inner)
                line([CGPoint(x: side * 0.5 - edge * 0.25, y: outer),
                      CGPoint(x: side * 0.5 + edge * 0.25, y: inner)])
            case .shred:
                for index in 0..<3 {
                    let x = side * (0.25 + CGFloat(index) * 0.25)
                    let d = edge * (0.45 + 0.2 * sin(step + CGFloat(index)))
                    line([CGPoint(x: x - edge * 0.2, y: outer), CGPoint(x: x, y: outer + d),
                          CGPoint(x: x + edge * 0.2, y: outer)], weight: width * 1.5)
                }
            case .debit:
                for index in 0..<4 {
                    let x = side * (0.18 + CGFloat(index) * 0.2)
                    let diameter = max(width * 2, edge * 0.6)
                    let rect = CGRect(x: x, y: outer, width: diameter, height: diameter)
                    context.stroke(Path(ellipseIn: rect), with: .color(ink.opacity(0.6 + breathe * 0.4)), lineWidth: width)
                    line([CGPoint(x: rect.minX + diameter * 0.25, y: rect.midY),
                          CGPoint(x: rect.maxX - diameter * 0.25, y: rect.midY)])
                }
            case .clock:
                let center = CGPoint(x: side * 0.5, y: outer + (inner - outer) * 0.5)
                let radius = max(width * 2, (inner - outer) * 0.45)
                context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                     width: radius * 2, height: radius * 2)),
                               with: .color(ink), lineWidth: width)
                line([center, CGPoint(x: center.x + radius * 0.7 * sin(step),
                                      y: center.y - radius * 0.7 * cos(step))])
                topLine(0.15, 0.43, y: outer)
                topLine(0.57, 0.85, y: outer)
            case .barredPair:
                for index in 0..<5 {
                    let x = side * (0.17 + CGFloat(index) * 0.15)
                    topLine(x / side, x / side + 0.08, y: outer)
                    if index == 1 || index == 3 {
                        line([CGPoint(x: x, y: inner), CGPoint(x: x + side * 0.08, y: outer)],
                             color: ink.opacity(0.55 + breathe * 0.4), weight: width * 1.4)
                    }
                }
            case .rowBrackets:
                // Margin furniture only: the real moving row is outlined by
                // BossBoardFeedback, not inferred from an animation phase.
                let y = side * 0.45
                for x in [outer, side - outer] {
                    let direction: CGFloat = x < side / 2 ? 1 : -1
                    let tip = direction * edge * (0.25 + 0.2 * breathe)
                    line([CGPoint(x: x + tip, y: y), CGPoint(x: x, y: y),
                          CGPoint(x: x, y: y + side / 9), CGPoint(x: x + tip, y: y + side / 9)])
                }
            case .boxBrackets:
                for x in [outer, side - outer] {
                    let direction: CGFloat = x < side / 2 ? 1 : -1
                    let tip = direction * edge * (0.3 + 0.2 * breathe)
                    for y in [side * 0.2, side * 0.8] {
                        line([CGPoint(x: x + tip, y: y), CGPoint(x: x, y: y),
                              CGPoint(x: x, y: y + (y < side / 2 ? 1 : -1) * span * 0.12)])
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
