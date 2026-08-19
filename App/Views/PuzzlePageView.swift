import SwiftUI
import NumberClubEngine

struct PuzzlePageView: View {
    @Bindable var model: GameModel
    var puzzle: PuzzleState
    @Environment(PageFlipper.self) private var flipper
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            ScoreMeter(score: puzzle.score, target: puzzle.target,
                       level: puzzle.level, slot: puzzle.slot.rawValue)

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
                        .foregroundStyle(Paper.inkFaint)
                }
                Spacer(minLength: 4)
                Text("Turn \(min(puzzle.turnNumber, puzzle.turnsMax))/\(puzzle.turnsMax)")
                    .font(Print.caption(12))
                    .foregroundStyle(Paper.inkSoft)
                    .contentTransition(.numericText())
            }

            if let boss = puzzle.boss {
                BossStamp(boss: boss, censored: puzzle.censoredDigit)
            }

            Rectangle().fill(Paper.rule).frame(height: 1)
        }
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
            .foregroundStyle(Paper.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Actions

    private var actionRow: some View {
        HStack(spacing: 10) {
            if model.isTossing {
                PaperButton(title: "Cancel", kind: .quiet) { model.cancelToss() }
                PaperButton(title: "Toss \(model.tossSelection.count)",
                            kind: .primary,
                            isEnabled: !model.tossSelection.isEmpty) { model.confirmToss() }
            } else {
                PaperButton(title: "Toss",
                            subtitle: "\(puzzle.tossesRemaining) left",
                            kind: .quiet,
                            isEnabled: puzzle.tossesRemaining > 0 && !puzzle.hand.isEmpty) {
                    model.beginToss()
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
                PaperButton(title: "End Turn", kind: .primary) {
                    Task { await flipper.flip(from: model, reduceMotion: reduceMotion) { model.endTurn() } }
                }
            }
        }
    }
}

/// Score against target. This is the number the whole run is about, so it gets
/// the weight the mockup gave the puzzle title.
struct ScoreMeter: View {
    var score: Int
    var target: Int
    var level: Int
    var slot: Int

    private var fraction: Double {
        target > 0 ? min(1, Double(score) / Double(target)) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Score")
                    .font(Print.caption(10)).tracking(1.4).textCase(.uppercase)
                    .foregroundStyle(Paper.inkFaint)
                Text(score.formatted())
                    .font(Print.numeral(25, weight: .bold))
                    .foregroundStyle(Paper.ink)
                    .contentTransition(.numericText())
                Text("of \(target.formatted())")
                    .font(Print.numeral(15, weight: .semibold))
                    .foregroundStyle(Paper.inkFaint)
                Spacer(minLength: 6)
                Text("Level \(level)")
                    .font(Print.caption(11))
                    .foregroundStyle(Paper.inkSoft)
                ProgressDots(index: slot, count: 3)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            // A pencil line filling up along a printed rule.
            ZStack(alignment: .leading) {
                Capsule().fill(Paper.pageEdge).frame(height: 5)
                GeometryReader { proxy in
                    Capsule()
                        .fill(fraction >= 1 ? Paper.sage : Paper.ink.opacity(0.75))
                        .frame(width: max(4, proxy.size.width * fraction), height: 5)
                }
                .frame(height: 5)
            }
            .frame(height: 5)
        }
        .animation(.snappy, value: score)
    }
}

/// The Boss Modifier, stamped onto the page in red pencil.
struct BossStamp: View {
    var boss: BossModifier
    var censored: Digit?

    var body: some View {
        HStack(spacing: 7) {
            Text(boss.name)
                .font(Print.caption(11))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Paper.redPencil)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Paper.redPencil.opacity(0.7), lineWidth: 1.4)
                }
                .rotationEffect(.degrees(-1.5))

            Text(censored.map { "\(boss.text) (\($0.rawValue))" } ?? boss.text)
                .font(Print.body(11.5))
                .foregroundStyle(Paper.inkSoft)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Buttons

struct PaperButton: View {
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
        case .primary: return Paper.page
        case .quiet: return Paper.ink
        case .danger: return Paper.redPencil
        }
    }
    private var background: Color {
        switch kind {
        case .primary: return Paper.sage
        case .quiet: return Paper.pageWarm
        case .danger: return Paper.pageWarm
        }
    }
    private var border: Color {
        kind == .danger ? Paper.redPencil.opacity(0.6) : Paper.rule
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
    var level: Int
    var slot: Int

    /// Three Puzzles a Level, each taking a spread.
    private var page: Int { ((level - 1) * 3 + slot) * 2 + 7 }

    var body: some View {
        HStack(spacing: 6) {
            Rectangle().fill(Paper.rule.opacity(0.45)).frame(width: 14, height: 0.75)
            Text("\(page)")
                .font(Print.body(10.5))
                .foregroundStyle(Paper.inkFaint)
            Rectangle().fill(Paper.rule.opacity(0.45)).frame(width: 14, height: 0.75)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityHidden(true)
    }
}
