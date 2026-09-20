import SwiftUI
import ProbablySudokuEngine

/// All briefing elements share a single viewport budget. The board uses the
/// remaining square; neither a long rule nor a new receipt can move the actions.
struct PuzzleBriefingLayout {
    let available: CGSize
    static let routeMaximumWidth: CGFloat = 560

    var contentSize: CGSize {
        CGSize(width: min(available.width, 560), height: min(available.height, 840))
    }
    var compact: Bool { contentSize.height < 600 }
    var spacing: CGFloat { 6 }
    var headerHeight: CGFloat { compact ? 56 : 64 }
    var routeHeight: CGFloat { compact ? 76 : 80 }
    var targetHeight: CGFloat { compact ? 42 : 48 }
    var decisionHeight: CGFloat { compact ? 100 : 104 }
    var actionHeight: CGFloat { 52 }
    var boardSide: CGFloat {
        max(0, min(contentSize.width - 8, contentSize.height - headerHeight - routeHeight
                   - targetHeight - decisionHeight - actionHeight - spacing * 5))
    }
}

/// A reading layout spends its space on the complete decision before the
/// decorative preview. Short viewports still get enlarged, readable text;
/// taller ones can honor more of the user's requested scale.
struct BriefingReadingStyle {
    let available: CGSize
    let scale: CGFloat
    private var tight: Bool { available.height < 500 }
    var context: CGFloat { min(13 * scale, tight ? 18 : 23) }
    var target: CGFloat { min(20 * scale, tight ? 24 : 31) }
    var name: CGFloat { min(21 * scale, tight ? 32 : 42) }
    var effect: CGFloat { min(13 * scale, tight ? 22 : 28) }
    var caption: CGFloat { min(10 * scale, tight ? 15 : 18) }
    var action: CGFloat { min(22 * scale, tight ? 28 : 35) }
    var upcomingBossName: CGFloat { min(14 * scale, 19) }
    var upcomingBossEffect: CGFloat { min(13 * scale, 18) }
}

private struct BriefingReadingLayout: Layout {
    let spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 4 else { return proposal.replacingUnspecifiedDimensions() }
        let width = proposal.width ?? 320
        let column = ProposedViewSize(width: width, height: nil)
        let textHeight = [0, 2, 3].reduce(CGFloat.zero) { $0 + subviews[$1].sizeThatFits(column).height }
        return CGSize(width: width, height: proposal.height ?? textHeight + width + spacing * 3)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 4 else { return }
        let column = ProposedViewSize(width: bounds.width, height: nil)
        let header = subviews[0].sizeThatFits(column).height
        let decision = subviews[2].sizeThatFits(column).height
        let actions = subviews[3].sizeThatFits(column).height
        let remaining = max(0, bounds.height - header - decision - actions - spacing * 3)
        let side = max(0, min(bounds.width - 8, remaining))
        subviews[0].place(at: bounds.origin, proposal: column)
        subviews[1].place(at: CGPoint(x: bounds.midX - side / 2,
            y: bounds.minY + header + spacing + (remaining - side) / 2),
            proposal: ProposedViewSize(width: side, height: side))
        subviews[2].place(at: CGPoint(x: bounds.minX, y: bounds.maxY - actions - spacing - decision), proposal: column)
        subviews[3].place(at: CGPoint(x: bounds.minX, y: bounds.maxY - actions), proposal: column)
    }
}

/// The real next board and one explicit decision, fitted to a single page.
struct PuzzleBriefingView: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var readingScale: CGFloat = 1
    @Environment(PageFlipper.self) private var flipper
    @Bindable var model: GameModel
    var canStartPresentation: @MainActor () -> Bool = { true }
    var isPresentationCovered = false
    @State private var isStartingPuzzle = false
    @State private var isAwaitingPreparation = false
    @State private var playTask: Task<Void, Never>?
    @State private var playRequestID: UUID?
    @State private var skipClaim: GameModel.SkipClaim?
    @State private var clippingTask: Task<Void, Never>?
    @State private var clippingRequestID: UUID?
    @State private var replacementClaim: GameModel.SkipClaim?
    private struct BuffInspection: Identifiable {
        let buff: ItemDef
        var id: String { buff.id }
    }
    @State private var inspectedSkipBuff: BuffInspection?

    var body: some View {
        // The page owns its bounds. An encounter's artwork must fit that
        // proposal instead of making the Book grow into the desk's HUD.
        GeometryReader { proxy in
            let layout = PuzzleBriefingLayout(available: proxy.size)
            Group {
                if dynamicTypeSize > .large {
                    readingContent(layout: layout)
                } else {
                    briefingContent(layout: layout)
                }
            }
                .frame(width: layout.contentSize.width, height: layout.contentSize.height, alignment: .top)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .task(id: preparationLifetime) {
            guard scenePhase == .active else {
                model.cancelPuzzlePreparation()
                return
            }
            _ = await model.prepareUpcomingPuzzle()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                cancelPendingPlay()
                cancelClippingTake()
                model.cancelPuzzlePreparation()
            }
        }
        .onChange(of: isPresentationCovered) { _, covered in
            if covered {
                cancelPendingPlay()
                // Its own replacement panel covers the briefing too. Retain
                // that decision; unrelated coverage cancels pending tear-offs.
                if replacementClaim == nil { cancelClippingTake() }
            }
        }
        .onChange(of: flipper.isFlipping) { _, flipping in
            if flipping { cancelClippingTake() }
        }
        .paperPanel(item: $inspectedSkipBuff) { inspection in
            let buff = inspection.buff
            PaperSlip(title: buff.name, maximumWidth: 460, fitsContent: true,
                      onClose: { inspectedSkipBuff = nil }) {
                ItemDetailCard(def: buff, showsHeading: false)
            }
        }
        .paperPanel(item: $replacementClaim) { claim in
            SkipBuffReplacementSlip(offer: claim.offer.buff, buffs: model.run.buffs) { buffID in
                guard scenePhase == .active, replacementClaim == claim,
                      model.currentSkipClaim == claim, !flipper.isFlipping else { return }
                _ = model.takeSkip(ifCurrent: claim, replacingBuffID: buffID)
                replacementClaim = nil
            }
        }
        .onChange(of: model.currentSkipClaim) { _, claim in
            if let replacementClaim, replacementClaim != claim {
                self.replacementClaim = nil
            }
        }
        .onDisappear {
            model.cancelPuzzlePreparation()
            cancelClippingTake()
            // A committed flip owns its remaining animation independently of
            // the disappearing briefing. Other navigation cancels a cold wait.
            if model.page != .puzzle || !flipper.isFlipping { cancelPendingPlay() }
        }
    }

    private func briefingContent(layout: PuzzleBriefingLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.spacing) {
            briefingHeader(compact: layout.compact)
                .frame(height: layout.headerHeight)
            RunRouteStrip(currentSlot: model.run.slot, boss: upcomingBoss,
                          isMotionActive: !isPresentationCovered && !flipper.isFlipping)
                .frame(height: layout.routeHeight)
            targetAndTurns(compact: layout.compact)
                .frame(height: layout.targetHeight)
            upcomingBoard
                .frame(width: layout.boardSide, height: layout.boardSide)
                .frame(maxWidth: .infinity)
            decisionArea(compact: layout.compact)
                .frame(height: layout.decisionHeight)
            briefingActions()
                .frame(height: layout.actionHeight)
                .inventorySaleActionArea()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier("briefing.singlePage")
    }

    private func readingContent(layout: PuzzleBriefingLayout) -> some View {
        let style = BriefingReadingStyle(available: layout.contentSize, scale: readingScale)
        return BriefingReadingLayout {
            readingHeader(style: style)
            upcomingBoard.clipped()
            decisionArea(compact: layout.compact, readingStyle: style)
            briefingActions(readingSize: style.action)
                .inventorySaleActionArea()
        }
        .accessibilityIdentifier("briefing.singlePage")
    }

    private func readingHeader(style: BriefingReadingStyle) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Chapter \(model.run.level) · \(RunRouteStrip.title(for: model.run.slot))")
                .font(.system(size: style.context, weight: .semibold, design: .serif))
                .foregroundStyle(GameplaySurface.softInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Next puzzle. Chapter \(model.run.level). \(RunRouteStrip.title(for: model.run.slot)).")
                .accessibilityAddTraits(.isHeader)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    readingTarget(style: style)
                    Spacer(minLength: 0)
                    readingTurns(style: style)
                }
                VStack(alignment: .leading, spacing: 2) {
                    readingTarget(style: style)
                    readingTurns(style: style)
                }
            }
            // The ordinary-puzzle route announces this same committed boss.
            // A larger reading layout must preserve that planning information
            // even when the three visual route stops no longer fit.
            if model.run.slot != .boss, let boss = upcomingBoss {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Chapter boss: \(boss.name)")
                        .font(.system(size: style.upcomingBossName, weight: .semibold, design: .serif))
                    Text(boss.text)
                        .font(.system(size: style.upcomingBossEffect, design: .serif))
                        .foregroundStyle(GameplaySurface.softInk)
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("briefing.announced-boss")
            }
            Rectangle().fill(theme.paper.ruleInk).frame(height: 1)
        }
        .foregroundStyle(GameplaySurface.ink)
        .accessibilityElement(children: .contain)
    }

    private func readingTarget(style: BriefingReadingStyle) -> some View {
        Text("Target \(previewTarget.formatted())")
            .font(.system(size: style.target, weight: .semibold, design: .serif))
            .fixedSize()
    }

    private var previewTarget: Int {
        model.preparedPuzzlePreview?.target ?? BossEncounterRules.startingTarget(
            base: model.run.target, boss: model.run.slot == .boss ? upcomingBoss : nil)
    }

    private func readingTurns(style: BriefingReadingStyle) -> some View {
        Text("\(model.preparedPuzzlePreview?.turnsMax ?? model.run.effectiveTurns(boss: model.run.slot == .boss ? upcomingBoss : nil)) turns")
            .font(.system(size: style.context, design: .serif))
            .fixedSize()
    }

    private func targetAndTurns(compact: Bool) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Target")
                    .font(Print.caption(compact ? 9 : 10)).tracking(1.5).textCase(.uppercase)
                    .foregroundStyle(GameplaySurface.softInk)
                Text(previewTarget.formatted())
                    .font(.system(size: compact ? 30 : 36, weight: .semibold, design: .serif))
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().fill(theme.paper.ruleInk).frame(width: 1)
                .padding(.vertical, 4)
            Label("\(model.preparedPuzzlePreview?.turnsMax ?? model.run.effectiveTurns(boss: model.run.slot == .boss ? upcomingBoss : nil)) turns",
                  systemImage: "clock")
                .font(.system(size: compact ? 17 : 20, weight: .medium, design: .serif))
                .lineLimit(1).minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 8)
        .foregroundStyle(GameplaySurface.ink)
        .accessibilityElement(children: .combine)
    }

    private var upcomingBoard: some View {
        ZStack {
            if let puzzle = model.preparedPuzzlePreview {
                GameplayBoardSnapshot(board: puzzle.board, markers: model.run.markedSquares, puzzle: puzzle)
                    .accessibilityLabel("Upcoming Puzzle board. Read only.")
                    .accessibilityIdentifier("briefing.upcomingBoard")
                    .transition(.opacity)
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(GameplaySurface.ivory)
                    .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(GameplaySurface.frame, lineWidth: 5) }
                Text("Preparing puzzle…")
                    .font(.system(size: 16, design: .serif))
                    .foregroundStyle(GameplaySurface.softInk)
                    .accessibilityIdentifier("briefing.preparingBoard")
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: model.hasPreparedPuzzle)
    }

    @ViewBuilder
    private func decisionArea(compact: Bool, readingStyle: BriefingReadingStyle? = nil) -> some View {
        if let offer = model.run.currentSkipOffer {
            Button { inspectedSkipBuff = BuffInspection(buff: offer.buff) } label: {
                BriefingRewardSlip(buff: offer.buff, compact: compact, readingStyle: readingStyle)
            }
                .buttonStyle(.plain)
                .accessibilityHint("Read the complete Buff effect")
                .id(offer.id)
                .scaleEffect(skipClaim != nil && !reduceMotion ? 0.97 : 1)
                .offset(y: skipClaim != nil && !reduceMotion ? -8 : 0)
                .opacity(skipClaim != nil ? 0 : 1)
                .animation(.easeOut(duration: reduceMotion ? 0.1 : 0.24), value: skipClaim != nil)
        } else if let boss = upcomingBoss, model.run.slot == .boss {
            BriefingBossSlip(boss: boss, compact: compact, readingStyle: readingStyle)
        }
    }

    private func briefingActions(readingSize: CGFloat? = nil) -> some View {
        let layout = readingSize == nil ? AnyLayout(HStackLayout(spacing: 10)) : AnyLayout(VStackLayout(spacing: 6))
        return layout {
            if let offer = model.run.currentSkipOffer {
                BriefingActionButton(title: "Skip + Buff", isPrimary: false,
                                     isEnabled: !isStartingPuzzle && skipClaim == nil && replacementClaim == nil,
                                     readingSize: readingSize,
                                     action: takeClipping)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Skip for \(offer.buff.name). \(offer.buff.text)")
                    .accessibilityHint("Skips this ordinary Puzzle and adds one consumable Buff. If your Buff slots are full, choose one to replace or cancel.")
                    .accessibilityIdentifier("briefing.skipBuff")
            }
            BriefingActionButton(title: isAwaitingPreparation ? "Preparing…" : (readingSize == nil ? "Play puzzle →" : "Play puzzle"),
                                 isPrimary: true,
                                 isEnabled: !isStartingPuzzle && skipClaim == nil && replacementClaim == nil,
                                 readingSize: readingSize,
                                 action: startPreparedPuzzle)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("briefing.playPuzzle")
        }
    }

    private var preparationLifetime: String {
        "\(model.puzzlePreparationRevision)-\(scenePhase == .active)"
    }

    private func startPreparedPuzzle() {
        guard !isStartingPuzzle, skipClaim == nil, replacementClaim == nil, scenePhase == .active, !flipper.isFlipping,
              canStartPresentation() else { return }
        let requestID = UUID()
        playRequestID = requestID
        isStartingPuzzle = true
        isAwaitingPreparation = !model.hasPreparedPuzzle
        playTask = Task { @MainActor in
            defer {
                if playRequestID == requestID {
                    isStartingPuzzle = false
                    isAwaitingPreparation = false
                    playTask = nil
                    playRequestID = nil
                }
            }
            guard let prepared = await model.prepareUpcomingPuzzle(reportFailure: true),
                  !Task.isCancelled, playRequestID == requestID,
                  canStartPresentation(), model.page == .briefing else { return }
            isAwaitingPreparation = false
            await flipper.flip(from: model, reduceMotion: reduceMotion) {
                guard playRequestID == requestID, canStartPresentation() else { return }
                model.beginPreparedPuzzle(prepared)
            }
        }
    }

    private func cancelPendingPlay() {
        playRequestID = nil
        playTask?.cancel()
        playTask = nil
        isStartingPuzzle = false
        isAwaitingPreparation = false
    }

    private func takeClipping() {
        guard !isStartingPuzzle, skipClaim == nil, replacementClaim == nil, scenePhase == .active,
              !flipper.isFlipping, canStartPresentation(),
              let claim = model.currentSkipClaim else { return }
        if model.run.buffs.count >= model.buffCapacity {
            replacementClaim = claim
            return
        }
        skipClaim = claim
        let requestID = UUID()
        clippingRequestID = requestID
        Haptics.pageTurn()
        clippingTask = Task { @MainActor in
            defer {
                if clippingRequestID == requestID {
                    clippingRequestID = nil
                    skipClaim = nil
                    clippingTask = nil
                }
            }
            do {
                try await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 280))
            } catch { return }
            guard !Task.isCancelled, clippingRequestID == requestID,
                  skipClaim == claim, scenePhase == .active,
                  !isPresentationCovered, !flipper.isFlipping, canStartPresentation() else { return }
            // The reward and route advance are one engine mutation. The
            // hanging paper is only presentation and can never pay twice.
            _ = model.takeSkip(ifCurrent: claim)
        }
    }

    private func cancelClippingTake() {
        replacementClaim = nil
        clippingTask?.cancel()
        clippingTask = nil
        clippingRequestID = nil
        skipClaim = nil
    }

    private func briefingHeader(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Next puzzle")
                .font(.system(size: compact ? 31 : 38, weight: .bold, design: .serif))
                .foregroundStyle(GameplaySurface.ink)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("Chapter \(model.run.level)")
                    .font(Print.caption(10)).tracking(2).textCase(.uppercase)
                    .foregroundStyle(GameplaySurface.softInk)
                Spacer(minLength: 4)
                if let buff = model.lastSkipReward {
                    SkipBuffReceipt(buff: buff)
                        .transition(.opacity)
                }
            }
            Rectangle().fill(theme.paper.ruleInk).frame(height: 1)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: model.lastSkipReward?.id)
    }

    /// The engine commits the Boss when this briefing is entered. The UI only
    /// reads that stored decision; it never rolls a second candidate.
    private var upcomingBoss: BossModifier? {
        model.run.pendingBoss
    }
}

/// Compact paper labels share the game's inventory materials, rather than
/// introducing a second card style between play and the next deal.
struct BriefingRewardSlip: View {
    @Environment(\.cosmeticTheme) private var theme
    let buff: ItemDef
    var compact = false
    var readingStyle: BriefingReadingStyle? = nil

    var body: some View {
        HStack(spacing: compact ? 10 : 14) {
            if readingStyle == nil {
                BriefingBuffTile(buff: buff)
                    .frame(width: compact ? 45 : 52, height: compact ? 50 : 58)
                Rectangle().strokeBorder(theme.paper.ruleInk,
                    style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .frame(width: 1)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Skip reward")
                    .font(Print.caption(readingStyle?.caption ?? 9)).tracking(1.3).textCase(.uppercase)
                    .foregroundStyle(GameplaySurface.softInk)
                Text(buff.name)
                    .font(.system(size: readingStyle?.name ?? (compact ? 20 : 23), weight: .semibold, design: .serif))
                    .lineLimit(readingStyle == nil ? 1 : nil)
                    .minimumScaleFactor(readingStyle == nil ? 0.8 : 1)
                    .fixedSize(horizontal: false, vertical: readingStyle != nil)
                Text(CatalogueDetails.item(buff.id)?.shortEffect ?? buff.text)
                    .font(.system(size: readingStyle?.effect ?? (compact ? 12 : 13), design: .serif))
                    .foregroundStyle(GameplaySurface.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, compact ? 12 : 14)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: readingStyle == nil ? .infinity : nil)
        .background {
            ClippingPaperEdge().fill(theme.paper.warm)
                .overlay { BriefingPaperTexture(opacity: 0.18).clipShape(ClippingPaperEdge()) }
                .shadow(color: .black.opacity(0.09), radius: 2, y: 2)
        }
        .foregroundStyle(GameplaySurface.ink)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Skip reward: \(buff.name). \(buff.text)")
        .accessibilityIdentifier("briefing.skipBuffOffer")
    }
}

private struct BriefingBuffTile: View {
    let buff: ItemDef

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(GameplaySurface.ink)
            .overlay(alignment: .top) {
                UnevenRoundedRectangle(topLeadingRadius: 5, topTrailingRadius: 5)
                    .fill(Paper.coinRim).frame(height: 5)
            }
            .overlay {
                ItemArtwork(id: buff.id, size: 38, style: .glyph)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(GameplaySurface.ivory)
            }
            .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.12), lineWidth: 1) }
            .shadow(color: .black.opacity(0.2), radius: 2, y: 3)
            .accessibilityHidden(true)
    }
}

private struct BriefingBossSlip: View {
    var boss: BossModifier
    var compact: Bool
    var readingStyle: BriefingReadingStyle? = nil

    var body: some View {
        HStack(spacing: 12) {
            if readingStyle == nil {
                BossSignatureBadge(boss: boss, isActive: false, side: compact ? 34 : 40)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(boss.name)
                    .font(.system(size: readingStyle?.name ?? (compact ? 15 : 17), weight: .semibold, design: .serif))
                    .foregroundStyle(GameplaySurface.ink)
                    .lineLimit(readingStyle == nil ? 1 : nil)
                    .minimumScaleFactor(readingStyle == nil ? 0.85 : 1)
                    .fixedSize(horizontal: false, vertical: readingStyle != nil)
                Text(boss.text)
                    .font(.system(size: readingStyle?.effect ?? (compact ? 12 : 13), design: .serif))
                    .foregroundStyle(GameplaySurface.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Boss Puzzles must be played.")
                    .font(.system(size: readingStyle?.caption ?? 11, design: .serif).italic())
                    .foregroundStyle(GameplaySurface.softInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12).padding(.vertical, 7)
        .frame(maxWidth: .infinity, maxHeight: readingStyle == nil ? .infinity : nil, alignment: .leading)
        .background(GameplaySurface.ivory.opacity(0.5), in: RoundedRectangle(cornerRadius: 4))
        .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(GameplaySurface.softInk.opacity(0.25), lineWidth: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Boss encounter: \(boss.name). \(boss.text). Boss Puzzles must be played.")
    }
}

private struct BriefingActionButton: View {
    var title: String
    var isPrimary: Bool
    var isEnabled: Bool
    var readingSize: CGFloat? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: readingSize ?? (isPrimary ? 22 : 19), weight: .semibold, design: .serif))
                .lineLimit(readingSize == nil ? 1 : nil)
                .minimumScaleFactor(readingSize == nil ? 0.75 : 1)
                .fixedSize(horizontal: false, vertical: readingSize != nil)
                .foregroundStyle(isPrimary ? GameplaySurface.ivory : GameplaySurface.ink)
                .padding(.vertical, readingSize == nil ? 0 : 7)
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: readingSize == nil ? .infinity : nil)
                .padding(.horizontal, 8)
                .background(isPrimary ? GameplaySurface.sage : GameplaySurface.ivory, in: RoundedRectangle(cornerRadius: 5))
                .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(GameplaySurface.sage, lineWidth: 1.2) }
        }
        .buttonStyle(PressedPaperStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.55)
    }
}

/// Receiving a reward changes the chapter line, never the board or footer.
private struct SkipBuffReceipt: View {
    var buff: ItemDef

    var body: some View {
        Text("Buff added: \(buff.name)")
            .font(Print.body(10))
            .lineLimit(1).minimumScaleFactor(0.75)
            .foregroundStyle(GameplaySurface.sage)
            .accessibilityLabel("Buff added: \(buff.name). \(buff.text)")
    }
}

/// Choosing a slot is the acceptance step. Opening or dismissing this slip
/// leaves the puzzle and all owned copies untouched.
struct SkipBuffReplacementSlip: View {
    @Environment(\.paperPanelDismiss) private var dismiss
    @Environment(\.cosmeticTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1
    let offer: ItemDef
    let buffs: [OwnedBuff]
    let onReplace: (UUID) -> Void
    @State private var didChoose = false

    var body: some View {
        PaperSlip(title: "Choose a Buff", subtitle: "Skip for \(offer.name)",
                  closeLabel: "Cancel", dismissesOnBackground: false,
                  closeAccessibilityID: "skip.cancelReplacement", maximumWidth: 420,
                  onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: 16) {
                Text(offer.text)
                    .font(Print.body(14 * textScale))
                    .foregroundStyle(theme.paper.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Your Buff slots are full. Choose a Buff to replace and skip this Puzzle, or cancel to keep everything.")
                    .font(Print.body(13 * textScale))
                    .foregroundStyle(theme.paper.softInk)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(buffs) { buff in
                    Button {
                        guard !didChoose else { return }
                        didChoose = true
                        onReplace(buff.id)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Replace \(buff.def.name)")
                                .font(Print.subheading(17 * textScale))
                                .foregroundStyle(theme.paper.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Slot \(slot(of: buff)) · \(buff.def.text)")
                                .font(Print.body(12 * textScale))
                                .foregroundStyle(theme.paper.softInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(theme.paper.warm, in: RoundedRectangle(cornerRadius: 4))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(theme.paper.ruleInk, lineWidth: 1)
                        }
                    }
                    .buttonStyle(PressedPaperStyle())
                    .disabled(didChoose)
                    .accessibilityLabel("Replace \(buff.def.name) in slot \(slot(of: buff))")
                    .accessibilityHint("Removes this copy, adds \(offer.name), and skips one Puzzle.")
                    .accessibilityIdentifier("skip.replace.\(slot(of: buff))")
                }
            }
        }
    }

    private func slot(of buff: OwnedBuff) -> Int {
        (buffs.firstIndex(where: { $0.id == buff.id }) ?? 0) + 1
    }
}

// MARK: - Route

struct RunRouteStrip: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.gameReduceMotion) private var reduceMotion
    var currentSlot: PuzzleSlot
    var boss: BossModifier?
    var isMotionActive = true

    static func height(for width: CGFloat) -> CGFloat { 80 }

    static func title(for slot: PuzzleSlot) -> String {
        switch slot {
        case .easy: "Easy"
        case .medium: "Easy but hard"
        case .boss: "Boss"
        }
    }

    var accessibilitySummary: String {
        let route = "Chapter route: Easy, Easy but hard, then Boss. Current stop: \(Self.title(for: currentSlot))."
        guard let boss else { return "\(route) Adversary not yet known." }
        return "\(route) \(boss.name). Power: \(boss.text)."
    }

    var body: some View {
        GeometryReader { proxy in
            let diameter: CGFloat = proxy.size.height < 80 ? 28 : 32
            ZStack(alignment: .top) {
                HStack(spacing: 0) {
                    Rectangle().fill(theme.paper.ruleInk)
                    Rectangle().fill(theme.paper.ruleInk)
                }
                .frame(height: 1)
                .padding(.horizontal, proxy.size.width / 6)
                .offset(y: diameter / 2)
                HStack(alignment: .top, spacing: 4) {
                    ForEach(PuzzleSlot.allCases, id: \.self) { slot in
                        routeStop(slot, diameter: diameter, width: (proxy.size.width - 8) / 3)
                    }
                }
            }
        }
        .frame(maxWidth: PuzzleBriefingLayout.routeMaximumWidth)
        .frame(idealHeight: Self.height(for: PuzzleBriefingLayout.routeMaximumWidth))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
        .animation(reduceMotion || !isMotionActive ? nil : .easeInOut(duration: 0.22), value: currentSlot)
    }

    private func routeStop(_ slot: PuzzleSlot, diameter: CGFloat, width: CGFloat) -> some View {
        VStack(spacing: 3) {
            Text("\(slot.rawValue + 1)")
                .font(.system(size: diameter * 0.62, weight: .semibold, design: .serif))
                .foregroundStyle(slot == currentSlot ? GameplaySurface.ivory : GameplaySurface.ink)
                .frame(width: diameter, height: diameter)
                .background(slot == currentSlot ? GameplaySurface.sage : GameplaySurface.ivory, in: Circle())
                .overlay { Circle().strokeBorder(slot == currentSlot ? GameplaySurface.sage : theme.paper.ruleInk, lineWidth: 1) }
                .overlay(alignment: .trailing) {
                    if slot == .boss {
                        Text("BOSS")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(GameplaySurface.ink)
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(Paper.coin.opacity(0.55), in: .rect(cornerRadius: 3))
                            .fixedSize()
                            .offset(x: 34)
                    }
                }
            Text(slot == .boss ? boss?.name ?? "Boss" : Self.title(for: slot))
                .font(.system(size: 12, weight: slot == currentSlot ? .bold : .regular, design: .serif))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: width)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 30, alignment: .top)
            if slot == .boss {
                Text(boss?.briefPower ?? "Mandatory")
                    .font(Print.body(10))
                    .foregroundStyle(Paper.redPencil)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .frame(width: width)
    }
}

/// Reuses the book's paper fibres at a restrained strength. The texture is
/// sized by its parent, so it never contributes an intrinsic image size.
private struct BriefingPaperTexture: View {
    var opacity: Double

    var body: some View {
        GeometryReader { proxy in
            Image("BetweenPuzzlesPaper")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .opacity(opacity)
        .blendMode(.multiply)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ClippingPaperEdge: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 1.5))
        let teeth = max(1, Int(rect.width / 5))
        let pitch = rect.width / CGFloat(teeth)
        for tooth in 0..<teeth {
            let x = rect.maxX - CGFloat(tooth) * pitch
            path.addQuadCurve(
                to: CGPoint(x: x - pitch, y: rect.maxY - 1.5),
                control: CGPoint(x: x - pitch * 0.5, y: rect.maxY - (tooth.isMultiple(of: 3) ? 3 : 2))
            )
        }
        path.closeSubpath()
        return path
    }
}

private extension BossModifier {
    var briefPower: String {
        switch self {
        case .censor: "One digit scores 0"
        case .editor: "Hand size −1"
        case .deadline: "8 turns"
        case .fog: "Markers hidden"
        case .critic: "Wrong penalty ×2"
        case .mirror: "Lines score 0"
        case .paywall: "Clues disabled"
        case .erratum: "No tosses"
        case .collector: "No interest"
        case .heavyLifter: "Target ×4"
        case .unluckyLucky: "Triggered Bookmark sleeps"
        case .buffborger: "Buffs disabled"
        case .sashimi: "Multipliers halved"
        case .overPusher: "Squares foul"
        case .accountant: "1 coin per placement"
        case .tikTak: "4 minute clock"
        case .handyDandy: "Up to 2 cards barred"
        case .grayTheGarry: "A row locked"
        case .garryTheGray: "A box locked"
        case .galleyQueue: "Play the oldest pair"
        case .bookends: "Play low or high"
        case .reprintBan: "Repeated numbers wait"
        case .rebinder: "Leftovers return to Pool"
        case .lateCourier: "Bonus draws wait for bank"
        case .collator: "Second packet waits"
        case .pageCutter: "Bank every 4 fills"
        case .chainStitcher: "Link fills or halve Points"
        case .returnSlip: "Wrong cards return sealed"
        case .orphanLine: "Leftovers cost Points"
        case .serialPublisher: "Banks capped; excess carries"
        case .bindery: "Bookmark order alternates"
        case .embargo: "Prepare before placing"
        case .dryPress: "Plain fills re-ink Markers"
        case .reviewBoard: "Clear a row, column and box"
        case .rivalColumn: "Beat the previous bank"
        case .royaltyContract: "Buffs raise the target"
        case .publicist: "One flat bonus per Bookmark"
        case .wordCount: "150 extra Points per Turn"
        case .backPage: "Number values reversed"
        case .collateral: "Pledge a tile for extra Mult"
        case .splitEdition: "Print both editions"
        case .lastEdition: "One bank. Make it count."
        }
    }

}
