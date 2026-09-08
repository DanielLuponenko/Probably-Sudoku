import SwiftUI
import ProbablySudokuEngine

/// A final leaf, not another payout receipt. It is presented only after the
/// engine settles the final win; drawing or turning this page cannot pay again.
struct BookVictoryPage: View {
    let summary: GameModel.BookCompletionSummary
    let board: Board?
    let bossName: String
    let obstacle: Obstacle
    let onClose: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { geometry in
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    ScrollView { content(compact: true) }
                } else {
                    ViewThatFits(in: .vertical) {
                        content(compact: false).fixedSize(horizontal: false, vertical: true)
                        content(compact: true).fixedSize(horizontal: false, vertical: true)
                        ScrollView { content(compact: true) }
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func content(compact: Bool) -> some View {
        BookVictoryContents(summary: summary, board: board, bossName: bossName,
                            obstacle: obstacle, compact: compact, onClose: onClose)
    }
}

/// Pure printed content also used by snapshot tests. The celebratory mark is
/// part of the sheet, so it curls with the page and respects Reduce Motion.
struct BookVictoryContents: View {
    let summary: GameModel.BookCompletionSummary
    let board: Board?
    let bossName: String
    let obstacle: Obstacle
    var compact = false
    var onClose: () -> Void = {}
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.bookPresentation) private var bookTheme
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0

    private var nextObstacle: Obstacle? { Obstacle(rawValue: obstacle.rawValue + 1) }
    var nextChallengeTitle: String {
        nextObstacle.map { "\($0.name) is ready" } ?? "All 9 obstacles conquered"
    }

    var body: some View {
        VStack(spacing: compact ? 12 : 17) {
            header
            finalBoard
            completionStrip
            nextChallenge
            closeButton
        }
        .foregroundStyle(theme.paper.ink)
        .frame(maxWidth: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("BOOK COMPLETE")
                .font(Print.heading((compact ? 28 : 32) * textScale))
                .tracking(-0.7)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("completion.heading")
            Text(summary.edition.title)
                .font(Print.body(13 * textScale))
                .foregroundStyle(theme.paper.softInk)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("VOLUME \(summary.edition.rule.volume) · \(obstacle.name.uppercased())")
                    .font(Print.caption(9 * textScale))
                    .tracking(1)
                Spacer(minLength: 8)
                Image(systemName: "sun.max")
                    .font(.system(size: 23, weight: .light))
                    .foregroundStyle(Paper.bookOrange)
                    .accessibilityHidden(true)
            }
            Rectangle().fill(theme.paper.ruleInk).frame(height: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var finalBoard: some View {
        VStack(spacing: compact ? 13 : 16) {
            if let board {
                VictoryBoardPrint(board: board)
                    .frame(maxWidth: compact ? 200 : 246)
                    .overlay(alignment: .bottomTrailing) {
                        Text("FINAL BOSS BEATEN")
                            .font(Print.subheading(compact ? 11 : 13))
                            .tracking(0.4)
                            .foregroundStyle(Paper.sageDeep)
                            .padding(.horizontal, 9).padding(.vertical, 6)
                            .background(theme.paper.page.opacity(0.96))
                            .overlay {
                                Rectangle().strokeBorder(Paper.sageDeep, lineWidth: 2)
                                    .padding(2)
                            }
                            .overlay { Rectangle().strokeBorder(Paper.sageDeep, lineWidth: 0.8) }
                            .rotationEffect(.degrees(-8))
                            .offset(x: 5, y: 7)
                    }
                    .padding(.bottom, 8)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Final boss beaten. Your final board, preserved as you played it.")
            } else {
                Text("FINAL BOSS BEATEN")
                    .font(Print.subheading(18 * textScale))
                    .foregroundStyle(theme.paper.accentInk)
            }
            Text("\(bossName) · defeated")
                .font(Print.caption(11 * textScale))
                .foregroundStyle(theme.paper.softInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var completionStrip: some View {
        VStack(spacing: 7) {
            HStack {
                Text("\(summary.levelsCleared) / 9 LEVELS")
                Spacer(minLength: 8)
                Text("\(summary.bossesBeaten) / 9 BOSSES")
            }
            .font(Print.caption(9 * textScale))
            .tracking(1)
            .foregroundStyle(theme.paper.softInk)
            HStack(spacing: 4) {
                ForEach(0..<9, id: \.self) { _ in
                    Rectangle().fill(Paper.sageDeep).frame(height: 6)
                }
            }
            .accessibilityHidden(true)
            Text("Best Puzzle · \(summary.bestPuzzleScore.formatted())")
                .font(Print.numeral(11 * textScale))
                .foregroundStyle(theme.paper.softInk)
                .fixedSize(horizontal: false, vertical: true)
            Text("You actually did it.")
                // Custom fonts already participate in Dynamic Type. Scaling
                // this again would make the handwriting grow twice as fast.
                .font(Print.handwritten(compact ? 23 : 27))
                .minimumScaleFactor(0.65)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, compact ? 2 : 5)
        }
    }

    private var nextChallenge: some View {
        VStack(spacing: 5) {
            Text(nextChallengeTitle)
                // Serif caps keep Roman numerals distinct from lowercase l.
                .font(.system(size: 16 * textScale, weight: .bold, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
            Text(nextObstacle == nil ? "This Book has nothing left to throw at you."
                                     : "In this Book only. The others keep their own progress.")
                .font(Print.body(11 * textScale))
                .foregroundStyle(theme.paper.softInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 10 : 13).padding(.horizontal, 12)
        .background(theme.paper.accentInk.opacity(0.08))
        .overlay(alignment: .leading) { Rectangle().fill(Paper.sage).frame(width: 3) }
        .accessibilityElement(children: .combine)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            VStack(spacing: 4) {
                Text("CLOSE THE BOOK")
                    .font(Print.subheading(16 * textScale))
                    .tracking(0.7)
                Text("Back to the shelf. Proudly.")
                    .font(Print.body(11 * textScale))
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(bookTheme.buttonForeground)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10).padding(.vertical, 12)
            .background(bookTheme.buttonFill, in: .rect(cornerRadius: 5))
        }
        .buttonStyle(PressedPaperStyle())
        .accessibilityIdentifier("completion.closeBook")
    }
}

/// A read-only print of the ACTUAL board, including its remaining blanks. A
/// score victory is not a solved Sudoku, and must never be illustrated as one.
struct VictoryBoardPrint: View {
    let board: Board
    @Environment(\.cosmeticTheme) private var theme

    var body: some View {
        Canvas { context, size in
            let cell = size.width / 9
            for square in Square.all {
                let origin = CGPoint(x: CGFloat(square.col) * cell, y: CGFloat(square.row) * cell)
                if board.isGiven[square.index] {
                    context.fill(Path(CGRect(origin: origin, size: CGSize(width: cell, height: cell))),
                                 with: .color(theme.paper.accentInk.opacity(0.07)))
                }
                if let digit = board[square] {
                    let text = Text("\(digit.rawValue)")
                        .font(Print.numeral(cell * 0.59))
                        .foregroundStyle(board.filledBy[square.index] == .player
                                         ? theme.paper.accentInk : theme.paper.ink)
                    context.draw(text, at: CGPoint(x: origin.x + cell / 2, y: origin.y + cell / 2))
                }
            }
            for division in 0...9 {
                let inset: CGFloat = 0.75
                let point = min(max(CGFloat(division) * cell, inset), size.width - inset)
                var path = Path()
                path.move(to: CGPoint(x: point, y: 0))
                path.addLine(to: CGPoint(x: point, y: size.height))
                path.move(to: CGPoint(x: 0, y: point))
                path.addLine(to: CGPoint(x: size.width, y: point))
                context.stroke(path, with: .color(theme.paper.ink.opacity(division % 3 == 0 ? 0.9 : 0.3)),
                               lineWidth: division % 3 == 0 ? 1.5 : 0.5)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(theme.paper.page)
        .accessibilityHidden(true)
    }
}
