import SwiftUI
import ProbablySudokuEngine

/// The celebration is one sheet. The final board receives the space left by
/// measured text and the Close action, so no final row sits behind a footer.
struct BookVictoryPage: View {
    let summary: GameModel.BookCompletionSummary
    let board: Board?
    let bossName: String
    let obstacle: Obstacle
    let onClose: () -> Void
    var markers: [Square: OwnedMarker] = [:]
    var puzzle: PuzzleState? = nil

    var body: some View {
        GeometryReader { geometry in
            BookVictoryContents(summary: summary, board: board, bossName: bossName,
                                obstacle: obstacle, compact: geometry.size.height < 620,
                                onClose: onClose, markers: markers, puzzle: puzzle)
        }
        .accessibilityIdentifier("completion.single-screen")
    }
}

struct BookVictoryBoardLayout {
    let available: CGSize
    let headerHeight: CGFloat
    let footerHeight: CGFloat
    var spacing: CGFloat = 10
    var maximumSide: CGFloat = 540

    var side: CGFloat {
        max(0, min(maximumSide, available.width,
                   available.height - headerHeight - footerHeight - spacing * 2))
    }
}

private struct BookVictoryLayout: Layout {
    var spacing: CGFloat
    var maximumBoardSide: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 3 else { return proposal.replacingUnspecifiedDimensions() }
        let width = proposal.width ?? 328
        let column = ProposedViewSize(width: width, height: nil)
        let naturalHeight = subviews[0].sizeThatFits(column).height
            + subviews[2].sizeThatFits(column).height + min(width, maximumBoardSide) + spacing * 2
        return CGSize(width: width, height: proposal.height ?? naturalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let column = ProposedViewSize(width: bounds.width, height: nil)
        let header = subviews[0].sizeThatFits(column)
        let footer = subviews[2].sizeThatFits(column)
        let side = BookVictoryBoardLayout(available: bounds.size, headerHeight: header.height,
            footerHeight: footer.height, spacing: spacing, maximumSide: maximumBoardSide).side
        subviews[0].place(at: bounds.origin, proposal: column)
        let middle = max(0, bounds.height - header.height - footer.height)
        subviews[1].place(at: CGPoint(x: bounds.midX - side / 2,
            y: bounds.minY + header.height + max(0, (middle - side) / 2)),
            proposal: ProposedViewSize(width: side, height: side))
        subviews[2].place(at: CGPoint(x: bounds.minX, y: bounds.maxY - footer.height), proposal: column)
    }
}

/// Pure presentation: the earned achievement comes from the same catalogue
/// as the permanent record. Rendering and reopening cannot grant it again.
struct BookVictoryContents: View {
    let summary: GameModel.BookCompletionSummary
    let board: Board?
    let bossName: String
    let obstacle: Obstacle
    var compact = false
    var onClose: () -> Void = {}
    var markers: [Square: OwnedMarker] = [:]
    var puzzle: PuzzleState? = nil
    var showsCloseButton = true
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 34

    private var accessible: Bool { dynamicTypeSize.isAccessibilitySize }
    private var nextObstacle: Obstacle? { Obstacle(rawValue: obstacle.rawValue + 1) }
    private var achievement: AchievementDefinition { AchievementCatalog.bookCompletion(for: summary.edition.rule) }
    var nextChallengeTitle: String {
        nextObstacle.map { "\($0.name) is ready" } ?? "All 9 obstacles conquered"
    }

    var body: some View {
        BookVictoryLayout(spacing: compact ? 8 : 12, maximumBoardSide: compact ? 360 : 540) {
            header
            finalBoard
            footer
        }
        .foregroundStyle(theme.paper.ink)
    }

    private var header: some View {
        VStack(spacing: accessible ? 4 : 7) {
            if !accessible {
                Text("BOOK COMPLETE")
                    .font(Print.caption(10 * textScale)).tracking(2)
                    .foregroundStyle(Paper.sageDeep)
            }
            Text("Congratulations!")
                .font(.system(size: compact ? titleSize * 0.87 : titleSize, weight: .bold, design: .serif))
                .tracking(-0.8)
                .lineLimit(1).minimumScaleFactor(0.65)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("completion.heading")
            Text(summary.edition.title)
                .font(.system(size: (accessible ? 11 : 15) * textScale, weight: .medium, design: .serif))
                .foregroundStyle(theme.paper.softInk)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("completion.bookTitle")
            if !accessible {
                HStack(spacing: 8) {
                    Rectangle().fill(theme.paper.ruleInk).frame(height: 1)
                    Text("VOLUME \(summary.edition.rule.volume) · \(obstacle.name.uppercased())")
                        .font(Print.caption(9 * textScale)).tracking(0.8)
                        .fixedSize()
                    Rectangle().fill(theme.paper.ruleInk).frame(height: 1)
                }
                .padding(.top, 3)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Book complete")
    }

    private var finalBoard: some View {
        Group {
            if let board {
                GameplayBoardSnapshot(board: board, markers: markers, puzzle: puzzle)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Your final board, preserved as you played it. Read only.")
            } else {
                Color.clear.accessibilityHidden(true)
            }
        }
        .accessibilityIdentifier("completion.finalBoard")
    }

    private var footer: some View {
        VStack(spacing: accessible ? 7 : (compact ? 8 : 11)) {
            if !accessible {
                HStack(spacing: 8) {
                    Text("FINAL BOSS BEATEN")
                        .font(Print.caption(9 * textScale)).tracking(0.4)
                        .foregroundStyle(Paper.sageDeep)
                    Text(bossName)
                        .font(Print.body(10 * textScale)).foregroundStyle(theme.paper.softInk)
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            achievementReceipt
            if !accessible {
                HStack {
                    Text("\(summary.levelsCleared) levels · \(summary.bossesBeaten) bosses")
                    Spacer(minLength: 4)
                    Text("Best Puzzle \(summary.bestPuzzleScore.formatted())")
                }
                .font(Print.caption(10 * textScale)).foregroundStyle(theme.paper.softInk)
            }
            Text(nextChallengeTitle)
                .font(.system(size: (accessible ? 10 : 13) * textScale, weight: .semibold, design: .serif))
                .foregroundStyle(Paper.sageDeep)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("\(nextChallengeTitle). In this Book only.")
            if showsCloseButton { closeButton }
        }
        .accessibilityElement(children: .contain)
    }

    private var achievementReceipt: some View {
        HStack(spacing: accessible ? 10 : 14) {
            if !accessible {
                ZStack {
                    Circle().fill(Paper.sageDeep.opacity(0.11))
                    Circle().strokeBorder(Paper.sageDeep.opacity(0.5), lineWidth: 1)
                        .padding(4)
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: compact ? 22 : 25, weight: .regular))
                        .foregroundStyle(Paper.sageDeep)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 15)).foregroundStyle(Paper.bookOrange)
                        .offset(x: 18, y: 18)
                }
                .frame(width: compact ? 54 : 60, height: compact ? 54 : 60)
                .accessibilityHidden(true)
            }
            VStack(alignment: accessible ? .center : .leading, spacing: 4) {
                Text("BOOK ACHIEVEMENT")
                    .font(Print.caption((accessible ? 8 : 9) * textScale))
                    .tracking(accessible ? 0.2 : 1)
                    .foregroundStyle(Paper.sageDeep)
                Text(achievement.title)
                    .font(.system(size: (accessible ? 12 : 20) * textScale, weight: .bold, design: .serif))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: accessible ? .center : .leading)
        }
        .padding(.horizontal, accessible ? 8 : 14)
        .padding(.vertical, accessible ? 8 : 11)
        .background(theme.paper.warm.opacity(0.72), in: .rect(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5).strokeBorder(Paper.sageDeep.opacity(0.28), lineWidth: 1)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(Paper.sageDeep.opacity(0.65)).frame(height: 2).padding(.horizontal, 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Book achievement: \(achievement.title). \(achievement.detail) Permanent achievement. \(obstacle.name). \(bossName) defeated. \(summary.levelsCleared) levels and \(summary.bossesBeaten) bosses completed. Best Puzzle score \(summary.bestPuzzleScore.formatted()).")
        .accessibilityIdentifier("completion.achievement")
    }

    private var closeButton: some View {
        Button(action: onClose) {
            HStack(spacing: 10) {
                Text("Close the Book")
                    .font(Print.subheading((accessible ? 12 : 16) * textScale))
                if !accessible {
                    Image(systemName: "arrow.right").font(.system(size: 15, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 10).padding(.vertical, accessible ? 4 : 7)
            .foregroundStyle(Paper.page)
            .background(Paper.sageDeep, in: .rect(cornerRadius: 5))
        }
        .buttonStyle(PressedPaperStyle())
        .accessibilityLabel("Close the Book")
        .accessibilityHint("Back to the shelf")
        .accessibilityIdentifier("completion.close")
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
