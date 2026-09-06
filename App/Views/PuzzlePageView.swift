import SwiftUI
import ProbablySudokuEngine

struct PuzzlePageView: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.levelPalette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var model: GameModel
    var puzzle: PuzzleState
    var isClockRunning = true
    @State private var numberReturnFrames: [String: CGRect] = [:]

    var body: some View {
        GeometryReader { proxy in
            // Compactness belongs to the available page, never the current
            // level, Boss, score or Hand. Short phones keep room for the grid.
            pageContent(compact: proxy.size.height < 560)
        }
        .coordinateSpace(name: NumberReturnMotionAnchor.space)
        .onPreferenceChange(NumberReturnMotionFrames.self) { numberReturnFrames = $0 }
        .overlay {
            NumberReturnMotionOverlay(events: model.numberReturns, frames: numberReturnFrames)
        }
        .onChange(of: shouldRunClock, initial: true) { _, running in
            model.setClockRunning(running)
        }
        .onDisappear {
            model.setClockRunning(false)
            model.finishScorePresentation()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.finishScorePresentation() }
        }
        .onChange(of: isClockRunning) { _, available in
            if !available { model.finishScorePresentation() }
        }
        .task(id: model.scorePerformance?.id) {
            guard let performance = model.scorePerformance else { return }
            guard scenePhase == .active else {
                model.finishScorePresentation(id: performance.id)
                return
            }
            if reduceMotion {
                if let last = performance.beats.last {
                    model.advanceScore(last, performanceID: performance.id)
                }
                try? await Task.sleep(for: .milliseconds(450))
            } else {
                // Long combinations accelerate instead of blocking play for
                // seconds per item. A new action replaces this task safely.
                let interval = max(0.16, min(0.30, 1.8 / Double(max(1, performance.beats.count))))
                for (index, beat) in performance.beats.enumerated() {
                    guard !Task.isCancelled else { return }
                    model.advanceScore(beat, performanceID: performance.id)
                    if beat.kind == .bank {
                        GameAudio.shared.play(.scoreBank)
                        Haptics.scoreStamp(bank: true)
                    } else if beat.kind == .multiplier {
                        GameAudio.shared.play(.scoreMultiply)
                    } else if beat.sourceID != nil {
                        GameAudio.shared.play(index <= 1 ? .scoreTick : .scoreTickHigh)
                        Haptics.scoreStamp(bank: false)
                    }
                    try? await Task.sleep(for: .seconds(beat.kind == .bank ? 0.5 : interval))
                }
            }
            guard !Task.isCancelled else { return }
            model.finishScorePresentation(id: performance.id)
        }
        .task(id: shouldRunClock) {
            guard shouldRunClock else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                model.tickClock()
            }
        }
    }

    private func pageContent(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            header(compact: compact)
            ScoreMeter(score: model.presentedScore ?? puzzle.score, target: puzzle.target,
                       queuedBase: model.presentedQueue ?? puzzle.pendingBase,
                       queuedMultiplier: puzzle.pendingMultiplier,
                       recentCoins: model.lastOutcome?.coinsEarned,
                       compact: compact)
                .dismissesPuzzleSelection(when: hasSelection) {
                    model.dismissSelection()
                }

            GridView(model: model, board: puzzle.board)
                .layoutPriority(1)

            marginBand(compact: compact)
                .dismissesPuzzleSelection(when: hasSelection) {
                    model.dismissSelection()
                }

            HandStripView(model: model, handSize: puzzle.handSize,
                          tileHeight: compact ? 44 : 50)
            actionRow(compact: compact)
            PuzzleTurnLine(turn: puzzle.turnNumber, total: puzzle.turnsMax)
                .dismissesPuzzleSelection(when: hasSelection) {
                    model.dismissSelection()
                }
        }
    }

    // MARK: Header

    private var shouldRunClock: Bool {
        isClockRunning && scenePhase == .active && model.animatesHandArrival
            && model.page == .puzzle && puzzle.boss?.secondsAllowed != nil
            && (puzzle.phase == .playing || puzzle.phase == .keepFilling)
    }

    private var hasSelection: Bool {
        model.selectedHandIndex != nil || model.selectedSquare != nil || model.isChoosingClue
    }

    private func header(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Puzzle \(puzzle.slot.rawValue + 1)")
                    .pageHeading(compact ? 22 : 25)
                Spacer(minLength: 4)
                Text("Level \(puzzle.level)")
                    .font(Print.body(11))
                    .foregroundStyle(palette.ink.opacity(0.72))
                ProgressDots(index: puzzle.slot.rawValue, count: 3)
                if let secondsLeft = model.secondsLeft {
                    Label(clockText(secondsLeft), systemImage: "timer")
                        .font(Print.caption(12))
                        .foregroundStyle(secondsLeft <= 30 ? palette.danger : palette.ink.opacity(0.72))
                        .accessibilityLabel("Time remaining, \(Int(secondsLeft.rounded(.up))) seconds")
                }
            }

            // A full-width two-line annotation keeps every Boss readable
            // without reserving the old three-line, two-column stamp.
            if let boss = puzzle.boss {
                BossStamp(boss: boss, censored: puzzle.censoredDigit)
            } else {
                BossStampReservation()
            }

            Rectangle().fill(palette.rule).frame(height: 1)
        }
        .dismissesPuzzleSelection(when: hasSelection) {
            model.dismissSelection()
        }
    }

    private func clockText(_ seconds: Double) -> String {
        let whole = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    /// The Book's own handwriting, given room whether or not it speaks, so a
    /// note appearing never shifts the grid.
    private func marginBand(compact: Bool) -> some View {
        ZStack {
            if let beat = model.scoreBeat, let performance = model.scorePerformance {
                ScoreReceiptView(beat: beat, summary: performance.summary)
                    .id(beat.id)
                    .transition(reduceMotion ? .opacity : .scale(scale: 1.04).combined(with: .opacity))
            } else if let note = model.marginNote {
                MarginNoteView(note: note)
                    .id(note.text)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: compact ? 38 : 46)
        .animation(.easeInOut(duration: 0.45), value: model.marginNote)
        .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: model.scoreBeat?.id)
    }

    // MARK: Actions

    private func actionRow(compact: Bool) -> some View {
        HStack(spacing: 12) {
            PuzzleActionButton(title: model.tossButtonTitle,
                               subtitle: model.tossButtonSubtitle,
                               kind: .quiet,
                               compact: compact,
                               isEnabled: model.canToss) {
                model.tossSelected()
            }

            if puzzle.canUseClue {
                PuzzleActionButton(title: model.isChoosingClue ? "Cancel" : "Clue",
                                   subtitle: model.isChoosingClue
                                       ? "pick a number" : "\(puzzle.cluesRemaining) left",
                                   kind: .quiet,
                                   compact: compact,
                                   isEnabled: !model.hand.isEmpty) {
                    model.chooseClue()
                }
            }

            PuzzleActionButton(title: "End Turn", kind: .primary, compact: compact) { model.endTurn() }
        }
    }
}

/// A transparent, explicitly labelled Button placed only behind inert page
/// regions. Existing controls remain above it and keep their own actions.
private struct PuzzleSelectionDismissSurface: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Color.clear.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear board selection")
    }
}

private extension View {
    func dismissesPuzzleSelection(when active: Bool,
                                  action: @escaping () -> Void) -> some View {
        background {
            if active {
                PuzzleSelectionDismissSurface(action: action)
            }
        }
    }
}

/// A compact, fixed-height score receipt. Score carries and pending payouts
/// must never borrow space from the board.
struct ScoreMeter: View {
    @Environment(\.levelPalette) private var palette
    var score: Int
    var target: Int
    /// Correct-play points waiting to be banked at the end of this Turn.
    var queuedBase: Int = 0
    var queuedMultiplier: Double = 1
    /// Coin effects use the engine outcome too, so a Copper payout is visible
    /// beside the placement that triggered it rather than inferred by the UI.
    var recentCoins: Int?
    var compact = false

    private var fraction: Double {
        target > 0 ? min(1, Double(score) / Double(target)) : 0
    }
    private var queued: Int { Int((Double(queuedBase) * queuedMultiplier).rounded(.down)) }
    private var reach: Double {
        target > 0 ? min(1, Double(score + queued) / Double(target)) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 3) {
            // Reserve both lines, including before the first placement. Bonus
            // receipts must neither squeeze the score nor push down the board.
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    RollingNumber(value: score, size: compact ? 24 : 28,
                                  weight: .bold, color: palette.ink)
                        .accessibilityLabel("Score, \(score.formatted())")
                    Text("/ \(target.formatted())")
                        .font(Print.numeral(compact ? 16 : 18, weight: .medium))
                        .foregroundStyle(palette.ink.opacity(0.70))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .accessibilityLabel("Target, \(target.formatted())")
                    Spacer(minLength: 0)
                }
                .frame(height: (compact ? 24 : 28) * 1.18, alignment: .topLeading)

                HStack(spacing: 8) {
                    if queuedBase > 0 {
                        Text("+\(queuedBase.formatted()) × \(queuedMultiplier.formatted(.number.precision(.fractionLength(0...2)))) queued")
                            .font(Print.caption(11))
                            .foregroundStyle(palette.accent)
                            .accessibilityLabel("\(queued) points queued until end turn")
                    }
                    Spacer(minLength: 0)
                    if let recentCoins, recentCoins > 0 {
                        Text("+\(recentCoins.formatted()) coins")
                            .font(Print.caption(12))
                            .foregroundStyle(Paper.coinRim)
                            .accessibilityLabel("Last placement, plus \(recentCoins) coins")
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: compact ? 14 : 16)
            }

            ScoreRuler(fraction: fraction, reach: reach, target: target, score: score,
                        ink: palette.ink, fill: palette.target, rule: palette.rule)
        }
        .animation(.snappy, value: score)
        .animation(.snappy(duration: 0.22), value: queuedBase)
        .animation(.snappy(duration: 0.22), value: queuedMultiplier)
        .animation(.snappy(duration: 0.22), value: recentCoins)
    }
}

private struct ScoreRuler: View {
    var fraction: Double
    var reach: Double
    var target: Int
    var score: Int
    var ink: Color
    var fill: Color
    var rule: Color

    private var percent: Int { Int((fraction * 100).rounded()) }

    var body: some View {
        HStack(spacing: 12) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(rule.opacity(0.42)).frame(height: 13)
                    Capsule()
                        .fill(fill.opacity(0.38))
                        .frame(width: max(4, width * reach), height: 13)
                    Capsule()
                        .fill(ink.opacity(0.88))
                        .frame(width: max(4, width * fraction), height: 13)
                    HStack(spacing: 0) {
                        ForEach(1..<8, id: \.self) { tick in
                            Rectangle().fill(.white.opacity(0.78)).frame(width: 1, height: 7)
                            if tick < 7 { Spacer() }
                        }
                    }
                    .padding(.horizontal, 18)

                    Text("\(percent)%")
                        .font(Print.numeral(13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.96))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(fill.opacity(0.98)))
                        .position(x: min(max(width * fraction, 24), width - 24), y: 6)
                }
            }
            .frame(height: 22)

            Text("\(max(0, target - score).formatted()) TO GO")
                .font(Print.caption(12)).tracking(0.6)
                .foregroundStyle(ink.opacity(0.76))
                .fixedSize()
        }
    }
}

private struct PuzzleActionButton: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.levelPalette) private var palette
    enum Kind { case primary, quiet }
    var title: String
    var subtitle: String? = nil
    var kind: Kind
    var compact = false
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).font(Print.subheading(compact ? 16 : 18)).tracking(1.1).textCase(.uppercase)
                if let subtitle { Text(subtitle).font(Print.body(11.5)).opacity(0.72) }
            }
            // Clue availability changes two columns to three (and back),
            // but wrapping button copy must never renegotiate the grid height.
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(kind == .primary ? Color.white : theme.paper.ink)
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 44 : 52)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(kind == .primary ? palette.target : theme.paper.warm)
                    .shadow(color: .black.opacity(kind == .primary ? 0.27 : 0.15), radius: 2, x: 0, y: 2)
            }
            .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(palette.rule.opacity(0.8), lineWidth: 1) }
        }
        .buttonStyle(PressedPaperStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.42)
    }
}

private struct PuzzleTurnLine: View {
    @Environment(\.levelPalette) private var palette
    var turn: Int
    var total: Int
    var body: some View {
        HStack(spacing: 8) {
            Rectangle().fill(palette.rule.opacity(0.5)).frame(width: 18, height: 1)
            Text("Turn \(min(turn, total))/\(total)").font(Print.body(13)).foregroundStyle(palette.ink.opacity(0.70))
            Rectangle().fill(palette.rule.opacity(0.5)).frame(width: 18, height: 1)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Empty typographic space for an ordinary Puzzle's reserved Boss band.
struct BossStampReservation: View {
    var body: some View {
        // BossStamp's two full-width copy lines determine the band's height.
        // Whitespace uses the same native font metrics and contains no rule.
        Text(" \n ")
            .font(Print.body(11.5))
            .lineLimit(2, reservesSpace: true)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .hidden()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

/// The Boss Modifier, annotated in ink without taking width from its rule.
struct BossStamp: View {
    @Environment(\.levelPalette) private var palette
    var boss: BossModifier
    var censored: Digit?

    private var design: BossBoardDesign { BossBoardDesign(boss: boss) }

    var body: some View {
        let rule = censored.map { "\(boss.text) (\($0.rawValue))" } ?? boss.text
        Text("\(Text(boss.name.uppercased()).font(Print.caption(11.5)).foregroundStyle(design.ink)) · \(rule)")
            .font(Print.body(11.5))
            .foregroundStyle(palette.ink.opacity(0.78))
            .lineLimit(2, reservesSpace: true)
            .minimumScaleFactor(0.85)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("\(boss.name). \(rule)")
    }
}

// MARK: - Buttons

struct PaperButton: View {
    @Environment(\.levelPalette) private var palette
    @Environment(\.cosmeticTheme) private var theme
    enum Kind { case primary, quiet, danger }

    var title: String
    var subtitle: String? = nil
    var kind: Kind = .primary
    var isEnabled: Bool = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text(title)
                    .font(Print.subheading(16))
                    .textCase(.uppercase)
                    .tracking(0.8)
                if let subtitle {
                    Text(subtitle)
                        .font(Print.caption(10))
                        .opacity(0.8)
                }
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                RoundedRectangle(cornerRadius: 5).fill(background)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(border, lineWidth: kind == .primary ? 0 : 1.4)
            }
        }
        .buttonStyle(PressedPaperStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }

    private var foreground: Color {
        switch kind {
        case .primary: return theme.paper.isDark ? theme.paper.ink : palette.paper
        case .quiet: return theme.paper.ink
        case .danger: return palette.danger
        }
    }
    private var background: Color {
        switch kind {
        case .primary: return palette.target
        case .quiet: return theme.paper.warm.opacity(0.9)
        case .danger: return theme.paper.warm.opacity(0.9)
        }
    }
    private var border: Color {
        kind == .danger ? palette.danger.opacity(0.6) : theme.paper.ruleInk
    }
}

/// A button on paper does not glow; it presses in.
struct PressedPaperStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(reduceMotion ? .easeOut(duration: 0.08) : .snappy(duration: 0.12),
                       value: configuration.isPressed)
    }
}

/// Printed at the foot of every page, the way a puzzle book numbers itself.
struct PageNumber: View {
    @Environment(\.levelPalette) private var palette
    @Environment(\.cosmeticTheme) private var theme
    var level: Int
    var slot: Int

    /// Three Puzzles a Level, each taking a spread.
    private var page: Int { ((level - 1) * 3 + slot) * 2 + 7 }

    var body: some View {
        HStack(spacing: 6) {
            Rectangle().fill(theme.paper.ruleInk.opacity(0.45)).frame(width: 14, height: 0.75)
            Text("\(page)")
                .font(Print.body(10.5))
                .foregroundStyle(theme.paper.faintInk.opacity(0.72))
            Rectangle().fill(theme.paper.ruleInk.opacity(0.45)).frame(width: 14, height: 0.75)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityHidden(true)
    }
}
