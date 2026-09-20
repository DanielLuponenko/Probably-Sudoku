import SwiftUI
import ProbablySudokuEngine

/// One inventory strip on every in-run screen. Lifts are rendered by the root
/// portal so neither the row nor a page capture clips freeform movement.
struct BookmarkRow: View {
    @Bindable var model: GameModel
    var isGameplay = false
    var onTapBuff: (Int) -> Void
    @Environment(\.inventoryDragPresenter) private var dragPresenter
    @Environment(\.paperPanelPresenter) private var paperPresenter
    @Environment(\.scenePhase) private var scenePhase
    @State private var owner = UUID()
    @State private var explaining: UUID?
    @State private var press = BookmarkPressState()
    @State private var holdTask: Task<Void, Never>?
    @State private var latestPoint = CGPoint.zero
    @State private var didLift = false
    @GestureState private var isTouching = false

    static let tuck: CGFloat = 16
    private var carried: InventoryDragSession? {
        dragPresenter?.session.flatMap { $0.owner == owner ? $0 : nil }
    }
    private var liftedSale: InventorySale? {
        carried?.sale ?? dragPresenter?.returning.flatMap { $0.owner == owner ? $0.sale : nil }
    }
    private var sourceBeat: ScorePerformance.Beat? {
        model.page == .puzzle && scenePhase == .active ? model.scoreBeat : nil
    }
    private var orderIsPinned: Bool {
        model.puzzle?.boss == .bindery && model.puzzle?.bossState.scoring.binderyPinned == true
    }

    var body: some View {
        GeometryReader { proxy in
            let strip = InventoryStripGeometry(frame: proxy.frame(in: .global),
                                               bookmarkCount: model.run.bookmarks.count, buffCapacity: model.buffCapacity)
            cards(strip: strip)
                .overlay(alignment: .topLeading) {
                    if orderIsPinned {
                        BossBinderyThread(centers: strip.bookmarkFrames.map { $0.midX - strip.frame.minX },
                            activeSlot: model.run.bookmarks.firstIndex { owned in
                                ScoringSourceHighlights.bookmarkBeatID(for: sourceBeat, bookmark: owned) != nil
                            },
                            beatID: sourceBeat?.id,
                            eventKey: model.bossEntranceID.map { "bindery-thread:\($0)" },
                            consumeEvent: model.consumeBossVisualEvent)
                            .frame(height: isGameplay ? 44 : 34 + Self.tuck)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if let beat = sourceBeat,
                       let slot = ScoringSourceHighlights.consumedBuffSlot(for: beat, buffs: model.run.buffs, capacity: model.buffCapacity) {
                        let frame = strip.itemFrame(kind: .buff, index: slot)
                        // The item has already been consumed. Mark its physical
                        // slot briefly without recreating a card or a tap target.
                        ScoringSourceOutline(trigger: beat.id.uuidString, cornerRadius: 6)
                            .frame(width: frame.width, height: frame.height)
                            .offset(x: frame.minX - strip.frame.minX, y: 0)
                    }
                }
        }
        .frame(height: isGameplay ? 44 : 34 + Self.tuck)
        .onDisappear { cancelInteraction() }
        .onChange(of: isTouching) { _, touching in
            // onEnded already consumed this touch. Do not interrupt the
            // presentation-only flight home after an outside release.
            if !touching, press.activeItemKey != nil { cancelInteraction() }
        }
        .onChange(of: scenePhase) { _, phase in if phase != .active { cancelInteraction() } }
        .onChange(of: paperPresenter?.isPresenting) { _, showing in if showing == true { cancelInteraction() } }
        .onChange(of: model.page) { _, _ in cancelInteraction() }
        .onChange(of: model.run.seed) { _, _ in cancelInteraction() }
        .onChange(of: model.puzzle?.turnNumber) { _, _ in cancelInteraction() }
        .onChange(of: model.run.bookmarks.map(\.id) + model.run.buffs.map(\.id)) { _, _ in cancelInteraction() }
    }

    private func handle(sale: InventorySale, strip: InventoryStripGeometry,
                        tap: @escaping (Int) -> Void) -> some Gesture {
        let token = (sale.kind == .buff ? 100 : 0) + sale.index
        return DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($isTouching) { _, touching, _ in touching = true }
            .onChanged { value in
                guard model.animatesHandArrival, scenePhase == .active,
                      paperPresenter?.isPresenting != true else { return }
                latestPoint = value.location
                if let generation = press.begin(itemKey: token) {
                    didLift = false
                    holdTask?.cancel()
                    holdTask = Task { @MainActor in
                        do { try await Task.sleep(for: .milliseconds(220)) } catch { return }
                        guard !Task.isCancelled,
                              press.isCurrent(itemKey: token, generation: generation) else { return }
                        lift(sale: sale, strip: strip, start: value.startLocation)
                    }
                }
                if carried == nil, !didLift,
                   hypot(value.translation.width, value.translation.height) >= 6 {
                    lift(sale: sale, strip: strip, start: value.startLocation)
                }
                dragPresenter?.move(owner: owner, to: value.location)
            }
            .onEnded { value in
                let active = press.activeItemKey == token
                let wasLifted = didLift
                cancelHold()
                guard active, scenePhase == .active, paperPresenter?.isPresenting != true else {
                    dragPresenter?.cancel(owner: owner)
                    return
                }
                let action = dragPresenter?.finish(owner: owner, at: value.location) ?? .cancel
                switch action {
                case .sell(let selected): sell(selected)
                case .reorder(let id, let index): model.reorderBookmark(id: id, to: index)
                case .cancel:
                    if !wasLifted, let index = sale.resolvedIndex(in: model.run) { tap(index) }
                }
            }
    }

    private func lift(sale: InventorySale, strip: InventoryStripGeometry, start: CGPoint) {
        guard !didLift, sale.matches(model.run), scenePhase == .active,
              paperPresenter?.isPresenting != true else { return }
        didLift = true
        model.cancelClueTargeting()
        dragPresenter?.begin(owner: owner, sale: sale,
            itemFrame: strip.itemFrame(kind: sale.kind, index: sale.index),
            bookmarkFrames: strip.bookmarkFrames, start: start, point: latestPoint)
    }

    private func cancelHold() {
        holdTask?.cancel()
        holdTask = nil
        press.cancel()
    }

    private func cancelInteraction() {
        cancelHold()
        dragPresenter?.cancel(owner: owner)
    }

    private func sell(_ sale: InventorySale) {
        guard let index = sale.resolvedIndex(in: model.run) else { explaining = nil; return }
        cancelInteraction()
        explaining = nil
        Haptics.pageTurn()
        model.sell(kind: sale.kind, index: index)
    }

    private func move(_ sale: InventorySale, by offset: Int) {
        guard let id = sale.bookmarkID, let index = sale.resolvedIndex(in: model.run) else { return }
        explaining = nil
        model.reorderBookmark(id: id, to: index + offset)
    }

    private func cards(strip: InventoryStripGeometry) -> some View {
        HStack(alignment: .top, spacing: 5) {
            ForEach(model.run.bookmarks) { owned in
                let slot = model.run.bookmarks.firstIndex { $0.id == owned.id } ?? 0
                let sale = InventorySale(bookmark: owned, index: slot, run: model.run)
                let pulseID = ScoringSourceHighlights.bookmarkBeatID(for: sourceBeat, bookmark: owned)
                let suspended = BookmarkMechanics.isSuspended(id: owned.id, puzzle: model.puzzle)
                InventoryBookmark(def: owned.def, colour: isGameplay ? GameplaySurface.ivory : Paper.pageWarm,
                    ink: isGameplay ? GameplaySurface.ink : Paper.ink, flagged: false, slot: slot,
                    pulling: liftedSale?.bookmarkID == owned.id,
                    asleep: model.sleepingBookmark == slot,
                    suspended: suspended,
                    fired: pulseID != nil,
                    explaining: Binding(get: { explaining == owned.id },
                                        set: { explaining = $0 ? owned.id : nil }),
                    sale: sale, onSell: { sell(sale) },
                    scorePulseID: pulseID, isGameplay: isGameplay,
                    onMoveEarlier: !orderIsPinned && slot > 0 ? { move(sale, by: -1) } : nil,
                    onMoveLater: !orderIsPinned && slot + 1 < model.run.bookmarks.count ? { move(sale, by: 1) } : nil,
                    orderNotice: orderIsPinned ? "The Bindery pins this order for the Puzzle. Odd Turns read forwards; even Turns read backwards." : model.puzzle?.scoringOrderLocked == true
                        ? "This Turn’s scoring is locked. Changes apply next Turn."
                        : "Bookmarks score from left to right.",
                    bonusPaid: model.puzzle?.boss == .publicist
                        && model.puzzle?.bossState.scoring.publicistPaid.contains(owned.id) == true)
                    .overlay(alignment: .bottom) {
                        if model.puzzle?.boss == .publicist,
                           model.puzzle?.bossState.scoring.publicistPaid.contains(owned.id) == true {
                            BossInventoryStamp(text: "PAID")
                        }
                    }
                    .overlay {
                        if carried?.reorderIndex == slot {
                            RoundedRectangle(cornerRadius: 6).strokeBorder(GameplaySurface.sage, lineWidth: 3)
                                .allowsHitTesting(false)
                        }
                    }
                    .gesture(handle(sale: sale, strip: strip) { _ in explaining = owned.id })
                    .accessibilityAction(named: sale.actionTitle) { sell(sale) }
                    .accessibilityActions {
                        if !orderIsPinned && slot > 0 { Button("Move earlier in scoring order") { move(sale, by: -1) } }
                        if !orderIsPinned && slot + 1 < model.run.bookmarks.count {
                            Button("Move later in scoring order") { move(sale, by: 1) }
                        }
                    }
                    // SwiftUI can retain an old custom-action collection when
                    // a ForEach item moves. Refresh its presentation whenever
                    // the available directions change; ownership stays UUID-based.
                    .id("\(slot):\(model.run.bookmarks.count)")
            }
            ForEach(model.run.bookmarks.count..<ItemKind.bookmark.capacity, id: \.self) { slot in
                EmptyBookmark(slot: slot, dark: false, isGameplay: isGameplay)
            }
            Rectangle()
                .fill(isGameplay ? GameplaySurface.softInk.opacity(0.6) : .clear)
                .frame(width: 1, height: isGameplay ? 44 : 1)
                .frame(width: 11)
                .accessibilityHidden(true)
            ForEach(model.run.buffs) { buff in
                let index = model.run.buffs.firstIndex { $0.id == buff.id } ?? 0
                let sale = InventorySale(buff: buff, index: index)
                InventoryBookmark(def: buff.def, colour: isGameplay ? GameplaySurface.ink : Paper.coverBoard,
                    ink: Paper.page, flagged: true, slot: ItemKind.bookmark.capacity + index,
                    pulling: liftedSale?.buffID == buff.id, asleep: false, fired: false,
                    explaining: .constant(false), onActivate: {
                        if let current = sale.resolvedIndex(in: model.run) { onTapBuff(current) }
                    }, isGameplay: isGameplay, isUnavailable: model.puzzle?.boss == .buffborger
                        || BossBuffRules.isEmbargoed(buff.defID, puzzle: model.puzzle),
                    bossEntranceKey: model.puzzle?.boss == .buffborger
                        ? model.bossEntranceID.map { "fine-print:\($0):\(buff.id)" } : nil,
                    consumeBossEntrance: model.consumeBossVisualEvent)
                    .gesture(handle(sale: sale, strip: strip) { onTapBuff($0) })
                    .accessibilityAction(named: sale.actionTitle) { sell(sale) }
            }
            ForEach(model.run.buffs.count..<max(model.run.buffs.count, model.buffCapacity), id: \.self) { slot in
                EmptyBookmark(slot: ItemKind.bookmark.capacity + slot, dark: true, isGameplay: isGameplay)
                    .overlay(alignment: .bottomTrailing) {
                        if model.puzzle?.boss == .buffborger {
                            BossActionSeal(dark: true).padding(2)
                                .modifier(BossObjectArrival(eventKey: model.bossEntranceID.map { "fine-print-empty:\($0):\(slot)" },
                                                            consume: model.consumeBossVisualEvent))
                        }
                    }
            }
        }
        .frame(height: isGameplay ? 44 : 34 + Self.tuck, alignment: .top)
    }
}

struct InventoryStripGeometry {
    let frame: CGRect
    let bookmarkCount: Int
    var buffCapacity: Int = 2
    private var cardWidth: CGFloat { max(1, (frame.width - 46 - CGFloat(max(0, buffCapacity - 2)) * 5) / CGFloat(5 + buffCapacity)) }
    var bookmarkFrames: [CGRect] { (0..<bookmarkCount).map { itemFrame(kind: .bookmark, index: $0) } }
    func itemFrame(kind: ItemKind, index: Int) -> CGRect {
        let x = kind == .buff ? 5 * cardWidth + 41 + CGFloat(index) * (cardWidth + 5)
                             : CGFloat(index) * (cardWidth + 5)
        return CGRect(x: frame.minX + x, y: frame.minY, width: cardWidth, height: frame.height)
    }
}

/// A delayed inventory action captures the actual Buff copy. Identical copies
/// can have the same price, and a slot can change while a slip or drag is open.
struct InventorySale: Equatable {
    let kind: ItemKind
    let index: Int
    let defID: String
    let pricePaid: Int
    let boughtAtLevel: Int?
    let buffID: UUID?
    let bookmarkID: UUID?
    let refund: Int

    init(bookmark: OwnedBookmark, index: Int, run: RunState) {
        kind = .bookmark
        self.index = index
        defID = bookmark.defID
        pricePaid = bookmark.pricePaid
        boughtAtLevel = bookmark.boughtAtLevel
        buffID = nil
        bookmarkID = bookmark.id
        refund = BookmarkMechanics.salePrice(for: bookmark, run: run)
    }

    init(buff: OwnedBuff, index: Int) {
        kind = .buff
        self.index = index
        defID = buff.defID
        pricePaid = buff.pricePaid
        boughtAtLevel = nil
        buffID = buff.id
        bookmarkID = nil
        refund = Shop.sellPrice(buff.pricePaid)
    }

    var actionTitle: String { "Sell for \(refund) \(refund == 1 ? "coin" : "coins")" }

    func matches(_ run: RunState) -> Bool {
        resolvedIndex(in: run) != nil
    }

    func resolvedIndex(in run: RunState) -> Int? {
        switch kind {
        case .bookmark:
            guard let bookmarkID else { return nil }
            return run.bookmarks.firstIndex { $0.id == bookmarkID }
        case .buff:
            guard let buffID else { return nil }
            return run.buffs.firstIndex { $0.id == buffID }
        case .marker, .subscription:
            return nil
        }
    }
}

/// A delayed hold belongs to one touch, not merely one bookmark slot. Reusing
/// a slot after release must never make an older 220 ms callback current again.
struct BookmarkPressState: Equatable {
    private(set) var activeItemKey: Int?
    private(set) var generation = 0

    mutating func begin(itemKey: Int) -> Int? {
        guard activeItemKey != itemKey else { return nil }
        generation += 1
        activeItemKey = itemKey
        return generation
    }

    func isCurrent(itemKey: Int, generation: Int) -> Bool {
        activeItemKey == itemKey && self.generation == generation
    }

    mutating func cancel() {
        activeItemKey = nil
        generation += 1
    }
}

/// A card slipped into the pages: rounded at the head, square at the foot,
/// because the foot is inside the book.
private struct BookmarkShape: Shape {
    var radius: CGFloat = 4
    var isGameplay = false

    func path(in rect: CGRect) -> Path {
        if isGameplay { return RoundedRectangle(cornerRadius: 6).path(in: rect) }
        return Path(
            UnevenRoundedRectangle(
                topLeadingRadius: radius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: radius
            )
            .path(in: rect).cgPath
        )
    }
}

struct InventoryBookmark: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var def: ItemDef
    var colour: Color
    /// What is printed on it, which has to change with the stock.
    var ink: Color
    /// A gilt band across the head. Only the spendable ones carry it — it is
    /// the bit you would take hold of.
    var flagged: Bool
    var slot: Int
    /// True while this one is out of the pages and being carried.
    var pulling: Bool
    /// Unlucky Lucky has this one asleep for the Turn: still yours, still in
    /// the pages, doing nothing.
    var asleep: Bool
    /// Collateral suspends this exact owned copy for the whole Puzzle.
    var suspended = false
    /// A passive Bookmark that just contributed to the player’s last action.
    var fired: Bool
    @Binding var explaining: Bool
    var sale: InventorySale? = nil
    var onSell: (() -> Void)? = nil
    var scorePulseID: UUID? = nil
    /// Buffs open their use slip instead of the passive-item detail panel. Keep
    /// activation on this one accessible element, not a second wrapping button.
    var onActivate: (() -> Void)? = nil
    var isGameplay = false
    var isUnavailable = false
    var onMoveEarlier: (() -> Void)? = nil
    var onMoveLater: (() -> Void)? = nil
    var orderNotice: String? = nil
    var bossEntranceKey: String? = nil
    var consumeBossEntrance: ((String) -> Bool)? = nil
    var bonusPaid = false

    func activate() {
        if let onActivate {
            onActivate()
        } else {
            explaining = true
        }
    }

    /// Hand-inserted things are never quite straight, and the tilt has to be
    /// the same every render or the row twitches on each state change.
    private var tilt: Double {
        let wobble = [(-1.4), 0.9, (-0.6), 1.6, (-1.1), 0.5, (-1.8)]
        return wobble[slot % wobble.count]
    }

    var body: some View {
        // Deliberately not a Button: the gestures are attached from the row,
        // and a Button would swallow them.
        ItemArtwork(id: def.id, size: isGameplay ? 28 : 23, style: .glyph)
            .font(.system(size: isGameplay ? 19 : 15, weight: flagged ? .semibold : .regular))
            .foregroundStyle(ink)
        // The symbol shares the card's center on every run page. A top inset
        // plus a trailing Spacer pushed the former 28-point glyph down by 4pt.
        .frame(maxWidth: .infinity)
        .frame(height: isGameplay ? 44 : 34 + BookmarkRow.tuck)
        .background {
            BookmarkShape(isGameplay: isGameplay)
            .fill(colour)
            .overlay(alignment: .top) {
                if flagged {
                    Rectangle()
                        .fill(
                            LinearGradient(colors: [Paper.coin, Paper.coinRim],
                                           startPoint: .top, endPoint: .bottom)
                        )
                        .frame(height: 3)
                }
            }
            .overlay {
                // A crease down the card, the way a folded marker sits.
                BookmarkShape(isGameplay: isGameplay)
                    .stroke(flagged ? Paper.page.opacity(0.22)
                                    : Paper.ink.opacity(0.14),
                            lineWidth: 1)
            }
            .clipShape(BookmarkShape(isGameplay: isGameplay))
            .shadow(color: .black.opacity(isGameplay ? 0.14 : (flagged ? 0.5 : 0.35)),
                    radius: flagged ? 4 : 3, x: 1, y: 2)
        }
        .overlay {
            if asleep || suspended {
                BossFoldedCorner()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .transition(.scale(scale: 0.1, anchor: .topTrailing).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if asleep {
                BossSleepingBookmarkSeal().padding(.bottom, 1)
                    .transition(.offset(y: -4).combined(with: .opacity))
            }
        }
        .overlay {
            ScoringSourceOutline(trigger: fired ? (scorePulseID?.uuidString ?? def.id) : nil,
                                 cornerRadius: isGameplay ? 6 : 4)
        }
        .rotationEffect(.degrees(isGameplay ? 0 : tilt), anchor: .bottom)
        // Out of the pages and in your hand.
        .overlay(alignment: .bottomTrailing) {
            if isUnavailable {
                BossActionSeal(dark: flagged).padding(2)
                    .modifier(BossObjectArrival(eventKey: bossEntranceKey,
                                                consume: { consumeBossEntrance?($0) ?? false }))
                    .transition(.offset(y: -5).combined(with: .opacity))
                    .accessibilityHidden(true)
            }
        }
        .opacity(pulling ? 0.25 : (asleep || suspended || isUnavailable ? 0.55 : 1))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isUnavailable)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.20), value: asleep || suspended)
        .saturation(asleep || suspended ? 0.2 : 1)
        .contentShape(Rectangle())
        .animation(reduceMotion ? nil : .snappy(duration: 0.16), value: pulling)
        // The root paper portal gives item details the whole screen's bounds,
        // independent of this compact inventory row.
        .paperPanel(isPresented: $explaining) {
            PaperSlip(title: def.name, subtitle: nil, maximumWidth: 380,
                      onClose: { explaining = false }) {
              VStack(spacing: 8) {
                ItemDetailCard(def: def, sale: sale, onSell: onSell, showsHeading: false)
                    .environment(\.dynamicTypeSize, dynamicTypeSize)
                if let orderNotice {
                    Text(orderNotice).font(.system(size: 13)).foregroundStyle(GameplaySurface.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 12) {
                    if let onMoveEarlier {
                        Button(action: onMoveEarlier) {
                            Label("Earlier", systemImage: "arrow.left").frame(minHeight: 44)
                                .padding(.horizontal, 10)
                                .background(GameplaySurface.sage.opacity(0.1), in: .rect(cornerRadius: 6))
                        }
                            .accessibilityLabel("Move earlier in scoring order")
                    }
                    if let onMoveLater {
                        Button(action: onMoveLater) {
                            Label("Later", systemImage: "arrow.right").frame(minHeight: 44)
                                .padding(.horizontal, 10)
                                .background(GameplaySurface.sage.opacity(0.1), in: .rect(cornerRadius: 6))
                        }
                            .accessibilityLabel("Move later in scoring order")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(GameplaySurface.sage)
                .frame(minHeight: onMoveEarlier != nil || onMoveLater != nil ? 44 : 0)
              }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(def.name). \(def.text)")
        .accessibilityValue(accessibilityStatus)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(onActivate == nil ? "Shows item details, scoring order controls and sell price"
                                            : "Shows Buff details and use options")
        .accessibilityAction { activate() }
    }

    var accessibilityStatus: String {
        var values: [String] = []
        if !flagged { values.append("Scoring position \(slot + 1).") }
        if isUnavailable { values.append("Buffs disabled by this Boss.") }
        if bonusPaid { values.append("Flat placement or Line Clear bonus already paid this Turn. Other effects remain active.") }
        if suspended { values.append("Suspended for this Puzzle. Does not contribute.") }
        else if asleep { values.append("Asleep this Turn. Triggered effects sleep; passive upgrades stay active.") }
        if let orderNotice { values.append(orderNotice) }
        return values.joined(separator: " ")
    }
}

/// An empty slot: the gap a bookmark would go into, not a dashed box.
private struct EmptyBookmark: View {
    var slot: Int
    /// An empty Buff slot has to read as a Buff slot, or the row looks like
    /// five cards and two nothings.
    var dark: Bool
    var isGameplay = false

    var body: some View {
        // Against a dark desk an empty slot has to be lighter than its
        // surroundings, not darker, or it disappears entirely.
        BookmarkShape(isGameplay: isGameplay)
            .fill(isGameplay ? (dark ? GameplaySurface.ink : Color(hex: 0xE8E3D8)) : Paper.page.opacity(dark ? 0.05 : 0.16))
            .overlay(alignment: .top) {
                if dark {
                    Rectangle()
                        .fill(Paper.coin.opacity(0.35))
                        .frame(height: 2)
                }
            }
            .overlay {
                BookmarkShape(isGameplay: isGameplay)
                    .stroke(isGameplay ? GameplaySurface.softInk.opacity(0.25) : Paper.page.opacity(dark ? 0.28 : 0.38), lineWidth: 1)
            }
            .clipShape(BookmarkShape(isGameplay: isGameplay))
            .frame(maxWidth: .infinity)
            .frame(height: isGameplay ? 44 : 26 + BookmarkRow.tuck)
            .shadow(color: .black.opacity(isGameplay ? 0.1 : 0), radius: 1, x: 0, y: 2)
            .accessibilityLabel(dark ? "Empty buff slot" : "Empty slot")
    }
}

/// What an item actually does, on a torn slip of paper.
struct ItemDetailCard: View {
    var def: ItemDef
    var sale: InventorySale? = nil
    var onSell: (() -> Void)? = nil
    var showsHeading = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // A bounded scroll region preserves the complete copy at the
                // largest sizes. Respect the paper panel's compact margins.
                ScrollView { printedContent }
                    .frame(maxWidth: 260)
                    .frame(height: 360)
            } else {
                printedContent
                    .frame(maxWidth: 260)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .background(Paper.page)
    }

    private var printedContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            if showsHeading {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                ItemArtwork(id: def.id, size: 23 * textScale, style: .glyph)
                    .font(.system(size: 17 * textScale))
                    .foregroundStyle(Paper.ink)
                    .accessibilityHidden(true)
                Text(def.name)
                    .font(Print.subheading(17 * textScale))
                    .foregroundStyle(Paper.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            }
            Text(def.text)
                .font(Print.body(14 * textScale))
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            if let sale, let onSell {
                Divider().overlay(Paper.rule)
                Button(sale.actionTitle, action: onSell)
                    .font(Print.body(14 * textScale))
                    .foregroundStyle(Paper.redPencil)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sell \(def.name) for \(sale.refund) \(sale.refund == 1 ? "coin" : "coins")")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
