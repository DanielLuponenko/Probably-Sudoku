import SwiftUI
import ProbablySudokuEngine

/// Geography only: this projection never reads the solution or the selected
/// digit. A lit square describes the boss's price, not a correct placement.
struct BossChainProjection: Equatable {
    let anchor: Square?
    let fullPointSquares: Set<Square>
    let halfPointSquares: Set<Square>

    init(puzzle: PuzzleState?) {
        guard let puzzle, puzzle.boss == .chainStitcher, puzzle.phase == .playing,
              let anchor = puzzle.bossState.scoring.chainAnchor else {
            anchor = nil; fullPointSquares = []; halfPointSquares = []
            return
        }
        self.anchor = anchor
        let available = Set(puzzle.board.blanks.filter {
            !puzzle.isBarred($0) || BuffRuntime.passageAllows($0, puzzle: puzzle)
        })
        fullPointSquares = Set(available.filter { Self.links(anchor, $0) })
        halfPointSquares = available.subtracting(fullPointSquares)
    }

    static func links(_ a: Square, _ b: Square) -> Bool {
        a.row == b.row || a.col == b.col || a.box == b.box
    }

    func accessibilityHint(for square: Square) -> String? {
        if fullPointSquares.contains(square) { return "Lit square. Full placement points if correct without a Clue." }
        if halfPointSquares.contains(square) { return "Outside the lit area. Half placement points if correct without a Clue." }
        return nil
    }
}

/// Full-price wells have an inset brass rim and warm glow, distinct from the
/// existing sage matching-number selection. The stitch
/// stays on the last real fill; only the short, committed move draws a thread.
struct BossChainGuidance: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.bossMotionIsActive) private var presented
    @Environment(\.scenePhase) private var scenePhase
    let projection: BossChainProjection
    @State private var previousAnchor: Square?
    @State private var lastAnchor: Square?
    @State private var stitchProgress: CGFloat = 1

    private var canAnimate: Bool { !reduceMotion && presented && scenePhase == .active }

    var body: some View {
        GeometryReader { proxy in
            let cell = min(proxy.size.width, proxy.size.height) / 9
            Canvas { context, _ in
                for square in projection.fullPointSquares {
                    let rect = CGRect(x: CGFloat(square.col) * cell + 3,
                                      y: CGFloat(square.row) * cell + 3,
                                      width: cell - 6, height: cell - 6)
                    let well = Path(roundedRect: rect, cornerRadius: 2)
                    context.fill(well, with: .linearGradient(
                        Gradient(colors: [Color(hex: 0xF7D681).opacity(0.70), Color(hex: 0xD9B45B).opacity(0.26)]),
                        startPoint: rect.origin, endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
                    context.stroke(well, with: .color(Paper.coinRim.opacity(0.75)), lineWidth: 1.3)
                }
                if let anchor = projection.anchor {
                    let rect = CGRect(x: CGFloat(anchor.col) * cell + 2,
                                      y: CGFloat(anchor.row) * cell + 2,
                                      width: cell - 4, height: cell - 4)
                    context.stroke(Path(roundedRect: rect, cornerRadius: 2),
                                   with: .color(Paper.coinRim), lineWidth: 2.4)
                }
            }
            if let anchor = projection.anchor {
                Image(systemName: "link")
                    .font(.system(size: max(9, cell * 0.25), weight: .bold))
                    .foregroundStyle(Paper.coinRim)
                    .position(x: (CGFloat(anchor.col) + 0.22) * cell,
                              y: (CGFloat(anchor.row) + 0.82) * cell)
                if let previousAnchor, canAnimate {
                    BossChainStitch(from: previousAnchor, to: anchor, cell: cell,
                                    progress: stitchProgress)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: projection.anchor) {
            let old = lastAnchor
            lastAnchor = projection.anchor
            previousAnchor = old
            guard old != nil, projection.anchor != nil, canAnimate else { stitchProgress = 1; return }
            stitchProgress = 0
            await Task.yield()
            guard !Task.isCancelled, canAnimate else { stitchProgress = 1; return }
            withAnimation(.easeOut(duration: 0.8)) { stitchProgress = 1 }
        }
        .onChange(of: canAnimate) { _, active in
            if !active { previousAnchor = nil; stitchProgress = 1 }
        }
    }
}

private struct BossChainStitch: View, Animatable {
    let from: Square
    let to: Square
    let cell: CGFloat
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, _ in
            let start = CGPoint(x: (CGFloat(from.col) + 0.5) * cell, y: (CGFloat(from.row) + 0.82) * cell)
            let end = CGPoint(x: (CGFloat(to.col) + 0.5) * cell, y: (CGFloat(to.row) + 0.82) * cell)
            let linked = BossChainProjection.links(from, to)
            var thread = Path()
            thread.move(to: start)
            thread.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2,
                                                        y: (start.y + end.y) / 2 + cell * 0.45))
            context.opacity = Double(min(1, (1 - progress) * 3))
            context.stroke(thread.trimmedPath(from: 0, to: min(1, progress * 3)),
                           with: .color(linked ? Paper.coinRim : Paper.redPencil),
                           style: StrokeStyle(lineWidth: 2.4, lineCap: .round,
                                              dash: linked ? [] : [5, 7]))
            if !linked, progress > 0.2 {
                let label = Text("½ points").font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Paper.redPencil)
                let center = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
                let paper = CGRect(x: center.x - 37, y: center.y - 12, width: 74, height: 24)
                context.fill(Path(roundedRect: paper, cornerRadius: 4), with: .color(GameplaySurface.ivory))
                context.draw(label, at: center)
            }
        }
    }
}

struct BossChainLegend: View {
    let hasAnchor: Bool
    var body: some View {
        if hasAnchor {
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 5) {
                    Text("Lit ×1")
                        .foregroundStyle(GameplaySurface.ink)
                        .padding(.horizontal, 5).padding(.vertical, 3)
                        .background(Color(hex: 0xF7D681), in: RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Paper.coinRim, lineWidth: 1))
                    Text("Other ½").foregroundStyle(GameplaySurface.softInk)
                }
                .font(Print.numeral(13, weight: .semibold))
                Text("Placement points").font(Print.caption(10)).foregroundStyle(GameplaySurface.softInk)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Lit squares keep full placement points. Other squares earn half placement points. Correct numbers without Clues only; Clue scoring is unchanged.")
        } else {
            Label("Place a number to start", systemImage: "link")
                .font(Print.body(12)).foregroundStyle(GameplaySurface.softInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
