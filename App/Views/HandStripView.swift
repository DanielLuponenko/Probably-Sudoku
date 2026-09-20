import SwiftUI
import ProbablySudokuEngine

/// The Hand is a row of separate ivory tiles. Its UUID order belongs to the
/// presentation; every action still resolves the canonical Engine index.
struct HandStripView: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.levelPalette) private var palette
    @Environment(\.handArrangementPresenter) private var arrangementPresenter
    @State private var arrangementOwner = UUID()
    @State private var arrangementAnchor = CGRect.zero
    @State private var overflowEdges = HandOverflowEdges()
    @Namespace private var handScrollSpace
    @Bindable var model: GameModel
    var handSize: Int
    var tileHeight: CGFloat = 54

    private var tileWidth: CGFloat { max(44, min(50, tileHeight * 0.92)) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                if model.puzzle?.boss == .editor, model.clueHandInstruction == nil,
                   !model.isReadingLitmus {
                    BossEditorFold(handSize: handSize)
                        .modifier(BossObjectArrival(eventKey: model.bossEntranceID.map { "editor:\($0)" },
                                                    consume: model.consumeBossVisualEvent))
                } else {
                Text(model.clueHandInstruction ?? (model.isReadingLitmus
                     ? "Litmus: choose a number" : model.firstRunGuidance ?? ""))
                    .font(Print.caption(12))
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(GameplaySurface.ink)
                }
                Spacer(minLength: 0)
                arrangementControls
            }
            .frame(height: 44)

            GeometryReader { proxy in
                // Keep a slim rail outside the tiles only when the Hand is
                // wider than its viewport. The arrows stay visible after the
                // system scroll indicator fades, without covering a number.
                let contentWidth = CGFloat(model.displayedHandCards.count) * tileWidth
                    + CGFloat(max(0, model.displayedHandCards.count - 1)) * 7 + 4
                let rail: CGFloat = contentWidth > proxy.size.width ? 10 : 0
                let viewportWidth = max(0, proxy.size.width - rail * 2)
                ScrollViewReader { scroll in
                    ScrollView(.horizontal) {
                        HStack(spacing: 7) {
                            ForEach(model.displayedHandCards) { card in
                                handButton(for: card)
                                    .id(card.id)
                            }
                        }
                        .padding(.horizontal, 2)
                        .frame(minWidth: viewportWidth, alignment: .center)
                        .padding(.top, 2)
                        .padding(.bottom, 6)
                        .onGeometryChange(for: HandOverflowEdges.self) { geometry in
                            HandOverflowEdges(content: geometry.frame(in: .named(handScrollSpace)),
                                              viewportWidth: viewportWidth)
                        } action: { overflowEdges = $0 }
                    }
                    .coordinateSpace(name: handScrollSpace)
                    .scrollIndicators(.visible, axes: .horizontal)
                    .padding(.horizontal, rail)
                    .onChange(of: model.handPresentationOrder) { _, _ in
                        // Keep the selected duplicate reachable after a sort.
                        guard let index = model.selectedHandIndex,
                              model.handCards.indices.contains(index) else { return }
                        scroll.scrollTo(model.handCards[index].id, anchor: .center)
                    }
                    .overlay {
                        if rail > 0 {
                            HStack(spacing: 0) {
                                overflowArrow("chevron.left", visible: overflowEdges.leading)
                                Spacer(minLength: 0)
                                overflowArrow("chevron.right", visible: overflowEdges.trailing)
                            }
                            .frame(height: tileHeight)
                            .frame(maxHeight: .infinity, alignment: .top)
                            .padding(.top, 2)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                        }
                    }
                }
            }
            .frame(height: tileHeight + 8)
            .numberReturnMotionFrame(NumberReturnMotionAnchor.hand)
            .overlay(alignment: .trailing) {
                // Returned numbers fade into the edge of the hand. This is
                // geometry only, never a visible Pool label or extra spacing.
                Color.clear.frame(width: 1, height: 1)
                    .numberReturnMotionFrame(NumberReturnMotionAnchor.pool)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .cosmeticPulseClock(for: theme.numbers.finish)
        .onDisappear { arrangementPresenter?.dismiss(owner: arrangementOwner) }
    }

    private func overflowArrow(_ symbol: String, visible: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(GameplaySurface.sage)
            .frame(width: 10)
            .opacity(visible ? 1 : 0)
    }

    /// The three choices live beside their one toolbar button, without
    /// replacing the page or touching the active Hand/Clue selection.
    private var arrangementControls: some View {
        let isOpen = arrangementPresenter?.session?.owner == arrangementOwner
        return Button {
            arrangementPresenter?.toggle(owner: arrangementOwner, anchor: arrangementAnchor, model: model)
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isOpen ? GameplaySurface.sage : GameplaySurface.softInk)
                .frame(width: 36, height: 28)
                .background(isOpen ? GameplaySurface.sage.opacity(0.13) : .clear, in: Capsule())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!model.acceptsPuzzleInput)
        .accessibilityLabel("Arrange hand")
        .accessibilityValue(isOpen ? "Menu open" : arrangementDescription)
        .accessibilityHint("Show ascending, descending, and shuffle choices")
        .accessibilityIdentifier("hand-arrangement")
        .numberReturnMotionFrame("hand-arrangement-control")
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { arrangementAnchor = $0 }
    }

    private var arrangementDescription: String {
        switch model.handArrangement {
        case .dealt: "Dealt order"
        case .ascending: "Ascending"
        case .descending: "Descending"
        case .random: "Shuffled"
        }
    }

    private func handButton(for card: GameModel.HandCard) -> some View {
        let index = model.canonicalHandIndex(for: card.id)
        let isSelected = index != nil && model.selectedHandIndex == index
        let isBlocked = index.map { model.isBlocked(handIndex: $0) } ?? false
        let isTossBlocked = index.map { index in
            guard let p = model.puzzle else { return false }
            return p.isTossBlocked(handIndex: index) && !BuffRuntime.releaseAllows(handIndex: index, puzzle: p)
        } ?? false
        let bossTreatment = BossHandTreatment.resolve(index: index, puzzle: model.puzzle)
        return Button {
            model.tapHandCard(card.id)
        } label: {
            NumberTile(digit: card.digit, isSelected: isSelected, isBlocked: isBlocked,
                       arrivalOrder: card.arrivalOrder,
                       shouldAnimateArrival: model.animatesHandArrival,
                       width: tileWidth, height: tileHeight, theme: theme, palette: palette,
                       bossTreatment: bossTreatment,
                       bossEntranceKey: bossTreatment == .none ? nil : model.bossEntranceID.map { "hand-object:\($0):\(card.id)" },
                       consumeBossEntrance: model.consumeBossVisualEvent)
        }
        .buttonStyle(.plain)
        .numberReturnMotionFrame(NumberReturnMotionAnchor.card(card.id))
        .accessibilityLabel("Number \(card.digit.rawValue)"
            + (isBlocked ? ", \(index.flatMap { model.handRestrictionDescription($0) } ?? "blocked")" : ""))
        .accessibilityValue([isSelected ? "Selected" : nil, bossTreatment.accessibilityStatus]
            .compactMap { $0 }.joined(separator: ", "))
        .accessibilityHint(isTossBlocked ? "Cannot be placed or tossed this turn"
            : isBlocked ? "Can still be tossed" : "Select this card to place it, toss it, or use a clue")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityIdentifier("hand-card-\(card.id.uuidString)")
    }
}

/// Only hidden content warrants an arrow; elastic overscroll at an end does
/// not imply that another card exists there.
struct HandOverflowEdges: Equatable {
    var leading = false
    var trailing = false

    init() {}

    init(content: CGRect, viewportWidth: CGFloat) {
        guard viewportWidth > 0, content.width > viewportWidth + 1 else { return }
        leading = content.minX < -1
        trailing = content.maxX > viewportWidth + 1
    }
}

private struct NumberTile: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.bossMotionIsActive) private var bossPresented
    @Environment(\.scenePhase) private var scenePhase
    var digit: Digit
    var isSelected: Bool
    var isBlocked: Bool
    var arrivalOrder: Int
    var shouldAnimateArrival: Bool
    var width: CGFloat
    var height: CGFloat
    var theme: CosmeticTheme
    var palette: LevelPalette
    var bossTreatment: BossHandTreatment = .none
    var bossEntranceKey: String? = nil
    var consumeBossEntrance: ((String) -> Bool)? = nil

    @State private var hasArrived = false

    var body: some View {
        CosmeticNumberGlyph(text: "\(digit.rawValue)", skin: theme.numbers,
                            size: min(29, height * 0.56), weight: .medium,
                            color: isBlocked && bossTreatment == .none ? GameplaySurface.softInk : GameplaySurface.ink,
                            intensity: isBlocked && bossTreatment == .none ? 0.54 : 1, showsPressShadow: false)
            .offset(y: bossTreatment == .none ? 0 : -min(6, height * 0.12))
            .frame(width: width, height: height)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(red: 0.72, green: 0.71, blue: 0.65))
                        .offset(y: 3)
                        .shadow(color: .black.opacity(0.13), radius: 2, x: 0, y: 3)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(LinearGradient(colors: bossTreatment.isWaiting
                                             ? [GameplaySurface.ivory, Color(red: 0.86, green: 0.83, blue: 0.75)]
                                             : [.white.opacity(0.95), GameplaySurface.ivory],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(.white.opacity(0.85), lineWidth: 1)
                        .padding(1)
                }
            }
            .overlay {
                if isBlocked && bossTreatment == .none {
                    Rectangle()
                        .fill(palette.danger.opacity(0.75))
                        .frame(width: width * 0.66, height: 1.8)
                        .rotationEffect(.degrees(-14))
                        .accessibilityHidden(true)
                }
            }
            .overlay {
                BossHandTreatmentView(treatment: bossTreatment)
                    .modifier(BossObjectArrival(eventKey: bossEntranceKey,
                                                consume: { consumeBossEntrance?($0) ?? false }))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(isBlocked ? palette.danger.opacity(0.65)
                        : (isSelected ? GameplaySurface.frame : GameplaySurface.sage.opacity(0.35)),
                                  lineWidth: isSelected ? 2 : 0.8)
            }
            .overlay {
                if isSelected {
                    // The selected card gets a separate outer ring. A boss's
                    // PLAY tray or brass bookend must never look selected by
                    // itself. This fits the existing 7-point card spacing
                    // and 2-point top allowance without changing hit targets.
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(GameplaySurface.ink.opacity(0.9), lineWidth: 1.3)
                        .padding(-2)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .scaleEffect(hasArrived || reduceMotion || !shouldAnimateArrival
                         ? 1 : theme.numbers.motion.arrivalScale)
            .offset(y: hasArrived || reduceMotion || !shouldAnimateArrival
                    ? 0 : theme.numbers.motion.arrivalOffset)
            .opacity(hasArrived || reduceMotion || !shouldAnimateArrival ? 1 : 0)
            .animation(!reduceMotion && bossPresented && scenePhase == .active
                       ? .easeOut(duration: 0.2) : nil, value: isBlocked)
            .animation(!reduceMotion && bossPresented && scenePhase == .active
                       ? .spring(response: 0.36, dampingFraction: 0.78) : nil, value: bossTreatment)
            .onAppear {
                guard !hasArrived else { return }
                guard shouldAnimateArrival && !reduceMotion else {
                    hasArrived = true
                    return
                }
                withAnimation(theme.numbers.motion.arrivalAnimation
                    .delay(Double(arrivalOrder) * 0.035)) {
                    hasArrived = true
                }
            }
            .onChange(of: reduceMotion) { _, isReduced in
                if isReduced { hasArrived = true }
            }
    }
}
