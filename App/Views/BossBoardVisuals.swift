import SwiftUI
import ProbablySudokuEngine

/// Boss identity belongs in the existing header and route artwork. The playable
/// board carries only actual restrictions, never decorative lines or doodles.
struct BossBoardDesign {
    let boss: BossModifier

    var symbol: String {
        switch boss {
        case .censor: return "rectangle.and.text.magnifyingglass"
        case .editor: return "pencil.line"
        case .deadline: return "clock"
        case .fog: return "cloud.fog"
        case .critic: return "pencil.tip.crop.circle"
        case .mirror: return "rectangle.on.rectangle"
        case .paywall: return "lock.rectangle"
        case .erratum: return "text.badge.xmark"
        case .collector: return "tray.full"
        case .heavyLifter: return "dumbbell"
        case .unluckyLucky: return "bookmark.slash"
        case .buffborger: return "bandage"
        case .sashimi: return "scissors"
        case .overPusher: return "drop.fill"
        case .accountant: return "list.bullet.rectangle"
        case .tikTak: return "timer"
        case .handyDandy: return "hand.raised.slash"
        case .grayTheGarry: return "rectangle.split.3x1"
        case .garryTheGray: return "square.grid.3x3"
        case .galleyQueue: return "text.line.first.and.arrowtriangle.forward"
        case .bookends: return "books.vertical"
        case .reprintBan: return "repeat.1"
        case .rebinder: return "book.closed"
        case .lateCourier: return "envelope.badge"
        case .collator: return "rectangle.split.2x1"
        case .pageCutter: return "scissors.circle"
        case .chainStitcher: return "link"
        case .returnSlip: return "arrow.uturn.backward.square"
        case .orphanLine: return "text.alignleft"
        case .serialPublisher: return "newspaper"
        case .bindery: return "arrow.left.arrow.right"
        case .embargo: return "seal"
        case .dryPress: return "drop.halffull"
        case .reviewBoard: return "checklist"
        case .rivalColumn: return "chart.bar.xaxis"
        case .royaltyContract: return "signature"
        case .publicist: return "megaphone"
        case .wordCount: return "ruler"
        case .backPage: return "arrow.triangle.2.circlepath"
        case .collateral: return "envelope.fill"
        case .splitEdition: return "rectangle.split.2x1.fill"
        case .lastEdition: return "printer.fill"
        }
    }

    var ink: Color {
        switch boss {
        case .critic, .censor, .erratum, .handyDandy: return Paper.redPencil
        case .fog, .grayTheGarry, .garryTheGray: return Paper.inkFaint
        case .paywall, .collector, .accountant: return Paper.inkSoft
        default: return Paper.sageDeep
        }
    }

    var angle: Double {
        switch boss {
        case .critic, .erratum: return -2.2
        case .collector, .accountant: return 1.4
        default: return -1.0
        }
    }

    /// Header shorthand keeps both name and rule readable beside the seal.
    /// The full engine-authored rule remains the accessibility description.
    func headerRule(censored: Digit?, turns: Int? = nil) -> String {
        switch boss {
        case .censor: return censored.map { "Digit \($0.rawValue) scores 0" } ?? "One digit scores 0"
        case .editor: return "Hand size −1"
        case .deadline: return "\(turns ?? 8) turns"
        case .fog: return "Markers hidden"
        case .critic: return "Wrong-placement penalty ×2"
        case .mirror: return "No line-clear bonus"
        case .paywall: return "Clues disabled"
        case .erratum: return "No tosses"
        case .collector: return "No interest payout"
        case .heavyLifter: return "Target ×4"
        case .unluckyLucky: return "One triggered Bookmark sleeps"
        case .buffborger: return "Buffs disabled"
        case .sashimi: return "Multipliers halved"
        case .overPusher: return "Each Turn fouls up to 3 squares for 2 Turns"
        case .accountant: return "Each placement costs 1 coin"
        case .tikTak: return "\(Int((boss.secondsAllowed ?? 240) / 60))-minute limit"
        case .handyDandy: return "Up to 2 Hand cards barred each turn"
        case .grayTheGarry: return "One row locked each turn"
        case .garryTheGray: return "One box locked each turn"
        default: return boss.text
        }
    }
}

/// A render-only projection of public rules. No random choices, Marker
/// locations or hidden solution digits enter the overlay.
struct BossBoardFeedback: Equatable {
    let boss: BossModifier?
    let turnNumber: Int
    let censoredSquares: Set<Square>
    let fouled: Set<Square>
    let greyed: Set<Square>
    let clockIsUrgent: Bool

    init(puzzle: PuzzleState?, secondsLeft: Double? = nil) {
        boss = puzzle?.boss
        turnNumber = puzzle?.turnNumber ?? 0
        if let puzzle, puzzle.boss?.censorsARandomDigit == true,
           let digit = puzzle.censoredDigit {
            censoredSquares = Set(Square.all.filter { puzzle.board[$0] == digit })
        } else {
            censoredSquares = []
        }
        fouled = boss?.foulsSquaresEachTurn == true
            ? Set(puzzle?.bossTurn?.fouled.keys.map { $0 } ?? []) : []
        greyed = boss?.greysARowEachTurn == true || boss?.greysABoxEachTurn == true
            ? puzzle?.bossTurn?.greyed ?? [] : []
        clockIsUrgent = boss == .tikTak && secondsLeft.map { $0 <= 30 } == true
    }

    var showsFog: Bool { boss?.hidesMarkedSquares == true }
}

/// Only engine-authored restrictions appear over the cells. Fog is enforced by
/// concealing marker content in the cell projection, without washing out the
/// board. Boss seals and ambient artwork stay outside the playable grid.
struct BossBoardOverlay: View {
    @Environment(\.gameReduceMotion) private var gameReduceMotion
    private let feedback: BossBoardFeedback
    private let reduceMotionOverride: Bool?
    private let isActive: Bool
    private let phaseOverride: Double?
    private let includesBricks: Bool
    private let inkEvent: BossInkLandingEvent?
    private let consumeInkEvent: ((UUID) -> Bool)?
    private var reduceMotion: Bool { reduceMotionOverride ?? gameReduceMotion }

    init(puzzle: PuzzleState?, secondsLeft: Double? = nil, reduceMotionOverride: Bool? = nil,
         isActive: Bool = true, phaseOverride: Double? = nil, includesBricks: Bool = true,
         inkEvent: BossInkLandingEvent? = nil, consumeInkEvent: ((UUID) -> Bool)? = nil) {
        feedback = BossBoardFeedback(puzzle: puzzle, secondsLeft: secondsLeft)
        self.reduceMotionOverride = reduceMotionOverride
        self.isActive = isActive
        self.phaseOverride = phaseOverride
        self.includesBricks = includesBricks
        self.inkEvent = inkEvent
        self.consumeInkEvent = consumeInkEvent
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            BossInkLandingOverlay(squares: feedback.fouled, reduceMotion: reduceMotion,
                                  event: inkEvent, consumeEvent: consumeInkEvent,
                                  elapsedOverride: phaseOverride == nil ? nil : 1)
            .frame(width: side, height: side)
            .clipped()
            .overlay {
                if includesBricks {
                    BossBrickLandingOverlay(feedback: feedback, reduceMotion: reduceMotion,
                                            isActive: isActive, elapsedOverride: phaseOverride.map { _ in 2 })
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The event includes the turn: a repeated row/box still gets a fresh landing.
struct BossBrickLandingEvent: Equatable {
    let boss: BossModifier?
    let turn: Int
    let squares: Set<Square>
}

private struct BossBrickLandingRequest: Equatable {
    let event: BossBrickLandingEvent
    let canAnimate: Bool
    let deferUntilVisible: Bool
}

/// A hidden or reduced-motion event is still handled. Otherwise toggling
/// Reduce Motion off, uncovering an overlay, or resuming the app could replay
/// a turn the player has already seen settled.
struct BossBrickLandingLifecycle {
    private(set) var event: BossBrickLandingEvent?
    private(set) var isPending = false
    private(set) var isSettled = true

    mutating func prepare(_ next: BossBrickLandingEvent, canAnimate: Bool,
                          deferUntilVisible: Bool = false) -> Bool {
        guard next != event else {
            if deferUntilVisible {
                // Only an unseen entrance may wait. An outgoing or already
                // animated page settles rather than replaying after a curl.
                if !isPending { settle() }
                return false
            }
            if !canAnimate { settle() }
            return canAnimate && isPending && !isSettled
        }
        event = next
        isPending = (canAnimate || deferUntilVisible) && !next.squares.isEmpty
        isSettled = !isPending
        return isPending && !deferUntilVisible
    }

    mutating func start(_ requested: BossBrickLandingEvent) -> Bool {
        guard event == requested, isPending, !isSettled else { return false }
        isPending = false
        return true
    }

    private mutating func settle() {
        isPending = false
        isSettled = true
    }
}

/// One finite animation drives the brick layer, without ticking the board or engine.
struct BossBrickLandingOverlay: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.bossMotionIsActive) private var presentationIsActive
    @Environment(\.bossEntranceIsDeferred) private var entranceIsDeferred
    @State private var trigger = false
    @State private var lifecycle = BossBrickLandingLifecycle()
    let feedback: BossBoardFeedback
    let reduceMotion: Bool
    var isActive = true
    var elapsedOverride: Double? = nil
    var permitsInitialEntrance = true
    var hasConsumedEvent: ((BossBrickLandingEvent) -> Bool)? = nil
    var consumeEvent: ((BossBrickLandingEvent) -> Bool)? = nil
    @State private var exiting: Set<Square> = []
    @State private var exitProgress: Double = 1

    private var event: BossBrickLandingEvent {
        BossBrickLandingEvent(boss: feedback.boss, turn: feedback.turnNumber, squares: feedback.greyed)
    }
    private var canAnimate: Bool {
        !reduceMotion && isActive && presentationIsActive && scenePhase == .active && elapsedOverride == nil
    }
    private var deferUntilVisible: Bool {
        !reduceMotion && isActive && elapsedOverride == nil && scenePhase != .background
            && (entranceIsDeferred || (presentationIsActive && scenePhase == .inactive
                                      && (lifecycle.event == nil || lifecycle.isPending)))
    }

    private func sampledElapsed(_ elapsed: Double, rank: Int) -> Double {
        if let elapsedOverride { return elapsedOverride }
        if lifecycle.event == nil && (!permitsInitialEntrance || hasConsumedEvent?(event) == true) { return 2 }
        if deferUntilVisible && (lifecycle.event != event || lifecycle.isPending) { return -1 }
        guard canAnimate else { return 2 }
        // Pending placements stay above the visible page until their drop begins.
        guard lifecycle.event == event else { return -1 }
        guard !lifecycle.isSettled else { return 2 }
        guard !lifecycle.isPending else { return -1 }
        return BossBrickSequence.localElapsed(elapsed, rank: rank)
    }

    var body: some View {
        GeometryReader { proxy in
            let cell = min(proxy.size.width, proxy.size.height) / 9
            let squares = feedback.greyed.sorted { $0.index < $1.index }
            let duration = BossBrickSequence.duration(count: squares.count)
            KeyframeAnimator(initialValue: duration, trigger: trigger) { elapsed in
                ZStack(alignment: .topLeading) {
                    ForEach(exiting.sorted(), id: \.index) { square in
                        BossBrickDrawing(size: cell, motion: BossBrickMotion(elapsed: 2))
                            .offset(y: -cell * 0.32 * exitProgress)
                            .opacity(1 - exitProgress)
                            .position(x: (CGFloat(square.col) + 0.5) * cell,
                                      y: (CGFloat(square.row) + 0.5) * cell)
                    }
                    ForEach(Array(squares.enumerated()), id: \.element.index) { rank, square in
                        BossBrickDrawing(size: cell, motion: BossBrickMotion(
                            elapsed: sampledElapsed(elapsed, rank: rank)))
                            .position(x: (CGFloat(square.col) + 0.5) * cell,
                                      y: (CGFloat(square.row) + 0.5) * cell)
                    }
                }
                .frame(width: cell * 9, height: cell * 9)
                // A falling brick may pass over the row above its destination,
                // but can never leave the board or obscure the HUD/hand.
                .clipped()
            } keyframes: { _ in
                MoveKeyframe(0)
                LinearKeyframe(duration, duration: duration)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onDisappear { _ = consumeEvent?(event) }
        .task(id: BossBrickLandingRequest(event: event, canAnimate: canAnimate,
                                         deferUntilVisible: deferUntilVisible)) {
            let requested = event
            let previous = lifecycle.event
            if (previous == nil && !permitsInitialEntrance) || hasConsumedEvent?(requested) == true {
                _ = lifecycle.prepare(requested, canAnimate: false)
                exiting = []
                return
            }
            guard lifecycle.prepare(requested, canAnimate: canAnimate,
                                    deferUntilVisible: deferUntilVisible) else {
                if !deferUntilVisible {
                    _ = consumeEvent?(requested)
                    exiting = []
                }
                return
            }
            // Retiring blocks lift first, even if the Boss selected that exact
            // row again. New blocks wait off-page until those old ones clear.
            exiting = previous?.squares ?? []
            exitProgress = 0
            withAnimation(.easeIn(duration: 0.18)) { exitProgress = 1 }
            do { try await Task.sleep(for: .milliseconds(exiting.isEmpty ? 80 : 190)) } catch { return }
            guard !Task.isCancelled, lifecycle.start(requested) else { return }
            guard consumeEvent?(requested) ?? true else {
                _ = lifecycle.prepare(requested, canAnimate: false)
                return
            }
            exiting = []
            trigger.toggle()
        }
    }
}

/// Stable row-major cadence. Visual timing never consumes a game RNG stream.
enum BossBrickSequence {
    static let interval = 0.11
    static func localElapsed(_ elapsed: Double, rank: Int) -> Double {
        elapsed - Double(rank) * interval
    }
    static func duration(count: Int) -> Double {
        Double(max(0, count - 1)) * interval + BossBrickMotion.settledTime
    }
}

/// Ballistic fall, one small rebound and a rigid settle; units are cell widths.
/// Pure sampling also lets visual tests inspect the actual airborne/impact poses.
struct BossBrickMotion {
    let elapsed: Double
    static let impactTime = 0.34
    static let dustLifetime = 0.34
    static let settledTime = impactTime + dustLifetime
    var height: Double {
        if elapsed < 0 { return 2.2 }
        if elapsed < Self.impactTime {
            let t = elapsed / Self.impactTime
            return 2.2 * (1 - t * t)
        }
        let t = (elapsed - Self.impactTime) / 0.14
        return t >= 0 && t < 1 ? 0.10 * sin(t * .pi) : 0
    }
    var opacity: Double { min(1, max(0, elapsed / 0.07)) }
    var dust: Double {
        let t = (elapsed - Self.impactTime) / Self.dustLifetime
        return t >= 0 && t < 1 ? pow(1 - t, 1.7) : 0
    }
    var dustSpread: Double { max(0, min(1, (elapsed - Self.impactTime) / Self.dustLifetime)) }
}

/// Straight falling motion over a fixed footprint. Only the airborne sprite
/// leaves its target cell; settled clay, contact shadow and dust stay inside it.
struct BossBrickDrawing: View {
    let size: CGFloat
    let motion: BossBrickMotion

    private var lift: Double { motion.height / 2.2 }

    var body: some View {
        ZStack {
            // The paper footprint is fixed. An elevated block casts a softer,
            // broader shadow; contact brings it back to a tight grounded edge.
            RoundedRectangle(cornerRadius: size * 0.025)
                .fill(.black.opacity(0.30 - lift * 0.20))
                .frame(width: size * (0.76 + lift * 0.10),
                       height: size * (0.75 + lift * 0.08))
                .blur(radius: size * (0.018 + lift * 0.05))
                .offset(y: size * 0.028)
                .frame(width: size, height: size)
                .clipped()

            // Dust originates under the block; the clay face occludes it.
            // Drawing this above the sprite looks like spots painted on top.
            BossBrickDust(size: size, opacity: motion.dust, progress: motion.dustSpread)

            Image(decorative: "BossBrick")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                // Preserve the authored square sprite and its relief, while
                // firing the orange prototype into the reference's red clay.
                .colorMultiply(Color(red: 1, green: 0.78, blue: 0.88))
                .saturation(1.12)
                .shadow(color: .black.opacity(0.32 * max(0, 1 - motion.height * 5)),
                        radius: size * 0.014, y: size * 0.023)
                // Accelerate straight down into the well, then make one small
                // rigid rebound. Never rotate across a neighboring column.
                .scaleEffect(1 + lift * 0.09)
                .offset(y: -size * lift * 0.82)

        }
        .frame(width: size, height: size)
        .opacity(motion.opacity)
    }
}

/// Small warm mortar clouds with a few heavier grains. They originate at the
/// contact edges, spread a little, and fully disappear within half a second.
/// Positions are authored constants, never random values from a run.
private struct BossBrickDust: View {
    let size: CGFloat
    let opacity: Double
    let progress: Double

    var body: some View {
        Canvas { context, _ in
            guard opacity > 0 else { return }
            for puff in 0..<10 {
                let angle = Double(puff) * .pi / 5 + 0.14
                let spread = 0.42 + progress * 0.035
                let center = CGPoint(x: size * (0.5 + cos(angle) * spread),
                                     y: size * (0.53 + sin(angle) * spread * 0.90))
                let radius = size * (0.028 + progress * 0.044)
                let oval = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 0.65,
                                                 width: radius * 2, height: radius * 1.3))
                context.fill(oval, with: .radialGradient(
                    Gradient(colors: [Color(red: 0.69, green: 0.46, blue: 0.31).opacity(opacity * 0.55),
                                      Color(red: 0.82, green: 0.68, blue: 0.50).opacity(opacity * 0.30),
                                      .clear]),
                    center: center, startRadius: 0, endRadius: radius))
            }
            for grain in 0..<12 {
                let angle = Double(grain) * .pi / 6 + 0.31
                let spread = 0.445 + progress * (grain.isMultiple(of: 2) ? 0.025 : 0.012)
                let x = size * (0.5 + cos(angle) * spread)
                let y = size * (0.55 + sin(angle) * spread * 0.82 - sin(progress * .pi) * 0.025)
                let radius = size * (grain.isMultiple(of: 3) ? 0.012 : 0.007)
                context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                                   width: radius * 2, height: radius * 1.3)),
                             with: .color(Color(red: 0.48, green: 0.25, blue: 0.15).opacity(opacity * 0.70)))
            }
        }
        .frame(width: size, height: size)
        .clipped()
    }
}
