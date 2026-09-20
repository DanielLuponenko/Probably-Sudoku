import SwiftUI
import UIKit
import ProbablySudokuEngine

struct PuzzlePageView: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.levelPalette) private var palette
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var model: GameModel
    var puzzle: PuzzleState
    var isClockRunning = true
    @State private var numberReturnFrames: [String: CGRect] = [:]
    @State private var liveNumberReturnFrames: [String: CGRect] = [:]

    var body: some View {
        GeometryReader { proxy in
            // Compactness belongs to the available page, never the current
            // level, Boss, score or Hand. Short phones keep room for the grid.
            pageContent(layout: GameplayPuzzleLayout(available: proxy.size,
                                                   accessibilityText: dynamicTypeSize.isAccessibilitySize))
        }
        .coordinateSpace(name: NumberReturnMotionAnchor.space)
        .onPreferenceChange(NumberReturnMotionFrames.self) { latest in
            liveNumberReturnFrames = latest
            // A consumed card leaves the Hand before its return flight finishes.
            numberReturnFrames = model.numberReturns.isEmpty ? latest
                : numberReturnFrames.merging(latest, uniquingKeysWith: { _, new in new })
        }
        .onChange(of: model.numberReturns) { _, events in
            if events.isEmpty { numberReturnFrames = liveNumberReturnFrames }
        }
        .overlay {
            NumberReturnMotionOverlay(events: model.numberReturns, frames: numberReturnFrames)
        }
        .onChange(of: shouldRunClock, initial: true) { _, running in
            model.setClockRunning(running)
        }
        .onDisappear {
            model.setClockRunning(false)
            model.finishScorePresentation()
            model.cancelClueTargeting()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                model.finishScorePresentation()
                model.cancelClueTargeting()
            }
        }
        .onChange(of: isClockRunning) { _, available in
            if !available { model.finishScorePresentation() }
        }
        .task(id: ScorePlaybackID(performanceID: model.scorePerformance?.id,
                                  isVisible: isClockRunning && scenePhase == .active,
                                  reduceMotion: reduceMotion)) {
            guard let performance = model.scorePerformance else { return }
            // A Buff may be committed during its slip's closing animation.
            // Start its feedback once the board is visible; opening a cover
            // during existing playback still cancels via onChange above.
            guard isClockRunning, scenePhase == .active else { return }
            let beats = performance.feedbackBeats
            guard !beats.isEmpty else {
                model.finishScorePresentation(id: performance.id)
                return
            }
            // Reduce Motion retains each readable receipt with steady source
            // outlines. A new action replaces playback without delaying input.
            let interval = max(0.40, min(0.70, 4.2 / Double(beats.count)))
            for (index, beat) in beats.enumerated() {
                guard !Task.isCancelled, model.scorePerformance?.id == performance.id else { return }
                model.advanceScore(beat, performanceID: performance.id)
                if !reduceMotion {
                    if beat.kind == .bank {
                        GameAudio.shared.play(.scoreBank)
                        Haptics.scoreStamp(bank: true)
                    } else if beat.kind == .multiplier {
                        GameAudio.shared.play(.scoreMultiply)
                    } else if beat.sourceID != nil {
                        GameAudio.shared.play(index <= 1 ? .scoreTick : .scoreTickHigh)
                        Haptics.scoreStamp(bank: false)
                    }
                }
                try? await Task.sleep(for: .seconds(beat.kind == .bank ? 0.5 : interval))
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

    private func pageContent(layout: GameplayPuzzleLayout) -> some View {
        VStack(spacing: layout.spacing) {
            GameplayScorePanel(model: model, puzzle: puzzle, compact: layout.compact)
                .frame(height: layout.scoreHeight)
                .dismissesPuzzleSelection(when: hasSelection) { model.dismissSelection() }

            GridView(model: model, board: puzzle.board)
                .frame(width: layout.boardSide, height: layout.boardSide)
                .frame(maxWidth: .infinity)

            HandStripView(model: model, handSize: puzzle.handSize, tileHeight: layout.tileHeight)
                .frame(height: layout.handHeight)
            actionRow(compact: layout.compact)
                .frame(height: layout.actionHeight)
                .inventorySaleActionArea()
            PuzzleTurnLine(turn: puzzle.turnNumber, total: puzzle.turnsMax,
                           isDeadline: puzzle.boss == .deadline)
                .modifier(BossObjectArrival(eventKey: puzzle.boss == .deadline
                    ? model.bossEntranceID.map { "deadline:\($0)" } : nil,
                    consume: model.consumeBossVisualEvent))
                .overlay(alignment: .trailing) {
                    if puzzle.boss == .pageCutter {
                        PageCutterMarks(fills: puzzle.bossState.correctFills, turn: puzzle.turnNumber)
                            .padding(.trailing, 8)
                    }
                }
                .frame(height: layout.turnHeight)
                .dismissesPuzzleSelection(when: hasSelection) { model.dismissSelection() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .disabled(!model.acceptsPuzzleInput)
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

    // MARK: Actions

    private func actionRow(compact: Bool) -> some View {
        HStack(spacing: 8) {
            PuzzleActionButton(title: model.tossButtonTitle,
                               subtitle: "\(puzzle.tossesRemaining) left",
                               kind: .quiet,
                               compact: compact,
                               isEnabled: model.canToss) {
                model.tossSelected()
            }
            .overlay(alignment: .topLeading) {
                if puzzle.boss == .erratum {
                    BossCrossedTossTab()
                        .padding(.leading, 8).offset(y: -4)
                        .modifier(BossObjectArrival(eventKey: model.bossEntranceID.map { "erratum:\($0)" },
                                                    consume: model.consumeBossVisualEvent))
                }
            }

            PuzzleActionButton(title: puzzle.boss == .lastEdition && puzzle.phase == .playing ? "Print edition" : "End Turn",
                               subtitle: puzzle.boss == .lastEdition && puzzle.phase == .playing ? "Your only bank"
                                   : puzzle.boss == .orphanLine && puzzle.phase == .playing
                                       ? "−\(BossScoring.orphanDebit(puzzle)) pts for leftovers" : nil,
                               kind: .primary, compact: compact) { model.endTurn() }
                .overlay(alignment: .topTrailing) {
                    if puzzle.boss == .lateCourier {
                        CourierTickets(count: puzzle.bossState.deferredDraws.reduce(0) { $0 + $1.count })
                            .padding(.trailing, 5).offset(y: -7)
                    }
                }
        }
    }
}

private struct ScorePlaybackID: Equatable {
    var performanceID: UUID?
    var isVisible: Bool
    var reduceMotion: Bool
}

/// Book rules, Puzzle Corner and historical saves can own Clue charges
/// independently of the two consumable slots. Their one resource control
/// shares the same explicit hand-targeting flow as an inventory Peek.
struct ClueResourceButton: View {
    @Bindable var model: GameModel

    private var count: Int { model.puzzle?.cluesRemaining ?? 0 }
    private var isLocked: Bool { model.puzzle?.boss?.disablesClues == true }

    var body: some View {
        if count > 0 || model.isChoosingClue {
            Button {
                model.chooseClue()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: model.isChoosingClue ? "xmark" : "lightbulb")
                    if !model.isChoosingClue { Text("\(count)").monospacedDigit() }
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(model.isChoosingClue ? GameplaySurface.ivory : GameplaySurface.ink)
                .padding(.horizontal, 10)
                .frame(minWidth: 44, minHeight: 44)
                .background(model.isChoosingClue ? GameplaySurface.sage : GameplaySurface.ivory,
                            in: RoundedRectangle(cornerRadius: 9))
                .overlay {
                    RoundedRectangle(cornerRadius: 9)
                        .strokeBorder(GameplaySurface.sage.opacity(0.5), lineWidth: 1)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isLocked {
                    BossActionSeal().offset(x: 4, y: -3)
                        .modifier(BossObjectArrival(eventKey: model.bossEntranceID.map { "paywall:\($0)" },
                                                    consume: model.consumeBossVisualEvent))
                }
            }
            .buttonStyle(.plain)
            .disabled(!model.acceptsPuzzleInput)
            .accessibilityLabel(model.isChoosingClue ? "Cancel Clue selection" : "Clues")
            .accessibilityValue(model.isChoosingClue ? "Choose a hand card" : isLocked ? "\(count) owned. Clues locked." : "\(count) available")
            .accessibilityHint(isLocked ? "The Paywall prevents using Clues"
                : model.isChoosingClue ? "Keeps your Clue or Peek"
                : "Select a number from your hand to reveal a legal square")
            .accessibilityIdentifier("clue-resource")
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
    var beat: ScorePerformance.Beat? = nil
    var performanceSummary: String? = nil

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
                    if let beat {
                        // Attribute the staged score where its total lives,
                        // using the already-reserved queue line. The margin
                        // below the board remains handwriting, not a banner.
                        ScoreReceiptView(beat: beat, summary: performanceSummary ?? "\(beat.source), \(beat.value)")
                    } else {
                        if queuedBase > 0 {
                            Text("+\(queuedBase.formatted()) × \(ScorePerformance.number(queuedMultiplier)) queued")
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
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(height: compact ? 14 : 16)
                // Each printed attribution replaces the previous one. Inherit
                // neither the queue's spring nor its cross-fading text layers:
                // rapid beats otherwise print two sources over the same line.
                // The score digits and progress ruler keep their animations.
                .transaction { $0.animation = nil }
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

struct PuzzleActionButton: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.bookPresentation) private var bookTheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var titleSize: CGFloat = 17
    @ScaledMetric(relativeTo: .body) private var subtitleSize: CGFloat = 11.5
    enum Kind { case primary, quiet }
    var title: String
    var subtitle: String? = nil
    var kind: Kind
    var compact = false
    var isEnabled: Bool = true
    var badgeSubtitle = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title).font(Print.subheading(min(titleSize * (compact ? 15.0 / 17.0 : 1), 22)))
                if let subtitle {
                    Text(subtitle).font(Print.body(min(subtitleSize, 18)))
                        .foregroundStyle(badgeSubtitle ? GameplaySurface.ivory
                                         : (kind == .primary ? GameplaySurface.ivory : GameplaySurface.ink))
                        .padding(.horizontal, badgeSubtitle ? 12 : 0)
                        .background {
                            if badgeSubtitle { Capsule().fill(GameplaySurface.sage) }
                        }
                }
            }
            // Action copy cannot renegotiate the grid's reserved height.
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(kind == .primary ? GameplaySurface.ivory : GameplaySurface.ink)
            .frame(maxWidth: .infinity)
            .frame(height: dynamicTypeSize.isAccessibilitySize ? 64 : (compact ? 44 : 50))
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(kind == .primary ? GameplaySurface.sage : GameplaySurface.ivory)
                    .shadow(color: .black.opacity(kind == .primary ? 0.27 : 0.15), radius: 2, x: 0, y: 2)
            }
            .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(GameplaySurface.frame.opacity(0.45), lineWidth: 1) }
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
    var isDeadline = false
    var body: some View {
        HStack(spacing: 8) {
            if isDeadline { BossTurnCut() }
            else { Rectangle().fill(GameplaySurface.softInk.opacity(0.4)).frame(width: 18, height: 1) }
            Text("Turn \(min(turn, total))/\(total)").font(Print.body(13)).foregroundStyle(GameplaySurface.softInk)
            if isDeadline { BossTurnCut() }
            else { Rectangle().fill(GameplaySurface.softInk.opacity(0.4)).frame(width: 18, height: 1) }
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

/// A compact two-line caption and its ink seal. The same height is reserved
/// on every Puzzle, so identifying a Boss never shrinks the playable grid.
struct BossStamp: View {
    @Environment(\.levelPalette) private var palette
    var boss: BossModifier
    var censored: Digit?

    private var fullRule: String {
        censored.map { "\(boss.text) (\($0.rawValue))" } ?? boss.text
    }

    var body: some View {
        HStack(alignment: .center, spacing: 7) {
            BossSignatureBadge(boss: boss)
            // Let the full name and engine-authored rule share both lines.
            // Reserving an entire line for the name forced rule truncation
            // or shorthand that omitted important exceptions.
            Text("\(Text(boss.name.uppercased()).font(Print.caption(11.5)).foregroundStyle(palette.ink)) · \(Text(fullRule))")
                .font(Print.body(11.5))
                .foregroundStyle(palette.ink.opacity(0.78))
                .lineLimit(2, reservesSpace: true)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(boss.name). \(fullRule)")
    }
}

// MARK: - Buttons

struct PaperButton: View {
    @Environment(\.levelPalette) private var palette
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.bookPresentation) private var bookTheme
    @ScaledMetric(relativeTo: .headline) private var labelSize: CGFloat = 16
    @ScaledMetric(relativeTo: .caption) private var detailSize: CGFloat = 10
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
                    .font(Print.subheading(labelSize))
                    .textCase(.uppercase)
                    .tracking(0.8)
                if let subtitle {
                    Text(subtitle)
                        .font(Print.caption(detailSize))
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(minHeight: 52)
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
        case .primary: return bookTheme.buttonForeground
        case .quiet: return bookTheme.quietInk(onDarkPaper: theme.paper.isDark)
        case .danger: return palette.danger
        }
    }
    private var background: Color {
        switch kind {
        case .primary: return bookTheme.buttonFill
        case .quiet: return theme.paper.warm.opacity(0.9)
        case .danger: return theme.paper.warm.opacity(0.9)
        }
    }
    private var border: Color {
        kind == .danger ? palette.danger.opacity(0.6) : bookTheme.accent.opacity(0.7)
    }
}

/// A button on paper does not glow; it presses in.
struct PressedPaperStyle: ButtonStyle {
    @Environment(\.gameReduceMotion) private var reduceMotion

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
