import SwiftUI
import ProbablySudokuEngine

struct PuzzlePageView: View {
    @Environment(\.levelPalette) private var palette
    @Bindable var model: GameModel
    var puzzle: PuzzleState
    @State private var numberReturnFrames: [String: CGRect] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            ScoreMeter(score: puzzle.score, target: puzzle.target,
                       level: puzzle.level, slot: puzzle.slot.rawValue,
                       queuedBase: puzzle.pendingBase,
                       queuedMultiplier: puzzle.pendingMultiplier,
                       recentCoins: model.lastOutcome?.coinsEarned)

            Spacer(minLength: 0)
            GridView(model: model, board: puzzle.board)
                .layoutPriority(1)
            if showsInstruction { instruction }

            // The band under the grid is the only part of the page with
            // nothing printed on it and nothing to tap, which is why the Book
            // writes here.
            marginBand

            HandStripView(model: model, handSize: puzzle.handSize)
            actionRow
            PageNumber(level: puzzle.level, slot: puzzle.slot.rawValue)
        }
        .coordinateSpace(name: NumberReturnMotionAnchor.space)
        .onPreferenceChange(NumberReturnMotionFrames.self) { numberReturnFrames = $0 }
        .overlay {
            NumberReturnMotionOverlay(events: model.numberReturns, frames: numberReturnFrames)
        }
        .task(id: puzzle.boss?.secondsAllowed) {
            guard model.secondsLeft != nil else { return }
            while !Task.isCancelled, model.secondsLeft != nil, model.page == .puzzle {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                model.tickClock(by: 1)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Puzzle \(puzzle.slot.rawValue + 1)")
                    .pageHeading(27)
                if puzzle.boss == nil {
                    Text(puzzle.difficulty.rawValue)
                        .font(Print.caption(10))
                        .tracking(1.4)
                        .textCase(.uppercase)
                        .foregroundStyle(palette.ink.opacity(0.52))
                }
                Spacer(minLength: 4)
                if let secondsLeft = model.secondsLeft {
                    Label(clockText(secondsLeft), systemImage: "timer")
                        .font(Print.caption(12))
                        .foregroundStyle(secondsLeft <= 30 ? palette.danger : palette.ink.opacity(0.72))
                        .accessibilityLabel("Time remaining, \(Int(secondsLeft.rounded(.up))) seconds")
                }
                Text("Turn \(min(puzzle.turnNumber, puzzle.turnsMax))/\(puzzle.turnsMax)")
                    .font(Print.caption(12))
                    .foregroundStyle(palette.ink.opacity(0.72))
                    .contentTransition(.numericText())
            }

            if let boss = puzzle.boss {
                BossStamp(boss: boss, censored: puzzle.censoredDigit)
            }

            Rectangle().fill(palette.rule).frame(height: 1)
        }
    }

    private func clockText(_ seconds: Double) -> String {
        let whole = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }

    /// The Book's own handwriting, given room whether or not it speaks, so a
    /// note appearing never shifts the grid.
    private var marginBand: some View {
        ZStack {
            if let note = model.marginNote {
                MarginNoteView(note: note)
                    .id(note.text)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 54, maxHeight: .infinity)
        .padding(.bottom, 2)
        .animation(.easeInOut(duration: 0.45), value: model.marginNote)
    }

    /// Only on the very first page of a Book.
    private var showsInstruction: Bool {
        puzzle.level == 1 && puzzle.slot == .easy
    }

    private var instruction: some View {
        Text("Fill the grid so each column, row and 3x3 box contains numbers 1-9.")
            .font(Print.body(11.5))
            .foregroundStyle(palette.ink.opacity(0.72))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Actions

    private var actionRow: some View {
        HStack(spacing: 10) {
            PaperButton(title: model.tossButtonTitle,
                        subtitle: model.tossButtonSubtitle,
                        kind: .quiet,
                        isEnabled: model.canToss) {
                model.toggleTossMode()
            }

            if puzzle.canUseClue {
                PaperButton(title: "Clue",
                            subtitle: model.selectedSquare == nil
                                ? "pick a square" : "\(puzzle.cluesRemaining) left",
                            kind: .quiet,
                            isEnabled: model.selectedSquare.map {
                                puzzle.board.isBlank($0)
                            } ?? false) {
                    if let square = model.selectedSquare { model.useClue(at: square) }
                }
            }

            // No page turn here: a Turn ending deals a new Hand on the same
            // page. Turning the page for it made every Turn feel like leaving
            // the Puzzle.
            PaperButton(title: "End Turn", kind: .primary) { model.endTurn() }
        }
    }
}

/// Score against target. This is the number the whole run is about, so it gets
/// the weight the mockup gave the puzzle title.
struct ScoreMeter: View {
    @Environment(\.levelPalette) private var palette
    var score: Int
    var target: Int
    var level: Int
    var slot: Int
    /// Correct-play points waiting to be banked at the end of this Turn.
    var queuedBase: Int = 0
    var queuedMultiplier: Double = 1
    /// Coin effects use the engine outcome too, so a Copper payout is visible
    /// beside the placement that triggered it rather than inferred by the UI.
    var recentCoins: Int?

    private var fraction: Double {
        target > 0 ? min(1, Double(score) / Double(target)) : 0
    }
    private var queued: Int { Int((Double(queuedBase) * queuedMultiplier).rounded(.down)) }
    private var reach: Double {
        target > 0 ? min(1, Double(score + queued) / Double(target)) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Score")
                    .font(Print.caption(10)).tracking(1.4).textCase(.uppercase)
                    .foregroundStyle(palette.ink.opacity(0.52))
                RollingNumber(value: score, size: 25, weight: .bold, color: palette.ink)
                Text("of \(target.formatted())")
                    .font(Print.numeral(15, weight: .semibold))
                    .foregroundStyle(palette.ink.opacity(0.52))
                if queuedBase > 0 {
                    Text("+\(queuedBase.formatted()) × \(queuedMultiplier.formatted(.number.precision(.fractionLength(0...2)))) queued")
                        .font(Print.caption(11))
                        .foregroundStyle(palette.accent)
                        .accessibilityLabel("\(queued) points queued until end turn")
                }
                if let recentCoins, recentCoins > 0 {
                    Text("+\(recentCoins) coins")
                        .font(Print.caption(12))
                        .foregroundStyle(Paper.coinRim)
                        .id("coins-\(recentCoins)")
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .accessibilityLabel("Last placement, plus \(recentCoins) coins")
                }
                Spacer(minLength: 6)
                Text("Level \(level)")
                    .font(Print.caption(11))
                    .foregroundStyle(palette.ink.opacity(0.72))
                ProgressDots(index: slot, count: 3)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            // A pencil line filling up along a printed rule.
            ZStack(alignment: .leading) {
                Capsule().fill(palette.rule.opacity(0.45)).frame(height: 5)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(palette.target.opacity(0.45))
                            .frame(width: max(4, proxy.size.width * reach), height: 5)
                        Capsule()
                            .fill(fraction >= 1 ? palette.target : palette.ink.opacity(0.75))
                            .frame(width: max(4, proxy.size.width * fraction), height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(height: 5)
        }
        .animation(.snappy, value: score)
        .animation(.snappy(duration: 0.22), value: queuedBase)
        .animation(.snappy(duration: 0.22), value: queuedMultiplier)
        .animation(.snappy(duration: 0.22), value: recentCoins)
    }
}

/// The Boss Modifier, stamped onto the page in red pencil.
struct BossStamp: View {
    @Environment(\.levelPalette) private var palette
    var boss: BossModifier
    var censored: Digit?

    private var design: BossBoardDesign { BossBoardDesign(boss: boss) }

    var body: some View {
        HStack(spacing: 7) {
            Label(boss.name, systemImage: design.symbol)
                .font(Print.caption(11))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(design.ink)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(design.ink.opacity(0.7), lineWidth: 1.4)
                }
                .rotationEffect(.degrees(design.angle))

            Text(censored.map { "\(boss.text) (\($0.rawValue))" } ?? boss.text)
                .font(Print.body(11.5))
                .foregroundStyle(palette.ink.opacity(0.72))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Buttons

struct PaperButton: View {
    @Environment(\.levelPalette) private var palette
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
        case .primary: return palette.paper
        case .quiet: return palette.ink
        case .danger: return palette.danger
        }
    }
    private var background: Color {
        switch kind {
        case .primary: return palette.target
        case .quiet: return palette.paper.opacity(0.68)
        case .danger: return palette.paper.opacity(0.68)
        }
    }
    private var border: Color {
        kind == .danger ? palette.danger.opacity(0.6) : palette.rule
    }
}

/// A button on paper does not glow; it presses in.
struct PressedPaperStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}

/// Printed at the foot of every page, the way a puzzle book numbers itself.
struct PageNumber: View {
    @Environment(\.levelPalette) private var palette
    var level: Int
    var slot: Int

    /// Three Puzzles a Level, each taking a spread.
    private var page: Int { ((level - 1) * 3 + slot) * 2 + 7 }

    var body: some View {
        HStack(spacing: 6) {
            Rectangle().fill(palette.rule.opacity(0.45)).frame(width: 14, height: 0.75)
            Text("\(page)")
                .font(Print.body(10.5))
                .foregroundStyle(palette.ink.opacity(0.52))
            Rectangle().fill(palette.rule.opacity(0.45)).frame(width: 14, height: 0.75)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityHidden(true)
    }
}
