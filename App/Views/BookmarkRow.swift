import SwiftUI
import ProbablySudokuEngine

/// What you own, slipped into the top of the book like bookmarks.
///
/// Bookmarks run for the whole Book and Buffs are spent from here, so both have to be
/// on screen at all times — but a floating tray above the book is a piece of
/// interface, and everything else in this game is an object. Bookmarks are
/// tucked behind the block, so their tails disappear into the pages.
struct BookmarkRow: View {
    @Bindable var model: GameModel
    var onTapBuff: (Int) -> Void

    /// The one being pulled out of the pages to be sold.
    @State private var pulled: Pulled?
    /// Which slot has its explanation open. Held here rather than inside the
    /// card, because the card no longer owns its own tap.
    @State private var explaining: Int?
    /// A press that has not yet become either a tap or a pull.
    @State private var pressing: Int?


    struct Pulled: Equatable {
        var kind: ItemKind
        var index: Int
        var defID: String
        var price: Int
        var point: CGPoint = .zero
        var overBin = false
    }

    private static let space = "bookmarkRow"
    /// How wide the sell counter is when it appears.
    private static let binWidth: CGFloat = 96

    /// How much of each bookmark is swallowed by the book beneath it.
    static let tuck: CGFloat = 16
    private static let visible: CGFloat = 34
    /// The gap that separates the two kinds. Everything in the row is slipped
    /// into the same pages, so they have to stay one row — but a Bookmark runs
    /// by itself and a Buff is something you take out and use, and a row of
    /// seven identical cards says neither.
    private static let divide: CGFloat = 11

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                cards(width: proxy.size.width)
                    // Out of the way of the counter while one is being sold.
                    .opacity(pulled == nil ? 1 : 0.35)

                if let pulled {
                    SellCounter(defID: pulled.defID, price: pulled.price,
                                armed: pulled.overBin)
                        .frame(width: Self.binWidth, height: Self.visible)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))

                    // Held in the strip the bookmarks stand in. Below that is
                    // the book, which is drawn over this row so its tails tuck
                    // into the pages — so anything drawn down there is simply
                    // not seen.
                    // Once it is over the counter the card is shown *in* the
                    // counter instead, so the price is not hidden underneath
                    // the thing you are about to sell.
                    if !pulled.overBin {
                        PulledCard(defID: pulled.defID, armed: false)
                            .position(x: pulled.point.x, y: Self.visible / 2)
                            .allowsHitTesting(false)
                    }
                }
            }
            .coordinateSpace(name: Self.space)
            #if DEBUG
            // `-pullSell` runs the whole thing — works one loose, carries it
            // to the counter through the same code a finger goes through, and
            // lets go — so the drop can be proved without a touch.
            .task {
                guard ProcessInfo.processInfo.arguments.contains("-pullSell"),
                      pulled == nil else { return }
                try? await Task.sleep(for: .milliseconds(900))
                guard let owned = model.run.bookmarks.first else { return }
                let width = proxy.size.width
                withAnimation(.snappy(duration: 0.2)) {
                    pulled = Pulled(kind: .bookmark, index: 0, defID: owned.defID,
                                    price: model.sellPrice(owned.pricePaid),
                                    point: CGPoint(x: 40, y: Self.visible / 2))
                }
                try? await Task.sleep(for: .milliseconds(400))
                carry(to: CGPoint(x: width - 24, y: Self.visible / 2), width: width)
                guard !ProcessInfo.processInfo.arguments.contains("-pullHold") else { return }
                try? await Task.sleep(for: .milliseconds(600))
                drop()
            }
            #endif
            .animation(.snappy(duration: 0.18), value: pulled == nil)
            .animation(.snappy(duration: 0.14), value: pulled?.overBin)
        }
        .frame(height: Self.visible + Self.tuck)
    }

    /// Where the counter is, in the row's own space.
    ///
    /// The width is handed in from the reader that laid the row out, not kept
    /// in state: state written from a `GeometryReader` is a frame behind at
    /// best and zero at worst, and a counter measured against a width of zero
    /// sits off the left of the screen where nothing will ever be dropped on
    /// it. That is why the first drop did nothing.
    private func bin(in width: CGFloat) -> CGRect {
        // Generous: the finger is somewhere below the strip by the time it
        // gets here, and a little short of the counter still counts.
        CGRect(x: width - Self.binWidth - 16, y: -Self.visible,
               width: Self.binWidth + 40, height: (Self.visible + Self.tuck) * 3)
    }

    /// Everything a card can be asked to do, as one drag.
    ///
    /// Written by hand rather than composed. `LongPressGesture.sequenced(before:
    /// DragGesture)` inside an `ExclusiveGesture` recognised the hold — the
    /// card lifted and the counter appeared — but never delivered a single
    /// drag update, so whatever you picked up stayed at the origin. One
    /// `DragGesture` with the hold timed here does exactly what it says.
    private func handle(kind: ItemKind, index: Int, defID: String, price: Int,
                        width: CGFloat, tap: @escaping () -> Void) -> some Gesture {
        let token = key(kind, index)

        return DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
            .onChanged { value in
                if pulled == nil {
                    guard pressing != token else { return }
                    pressing = token
                    hold(token: token, kind: kind, index: index,
                         defID: defID, price: price, from: value.location)
                    return
                }
                guard pulled?.kind == kind, pulled?.index == index else { return }
                carry(to: value.location, width: width)
            }
            .onEnded { _ in
                pressing = nil
                guard pulled != nil else { tap(); return }
                drop()
            }
    }

    private func key(_ kind: ItemKind, _ index: Int) -> Int {
        (kind == .buff ? 100 : 0) + index
    }

    /// A quarter of a second down and it comes loose. Long enough that a tap
    /// is never mistaken for a pull, short enough that it does not feel stuck.
    private func hold(token: Int, kind: ItemKind, index: Int,
                      defID: String, price: Int, from point: CGPoint) {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(220))
            guard pressing == token, pulled == nil else { return }
            withAnimation(.snappy(duration: 0.18)) {
                pulled = Pulled(kind: kind, index: index, defID: defID,
                                price: price, point: point)
            }
        }
    }

    /// Letting go. Over the counter it sells; anywhere else it goes back.
    private func drop() {
        guard let carrying = pulled else { return }
        withAnimation(.snappy(duration: 0.2)) { pulled = nil }
        guard carrying.overBin else { return }
        Haptics.pageTurn()
        model.sell(kind: carrying.kind, index: carrying.index)
    }

    private func carry(to point: CGPoint, width: CGFloat) {
        guard var carrying = pulled else { return }
        carrying.point = point
        let over = bin(in: width).contains(point)
        if over != carrying.overBin {
            carrying.overBin = over
        }
        pulled = carrying
    }

    private func cards(width: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 5) {
            ForEach(0..<ItemKind.bookmark.capacity, id: \.self) { slot in
                if slot < model.run.bookmarks.count {
                    let owned = model.run.bookmarks[slot]
                    Bookmark(def: owned.def, colour: Paper.pageWarm,
                             ink: Paper.ink, flagged: false, slot: slot,
                             pulling: pulled?.kind == .bookmark && pulled?.index == slot,
                             asleep: model.sleepingBookmark == slot,
                             explaining: Binding(
                                get: { explaining == slot },
                                set: { explaining = $0 ? slot : nil }))
                        .gesture(handle(kind: .bookmark, index: slot,
                                        defID: owned.defID,
                                        price: model.sellPrice(owned.pricePaid),
                                        width: width) {
                            explaining = slot
                        })
                } else {
                    EmptyBookmark(slot: slot, dark: false)
                }
            }

            // Taken out of the flexible width rather than out of one card, so
            // all seven stay the same size.
            Spacer(minLength: 0).frame(width: Self.divide)

            ForEach(0..<ItemKind.buff.capacity, id: \.self) { slot in
                let index = slot
                if index < model.run.buffs.count {
                    let buff = model.run.buffs[index]
                    // Board, not paper: a Buff is a thing you take out and
                    // spend on a square, and it should not look like the five
                    // cards that simply sit there working.
                    Bookmark(def: buff.def, colour: Paper.coverBoard,
                             ink: Paper.page, flagged: true,
                             slot: ItemKind.bookmark.capacity + slot,
                             pulling: pulled?.kind == .buff && pulled?.index == index,
                             asleep: false,
                             explaining: .constant(false))
                        .gesture(handle(kind: .buff, index: index,
                                        defID: buff.defID,
                                        price: model.sellPrice(buff.pricePaid),
                                        width: width) {
                            onTapBuff(index)
                        })
                        // Pulling is an enhancement, not the only way to use
                        // a Buff. Keep a semantic activation for VoiceOver and
                        // switch control users.
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(buff.def.name). \(buff.def.text)")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { onTapBuff(index) }
                } else {
                    EmptyBookmark(slot: ItemKind.bookmark.capacity + slot, dark: true)
                }
            }
        }
        .frame(height: Self.visible + Self.tuck, alignment: .top)
    }
}

/// The counter, which is only there while something is being carried to it.
///
/// Hidden the rest of the time on purpose: a permanent bin over the pages
/// would be a piece of interface sitting on the book, and it would be the
/// first thing anyone pressed by mistake.
private struct SellCounter: View {
    var defID: String
    var price: Int
    var armed: Bool

    var body: some View {
        HStack(spacing: 5) {
            if armed {
                Image(systemName: ItemIcon.symbol(for: defID))
                    .font(.system(size: 13, weight: .semibold))
            }
            Text("Sell")
                .font(Print.caption(10)).tracking(1.2).textCase(.uppercase)
            HStack(spacing: 2) {
                Text("\(price)")
                    .font(Print.numeral(13, weight: .bold))
                Image(systemName: "circle.circle.fill")
                    .font(.system(size: 9))
            }
        }
        .foregroundStyle(armed ? Paper.page : Paper.page.opacity(0.7))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 5,
                                   bottomTrailingRadius: 0, topTrailingRadius: 5)
                .fill(armed ? Paper.sageDeep : Color.black.opacity(0.4))
                .overlay {
                    UnevenRoundedRectangle(topLeadingRadius: 5, bottomLeadingRadius: 5,
                                           bottomTrailingRadius: 0, topTrailingRadius: 5)
                        .strokeBorder(armed ? Paper.sage : Paper.page.opacity(0.4),
                                      style: StrokeStyle(lineWidth: 1.4,
                                                         dash: armed ? [] : [4, 3]))
                }
        }
        .scaleEffect(armed ? 1.04 : 1)
    }
}

/// The card itself, out of the pages and in your hand.
private struct PulledCard: View {
    var defID: String
    var armed: Bool

    var body: some View {
        Image(systemName: ItemIcon.symbol(for: defID))
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Paper.ink)
            .frame(width: 38, height: 30)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(armed ? Paper.cellCleared : Paper.pageWarm)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(armed ? Paper.sageDeep : Paper.rule, lineWidth: 1)
            }
            .rotationEffect(.degrees(-5))
            .shadow(color: .black.opacity(0.4), radius: 8, x: 3, y: 7)
            .scaleEffect(armed ? 1.08 : 1)
    }
}

/// A card slipped into the pages: rounded at the head, square at the foot,
/// because the foot is inside the book.
private struct BookmarkShape: Shape {
    var radius: CGFloat = 4

    func path(in rect: CGRect) -> Path {
        Path(
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

private struct Bookmark: View {
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
    @Binding var explaining: Bool

    /// Hand-inserted things are never quite straight, and the tilt has to be
    /// the same every render or the row twitches on each state change.
    private var tilt: Double {
        let wobble = [(-1.4), 0.9, (-0.6), 1.6, (-1.1), 0.5, (-1.8)]
        return wobble[slot % wobble.count]
    }

    var body: some View {
        // Deliberately not a Button: the gestures are attached from the row,
        // and a Button would swallow them.
        VStack(spacing: 0) {
            Image(systemName: ItemIcon.symbol(for: def.id))
            .font(.system(size: 15, weight: flagged ? .semibold : .regular))
            .foregroundStyle(ink)
            .padding(.top, flagged ? 10 : 8)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34 + BookmarkRow.tuck)
        .background {
            BookmarkShape()
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
                BookmarkShape()
                    .stroke(flagged ? Paper.page.opacity(0.22)
                                    : Paper.ink.opacity(0.14),
                            lineWidth: 1)
            }
            .clipShape(BookmarkShape())
            .shadow(color: .black.opacity(flagged ? 0.5 : 0.35),
                    radius: flagged ? 4 : 3, x: 1, y: 2)
        }
        .overlay {
            if asleep {
                // Crossed out in the same red pencil a barred number gets.
                Rectangle()
                    .fill(Paper.redPencil.opacity(0.75))
                    .frame(height: 1.6)
                    .rotationEffect(.degrees(-18))
            }
        }
        .rotationEffect(.degrees(tilt), anchor: .bottom)
        // Out of the pages and in your hand.
        .opacity(pulling ? 0.25 : (asleep ? 0.55 : 1))
        .saturation(asleep ? 0.2 : 1)
        .contentShape(Rectangle())
        .animation(.snappy(duration: 0.16), value: pulling)
        // Anchored to this bookmark, so the arrow points at the one that was
        // tapped rather than at the middle of the row.
        .popover(isPresented: $explaining, arrowEdge: .bottom) {
            ItemDetailCard(def: def)
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("\(def.name). \(def.text)")
    }
}

/// An empty slot: the gap a bookmark would go into, not a dashed box.
private struct EmptyBookmark: View {
    var slot: Int
    /// An empty Buff slot has to read as a Buff slot, or the row looks like
    /// five cards and two nothings.
    var dark: Bool

    var body: some View {
        // Against a dark desk an empty slot has to be lighter than its
        // surroundings, not darker, or it disappears entirely.
        BookmarkShape()
            .fill(Paper.page.opacity(dark ? 0.05 : 0.16))
            .overlay(alignment: .top) {
                if dark {
                    Rectangle()
                        .fill(Paper.coin.opacity(0.35))
                        .frame(height: 2)
                }
            }
            .overlay {
                BookmarkShape()
                    .stroke(Paper.page.opacity(dark ? 0.28 : 0.38), lineWidth: 1)
            }
            .clipShape(BookmarkShape())
            .frame(maxWidth: .infinity)
            .frame(height: 26 + BookmarkRow.tuck)
            .accessibilityLabel(dark ? "Empty buff slot" : "Empty slot")
    }
}

/// What an item actually does, on a torn slip of paper.
struct ItemDetailCard: View {
    var def: ItemDef

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Image(systemName: ItemIcon.symbol(for: def.id))
                    .font(.system(size: 15))
                    .foregroundStyle(Paper.ink)
                Text(def.name)
                    .font(Print.subheading(15))
                    .foregroundStyle(Paper.ink)
            }
            Text(def.text)
                .font(Print.body(13))
                .foregroundStyle(Paper.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: 260, alignment: .leading)
        .background(Paper.page)
    }
}
