import SwiftUI
import NumberClubEngine

/// What you own, slipped into the top of the book like bookmarks.
///
/// Ads run for the whole Book and Buffs are spent from here, so both have to be
/// on screen at all times — but a floating tray above the book is a piece of
/// interface, and everything else in this game is an object. Bookmarks are
/// tucked behind the block, so their tails disappear into the pages.
struct BookmarkRow: View {
    @Bindable var model: GameModel
    var onTapBuff: (Int) -> Void
    @State private var inspecting: ItemDef?

    /// How much of each bookmark is swallowed by the book beneath it.
    static let tuck: CGFloat = 16
    private static let visible: CGFloat = 34

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            ForEach(0..<ItemKind.ad.capacity, id: \.self) { slot in
                if slot < model.run.ads.count {
                    let ad = model.run.ads[slot]
                    Bookmark(def: ad.def, colour: Paper.pageWarm, slot: slot) {
                        inspecting = ad.def
                    }
                } else {
                    EmptyBookmark(slot: slot)
                }
            }

            ForEach(0..<ItemKind.buff.capacity, id: \.self) { slot in
                let index = slot
                if index < model.run.buffs.count {
                    let buff = model.run.buffs[index]
                    // Sage, because a Buff is a thing you spend rather than a
                    // thing that is simply running.
                    Bookmark(def: buff.def, colour: Paper.sage.opacity(0.55),
                             slot: ItemKind.ad.capacity + slot) {
                        onTapBuff(index)
                    }
                } else {
                    EmptyBookmark(slot: ItemKind.ad.capacity + slot)
                }
            }
        }
        .frame(height: Self.visible + Self.tuck, alignment: .top)
        .popover(item: $inspecting) { def in
            ItemDetailCard(def: def)
                .presentationCompactAdaptation(.popover)
        }
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
    var slot: Int
    var action: () -> Void

    /// Hand-inserted things are never quite straight, and the tilt has to be
    /// the same every render or the row twitches on each state change.
    private var tilt: Double {
        let wobble = [(-1.4), 0.9, (-0.6), 1.6, (-1.1), 0.5, (-1.8)]
        return wobble[slot % wobble.count]
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Image(systemName: ItemIcon.symbol(for: def.id))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Paper.ink)
                    .padding(.top, 8)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 34 + BookmarkRow.tuck)
            .background {
                BookmarkShape()
                    .fill(colour)
                    .overlay {
                        // A crease down the card, the way a folded marker sits.
                        BookmarkShape()
                            .stroke(Paper.ink.opacity(0.14), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 3, x: 1, y: 2)
            }
            .rotationEffect(.degrees(tilt), anchor: .bottom)
        }
        .buttonStyle(PressedPaperStyle())
        .accessibilityLabel("\(def.name). \(def.text)")
    }
}

/// An empty slot: the gap a bookmark would go into, not a dashed box.
private struct EmptyBookmark: View {
    var slot: Int

    var body: some View {
        // Against a dark desk an empty slot has to be lighter than its
        // surroundings, not darker, or it disappears entirely.
        BookmarkShape()
            .fill(Paper.page.opacity(0.09))
            .overlay {
                BookmarkShape()
                    .stroke(Paper.page.opacity(0.22), lineWidth: 1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 26 + BookmarkRow.tuck)
            .accessibilityLabel("Empty slot")
    }
}
