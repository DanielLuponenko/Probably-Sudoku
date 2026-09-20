import SwiftUI
import ProbablySudokuEngine

/// One physical frame encloses all 81 square wells. Its inset is part of the
/// layout, so cell frames (including motion targets) never include the rim.
struct GameplayBoardGeometry {
    let side: CGFloat
    var inset: CGFloat { min(6, max(4, side * 0.014)) }
    var contentSide: CGFloat { max(0, side - inset * 2) }
    var cellSide: CGFloat { contentSide / 9 }

    func cellFrame(_ square: Square) -> CGRect {
        CGRect(x: inset + CGFloat(square.col) * cellSide,
               y: inset + CGFloat(square.row) * cellSide,
               width: cellSide, height: cellSide)
    }
}

private enum BoardMaterial {
    static let sage = Color(hex: 0x5F867C)
    static let edge = Color(hex: 0x3F655B)
    static let ivory = Color(hex: 0xF5EDDF)
    static let recess = Color(hex: 0x806848)
    static let ink = Color(hex: 0x111411)
}

/// A settled record of the real board. Reuses gameplay wells, cells, glyphs,
/// markers and restrictions, without selection, score flashes or input.
struct GameplayBoardSnapshot: View {
    let board: Board
    var markers: [Square: OwnedMarker] = [:]
    var puzzle: PuzzleState? = nil
    @Environment(\.cosmeticTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            let palette = LevelPalette.forDisplay(slot: puzzle?.slot ?? .easy).resolved(for: theme.paper)
            let geometry = GameplayBoardGeometry(side: min(proxy.size.width, proxy.size.height))
            let cell = geometry.cellSide
            let fouled = Set(puzzle?.bossTurn?.fouled.keys.map { $0 } ?? [])
            let greyed = puzzle?.bossTurn?.greyed ?? []
            ZStack(alignment: .topLeading) {
                Rectangle().fill(BoardMaterial.ivory)
                RecessedCellWells(cell: cell)
                ForEach(Square.all, id: \.index) { square in
                    let marker = puzzle?.boss?.hidesMarkedSquares == true ? nil : markers[square]
                    CellView(square: square, digit: board[square], provenance: board.filledBy[square.index],
                             state: puzzle?.isBarred(square) == true ? .barred : .plain,
                             marker: marker, fouled: fouled.contains(square),
                             greyed: greyed.contains(square), theme: theme, palette: palette, size: cell)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(GridCellAccessibility.label(square: square, digit: board[square],
                            provenance: board.filledBy[square.index], marker: marker,
                            markersAreHidden: puzzle?.boss?.hidesMarkedSquares == true))
                        .accessibilityAddTraits(.isStaticText)
                        .position(x: (CGFloat(square.col) + 0.5) * cell,
                                  y: (CGFloat(square.row) + 0.5) * cell)
                }
                BossBoardOverlay(puzzle: puzzle, reduceMotionOverride: true,
                                 isActive: false, phaseOverride: 0)
                GameplayGridRules(cell: cell)
            }
            .frame(width: geometry.contentSide, height: geometry.contentSide)
            .padding(geometry.inset)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(colors: [BoardMaterial.sage, BoardMaterial.sage,
                                                  BoardMaterial.edge.opacity(0.95)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.2), lineWidth: 0.7) }
                    .shadow(color: BoardMaterial.edge.opacity(0.26), radius: 2, x: 0, y: 3)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .transaction { $0.disablesAnimations = true }
        .allowsHitTesting(false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Your board, as played. Read only.")
        .accessibilityIdentifier("results.played-board")
    }
}

/// Square recessed wells and live numerals, with clay bricks only over the
/// Garrys' engine-authored restricted cells.
struct GridView: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.levelPalette) private var palette
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.markerInspectionPresenter) private var inspector
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.bossMotionIsActive) private var routeIsVisible
    @State private var inspectionOwners = Dictionary(uniqueKeysWithValues: Square.all.map { ($0, UUID()) })
    @Bindable var model: GameModel
    var board: Board
    var fogPhaseOverride: Double? = nil

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let geometry = GameplayBoardGeometry(side: side)
            let cell = geometry.cellSide

            ZStack(alignment: .topLeading) {
                Rectangle().fill(BoardMaterial.ivory)
                RecessedCellWells(cell: cell)
                if model.markersAreHidden {
                    if let fogPhaseOverride {
                        BossFogDrawing(elapsed: fogPhaseOverride)
                    } else if !model.animatesHandArrival {
                        // Frozen page captures must draw the settled mist
                        // directly, without a lifecycle-owned timeline/task.
                        BossFogDrawing(elapsed: 0)
                    } else {
                        let key = "entrance:\(model.bossEntranceID?.uuidString ?? "restored"):fog"
                        BossFogLayer(animatesEntrance: model.bossEntranceID != nil
                                        && !model.hasConsumedBossVisualEvent(key),
                                     consumeEntrance: { model.consumeBossVisualEvent(key) })
                            .id(key)
                    }
                }
                if model.puzzle?.boss == .chainStitcher {
                    BossChainGuidance(projection: BossChainProjection(puzzle: model.puzzle))
                }
                cells(cell: cell, geometry: geometry, origin: proxy.frame(in: .global).origin)
                BossBoardOverlay(puzzle: model.puzzle, secondsLeft: model.clockIsUrgent ? 30 : nil,
                                 includesBricks: false, inkEvent: inkEvent,
                                 consumeInkEvent: { model.consumeBossVisualEvent("ink:\($0.uuidString)") })
                GameplayGridRules(cell: cell)
                // Airborne clay falls above the frame. Drawing the rules last
                // sliced moving bricks whenever they crossed a box boundary.
                // At rest the sprite, shadow and dust remain inside their cell.
                BossBrickLandingOverlay(feedback: BossBoardFeedback(puzzle: model.puzzle),
                                        reduceMotion: reduceMotion,
                                        permitsInitialEntrance: model.bossEntranceID != nil,
                                        hasConsumedEvent: { model.hasConsumedBossVisualEvent(brickKey($0)) },
                                        consumeEvent: { model.consumeBossVisualEvent(brickKey($0)) })
                if let inspected = inspector?.session?.square, inspector?.info(in: model) != nil {
                    Rectangle().strokeBorder(GameplaySurface.sage, lineWidth: 2)
                        .padding(2)
                        .frame(width: cell, height: cell)
                        .position(x: (CGFloat(inspected.col) + 0.5) * cell,
                                  y: (CGFloat(inspected.row) + 0.5) * cell)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                clears(side: geometry.contentSide, cell: cell)
                if let beat = model.scoreBeat,
                   let square = ScoringSourceHighlights.markerSquare(for: beat, board: board,
                       visibleMarkers: model.visibleMarkers, markersAreHidden: model.markersAreHidden,
                       claims: model.run.markerState.claims) {
                    ScoringSourceOutline(trigger: beat.id.uuidString)
                        .padding(2)
                        .frame(width: cell, height: cell)
                        .position(x: (CGFloat(square.col) + 0.5) * cell,
                                  y: (CGFloat(square.row) + 0.5) * cell)
                }
            }
            .frame(width: geometry.contentSide, height: geometry.contentSide)
            .padding(geometry.inset)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(colors: [BoardMaterial.sage, BoardMaterial.sage,
                                                  BoardMaterial.edge.opacity(0.95)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(.white.opacity(0.20), lineWidth: 0.7)
                    }
                    .shadow(color: BoardMaterial.edge.opacity(0.26), radius: 2, x: 0, y: 3)
                    .shadow(color: .black.opacity(0.10), radius: 5, x: 0, y: 4)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .numberReturnMotionFrame(NumberReturnMotionAnchor.grid)
        .cosmeticPulseClock(for: theme.numbers.finish)
    }

    private func brickKey(_ event: BossBrickLandingEvent) -> String {
        "bricks:\(model.run.seed):\(model.puzzle?.level ?? 0):\(model.bossEntranceID?.uuidString ?? "restored"):\(event.boss?.rawValue ?? "none"):\(event.turn)"
    }

    private var inkEvent: BossInkLandingEvent? {
        // A real first encounter may wait behind a curl longer than the short
        // card-return receipt. Keep that one stable entrance until revealed.
        if model.puzzle?.boss == .overPusher, model.puzzle?.turnNumber == 1,
           let entrance = model.bossEntranceID {
            return BossInkLandingEvent(id: entrance, squares: model.fouledSquares)
        }
        guard let event = model.numberReturns.last(where: { $0.kind == .fouled }) else { return nil }
        return BossInkLandingEvent(id: event.id, squares: Set(event.fouledSquares))
    }

    // MARK: Cells

    private func cells(cell: CGFloat, geometry: GameplayBoardGeometry, origin: CGPoint) -> some View {
        let fouledSquares = model.fouledSquares
        let greyedSquares = model.greyedSquares
        let visibleMarkers = model.visibleMarkers

        return ForEach(Square.all, id: \.index) { square in
            let digit = board[square]
            let provenance = board.filledBy[square.index]
            let cellState = state(for: square)
            let marker = visibleMarkers[square]
            let frame = geometry.cellFrame(square).offsetBy(dx: origin.x, dy: origin.y)
            let owner = inspectionOwners[square]!
                CellView(
                    square: square,
                    digit: digit,
                    provenance: provenance,
                    state: cellState,
                    marker: marker,
                    fouled: fouledSquares.contains(square),
                    greyed: greyedSquares.contains(square),
                    theme: theme,
                    palette: palette,
                    size: cell
                )
            .overlay {
                MarkerCellTouchSurface(canInspect: {
                    model.acceptsPuzzleInput && model.page == .puzzle && scenePhase == .active
                        && routeIsVisible && inspector != nil && model.visibleMarkers[square] != nil
                }, onTap: {
                    inspector?.dismiss()
                    if !model.isBarred(square) { model.tapSquare(square) }
                }, onBegin: {
                    inspector?.begin(square: square, model: model, cellFrame: frame, source: .touch(owner))
                }, onEnd: { inspector?.endTouch(owner: owner) })
            }
            .numberReturnMotionFrame(NumberReturnMotionAnchor.cell(square))
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("board-cell-\(square.row + 1)-\(square.col + 1)")
            .accessibilityAction {
                inspector?.dismiss()
                if !model.isBarred(square) { model.tapSquare(square) }
            }
            .accessibilityActions {
                if marker != nil, inspector != nil {
                    Button("Inspect marker") {
                        inspector?.begin(square: square, model: model, cellFrame: frame, source: .accessibility)
                    }
                }
            }
            .accessibilityLabel(accessibilityLabel(for: square, digit: digit,
                                                    provenance: provenance,
                                                    marker: marker))
            .accessibilityValue(accessibilityValue(for: square, digit: digit,
                                                    provenance: provenance,
                                                    state: cellState))
            .accessibilityHint(accessibilityHint(for: square, digit: digit,
                                                  state: cellState))
            .accessibilityAddTraits(model.selectedSquare == square ? .isSelected : [])
            .position(x: (CGFloat(square.col) + 0.5) * cell,
                      y: (CGFloat(square.row) + 0.5) * cell)
        }
    }

    private func accessibilityLabel(for square: Square, digit: Digit?,
                                    provenance: Provenance?, marker: OwnedMarker?) -> String {
        GridCellAccessibility.label(square: square, digit: digit, provenance: provenance,
                                    marker: marker, markersAreHidden: model.markersAreHidden)
    }

    private func accessibilityValue(for square: Square, digit: Digit?,
                                    provenance: Provenance?, state: CellState) -> String {
        if state == .barred { return "Unavailable this turn" }
        if state == .clueDestination { return "Clue destination for selected number" }
        if model.selectedSquare == square { return "Selected" }
        if state == .rightHere { return "Litmus match" }
        if state == .wrongHere { return "Litmus mismatch" }
        if state == .sameNumber { return "Matches selected number" }
        if digit == nil { return "Available" }
        switch provenance {
        case .given: return "Given number"
        case .player: return "Placed number"
        case .clue: return "Clue number"
        case nil: return "Number"
        }
    }

    func accessibilityHint(for square: Square, digit: Digit?, state: CellState) -> String {
        if state == .barred { return "This square cannot be used this turn." }
        if state == .clueDestination {
            return "Place the selected card here. This Clue placement scores zero unless an Onyx Marker restores its placement points."
        }
        if let selected = model.selectedDigit, digit == nil {
            if let index = model.selectedHandIndex, model.isBlocked(handIndex: index) {
                return model.handRestrictionDescription(index) ?? "The selected card cannot be placed this Turn."
            }
            let warning = model.wouldConflict(square, with: selected)
                ? " This placement conflicts with the row, column, or box."
                : ""
            let price = BossChainProjection(puzzle: model.puzzle).accessibilityHint(for: square)
                .map { " " + $0 } ?? ""
            return "Places number \(selected.rawValue).\(warning)\(price)"
        }
        if let digit { return "Select to inspect number \(digit.rawValue)." }
        return "Select a number from the hand, then activate to place it here."
            + (BossChainProjection(puzzle: model.puzzle).accessibilityHint(for: square).map { " " + $0 } ?? "")
    }

    private func state(for square: Square) -> CellState {
        // The square you tapped is one of the matches, so it is marked the same
        // way. Giving it its own colour made it look like a different kind of
        // thing from the numbers it had just found.
        if model.isBarred(square) { return .barred }
        if model.isClueDestination(square) { return .clueDestination }
        if let belongs = model.litmusReading(at: square) {
            return belongs ? .rightHere : .wrongHere
        }
        if let digit = model.highlightedDigit, board[square] == digit { return .sameNumber }
        if model.selectedSquare == square { return .selected }
        return .plain
    }

    /// A completed row, column or box, marked once and then let go. Completing
    /// a unit is worth far more than a placement (§6), so it is worth seeing.
    private func clears(side: CGFloat, cell: CGFloat) -> some View {
        ForEach(model.cleared) { clear in
            ClearedUnitMark(cells: Geometry.cells(of: clear.unit, through: clear.square),
                            cell: cell,
                            palette: palette)
        }
        .allowsHitTesting(false)
    }

}

enum GridCellAccessibility {
    static func label(square: Square, digit: Digit?, provenance: Provenance?,
                      marker: OwnedMarker?, markersAreHidden: Bool) -> String {
        var parts = ["Row \(square.row + 1), column \(square.col + 1)"]
        parts.append(digit.map { "number \($0.rawValue)" } ?? "empty")
        switch provenance {
        case .given: parts.append("given")
        case .player: parts.append("placed")
        case .clue: parts.append("clue")
        case nil: break
        }
        if !markersAreHidden, let marker {
            parts.append(marker.def.name)
            parts.append(provenance == .given ? "inactive under given number" : marker.def.text)
        }
        return parts.joined(separator: ", ")
    }
}

/// Draw every bevel in one static canvas instead of giving every button its
/// own shadow renderer. Light falls from the upper left onto recessed wells.
private struct RecessedCellWells: View {
    let cell: CGFloat

    var body: some View {
        Canvas { context, _ in
            for square in Square.all {
                let inset = max(0.6, cell * 0.018)
                let rect = CGRect(x: CGFloat(square.col) * cell + inset,
                                  y: CGFloat(square.row) * cell + inset,
                                  width: cell - inset * 2, height: cell - inset * 2)
                let bevel = max(2.0, cell * 0.072)
                context.fill(Path(rect), with: .linearGradient(
                    Gradient(colors: [BoardMaterial.recess.opacity(0.10), .clear, .white.opacity(0.12)]),
                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)))
                // Broad, fading shadows belong inside the well. The thin
                // ivory lip stays above them rather than becoming a green
                // hairline between every pair of cells.
                let topShadow = CGRect(x: rect.minX, y: rect.minY,
                                       width: rect.width, height: bevel)
                context.fill(Path(topShadow), with: .linearGradient(
                    Gradient(colors: [BoardMaterial.recess.opacity(0.37), .clear]),
                    startPoint: CGPoint(x: rect.midX, y: rect.minY),
                    endPoint: CGPoint(x: rect.midX, y: rect.minY + bevel)))
                let leftShadow = CGRect(x: rect.minX, y: rect.minY,
                                        width: bevel, height: rect.height)
                context.fill(Path(leftShadow), with: .linearGradient(
                    Gradient(colors: [BoardMaterial.recess.opacity(0.22), .clear]),
                    startPoint: CGPoint(x: rect.minX, y: rect.midY),
                    endPoint: CGPoint(x: rect.minX + bevel, y: rect.midY)))
                context.stroke(Path(rect), with: .color(.white.opacity(0.74)), lineWidth: 0.8)
                var light = Path()
                light.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                light.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
                light.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
                context.stroke(light, with: .color(.white.opacity(0.95)), lineWidth: max(1.1, cell * 0.033))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct GameplayGridRules: View {
    let cell: CGFloat

    var body: some View {
        Canvas { context, size in
            for index in stride(from: 0, through: 9, by: 3) {
                var line = Path()
                let position = CGFloat(index) * cell
                line.move(to: CGPoint(x: position, y: 0))
                line.addLine(to: CGPoint(x: position, y: size.height))
                line.move(to: CGPoint(x: 0, y: position))
                line.addLine(to: CGPoint(x: size.width, y: position))
                let width = max(3, cell * 0.105)
                context.stroke(line, with: .color(BoardMaterial.edge.opacity(0.60)), lineWidth: width + 0.8)
                context.stroke(line, with: .color(BoardMaterial.sage), lineWidth: width)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

enum CellState {
    case plain, selected, sameNumber, barred, rightHere, wrongHere, clueDestination
}

/// Pencil hatching across a square that cannot be used this Turn.
private struct Hatching: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX - rect.height
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += rect.width / 3.5
        }
        return path
    }
}

/// Washes the cells of a finished unit and rules a heavy line round it — the
/// whole row for a row, and the box's own three-by-three for a box.
private struct ClearedUnitMark: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    var cells: [Square]
    var cell: CGFloat
    var palette: LevelPalette
    @State private var shown = false

    private var bounds: CGRect {
        let rows = cells.map(\.row), cols = cells.map(\.col)
        let minRow = rows.min() ?? 0, maxRow = rows.max() ?? 0
        let minCol = cols.min() ?? 0, maxCol = cols.max() ?? 0
        return CGRect(x: CGFloat(minCol) * cell,
                      y: CGFloat(minRow) * cell,
                      width: CGFloat(maxCol - minCol + 1) * cell,
                      height: CGFloat(maxRow - minRow + 1) * cell)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Multiplied rather than painted over: the numbers in the unit are
            // the point of it, and an opaque wash hides them.
            ForEach(cells, id: \.index) { square in
                Rectangle()
                    .fill(palette.target.opacity(0.22))
                    .blendMode(.multiply)
                    .frame(width: cell, height: cell)
                    .offset(x: CGFloat(square.col) * cell, y: CGFloat(square.row) * cell)
            }
            Rectangle()
                .strokeBorder(palette.target, lineWidth: 3)
                .frame(width: bounds.width, height: bounds.height)
                .offset(x: bounds.minX, y: bounds.minY)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .opacity(shown ? 1 : 0)
        .task {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { shown = true }
            // Separate the reveal and fade into different display updates.
            // Two immediate writes in onAppear coalesced into an invisible flash.
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.55)) { shown = false }
        }
    }
}

/// Litmus conveys its verdict through shape as well as its cell tint.
struct LitmusIndicator: View {
    let isMatch: Bool
    let size: CGFloat

    var body: some View {
        Image(systemName: isMatch ? "checkmark" : "xmark")
            .font(.system(size: max(9, size * 0.25), weight: .bold))
            .foregroundStyle(GameplaySurface.ink.opacity(0.82))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private struct CellView: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    var square: Square
    var digit: Digit?
    var provenance: Provenance?
    var state: CellState
    var marker: OwnedMarker?
    var fouled: Bool
    var greyed: Bool
    var theme: CosmeticTheme
    var palette: LevelPalette
    var size: CGFloat

    var body: some View {
        ZStack {
            Rectangle().fill(background)

            if let marker {
                // The catalogue's symbol identifies the effect without
                // depending on color. Ownership stays visible under givens,
                // but its lower opacity makes the inactive state distinct.
                ItemArtwork(id: marker.defID, size: max(9, size * 0.26), style: .glyph)
                    .font(.system(size: max(7, size * 0.20), weight: .semibold))
                    .foregroundStyle(Paper.markerColor(marker.defID))
                    .opacity(provenance == .given ? 0.40 : 0.95)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(size * 0.09)
                    .accessibilityHidden(true)
            }

            if state == .sameNumber {
                Rectangle()
                    .strokeBorder(palette.accent.opacity(0.8), lineWidth: 1.5)
            }

            if state == .rightHere || state == .wrongHere {
                LitmusIndicator(isMatch: state == .rightHere, size: size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(size * 0.09)
            }

            if state == .clueDestination {
                RoundedRectangle(cornerRadius: size * 0.08)
                    .strokeBorder(Paper.coinRim, lineWidth: 2.5)
                    .padding(2)
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: size * 0.44, weight: .medium))
                    .foregroundStyle(Paper.coinRim)
                    .accessibilityHidden(true)
            }

            if state == .barred && !greyed && !fouled {
                Hatching()
                    .stroke(palette.ink.opacity(0.30), lineWidth: 1)
                    .clipShape(Rectangle())
            }


            if let digit {
                CosmeticNumberGlyph(text: "\(digit.rawValue)", skin: theme.numbers,
                                    size: size * 0.59, weight: numeralWeight,
                                    color: inkColor, showsPressShadow: false)
                    .transition(reduceMotion ? .identity : placementTransition)
            }


        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .animation(reduceMotion ? nil : theme.numbers.motion.arrivalAnimation, value: digit)
        .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: state)
    }

    private var numeralWeight: Font.Weight {
        if state == .sameNumber { return .bold }
        return provenance == .given ? .medium : .regular
    }

    private var background: Color {
        switch state {
        case .selected: return theme.board.selected
        case .sameNumber: return theme.board.sameNumber
        case .barred: return theme.board.hair.opacity(0.45)
        case .rightHere: return palette.accent.opacity(0.28)
        case .wrongHere: return palette.danger.opacity(0.24)
        case .clueDestination: return Paper.coin.opacity(0.14)
        case .plain: return .clear
        }
    }

    /// A Given is printed; a number you placed is written; a Clue is written by
    /// someone else, so it sits lighter on the page.
    private var inkColor: Color {
        switch provenance {
        case .given: return BoardMaterial.ink
        case .clue: return BoardMaterial.ink.opacity(0.68)
        default: return BoardMaterial.ink.opacity(0.90)
        }
    }

    private var placementTransition: AnyTransition {
        switch theme.numbers.motion {
        case .press: return .scale(scale: 0.72).combined(with: .opacity)
        case .typewriter: return .scale(scale: 1.14).combined(with: .opacity)
        case .pencil: return .opacity.combined(with: .scale(scale: 0.90, anchor: .leading))
        case .stencil: return .opacity.combined(with: .scale(scale: 1.05))
        case .neon: return .scale(scale: 0.60).combined(with: .opacity)
        case .handset: return .scale(scale: 0.78).combined(with: .opacity)
        case .laser: return .scale(scale: 0.68).combined(with: .opacity)
        case .flame: return .scale(scale: 0.66, anchor: .bottom).combined(with: .opacity)
        }
    }

}
