import SwiftUI
import NumberClubEngine

/// The build, always on screen. Ads run for the whole Book and are what a run
/// is actually made of, so they sit above the page permanently rather than
/// being tucked into a panel you have to go looking for. Buffs sit beside them
/// because they are spent from here. Markers are not in the row — they live on
/// the board itself, as the coloured squares they are.
struct LoadoutRow: View {
    @Bindable var model: GameModel
    var onUseBuff: (Int) -> Void
    @State private var inspecting: ItemDef?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<ItemKind.ad.capacity, id: \.self) { index in
                if index < model.run.ads.count {
                    let ad = model.run.ads[index]
                    LoadoutSlot(def: ad.def, tint: Paper.pageWarm) { inspecting = ad.def }
                } else {
                    LoadoutSlot.empty
                }
            }

            Divider().frame(height: 34).overlay(Paper.rule.opacity(0.5))

            ForEach(0..<ItemKind.buff.capacity, id: \.self) { index in
                if index < model.run.buffs.count {
                    let buff = model.run.buffs[index]
                    // Opens the Buff rather than spending it: a one-shot should
                    // not be gone because a finger landed on it.
                    LoadoutSlot(def: buff.def, tint: Paper.cellSelected, isSpendable: true) {
                        onUseBuff(index)
                    } inspect: {
                        inspecting = buff.def
                    }
                } else {
                    LoadoutSlot.empty
                }
            }

            if !model.run.markers.isEmpty || model.markersAreHidden {
                Divider().frame(height: 34).overlay(Paper.rule.opacity(0.5))
                MarkerChips(markers: model.run.markers, hidden: model.markersAreHidden)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Paper.page)
                .overlay { PaperGrain(opacity: 0.04) }
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Paper.pageEdge, lineWidth: 1) }
                .shadow(color: .black.opacity(0.4), radius: 10, y: 5)
        }
        .popover(item: $inspecting) { def in
            ItemDetailCard(def: def)
                .presentationCompactAdaptation(.popover)
        }
    }
}

private struct LoadoutSlot: View {
    var def: ItemDef
    var tint: Color
    var isSpendable: Bool = false
    var action: () -> Void
    var inspect: (() -> Void)?

    /// An empty slot has to read as a slot rather than as a gap, or a fresh
    /// run looks like a rendering fault.
    static var empty: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Paper.pageWarm.opacity(0.55))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Paper.rule.opacity(0.75),
                                  style: StrokeStyle(lineWidth: 1, dash: [3, 2.5]))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .accessibilityLabel("Empty slot")
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: ItemIcon.symbol(for: def.id))
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Paper.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background { RoundedRectangle(cornerRadius: 5).fill(tint) }
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(isSpendable ? Paper.sageDeep : Paper.rule,
                                      lineWidth: isSpendable ? 1.6 : 1)
                }
        }
        .buttonStyle(PressedPaperStyle())
        .simultaneousGesture(LongPressGesture().onEnded { _ in (inspect ?? action)() })
        .accessibilityLabel("\(def.name). \(def.text)")
        .accessibilityHint(isSpendable ? "Double tap to spend it" : "Double tap for details")
    }
}

/// Markers by colour only. The board already says where they are, so repeating
/// that here would be noise — this is just a reminder of which inks are live.
private struct MarkerChips: View {
    var markers: [OwnedMarker]
    var hidden: Bool

    var body: some View {
        HStack(spacing: 3) {
            if hidden {
                Image(systemName: "eye.slash")
                    .font(.system(size: 13))
                    .foregroundStyle(Paper.redPencil)
                    .accessibilityLabel("Markers hidden by The Fog")
            } else {
                ForEach(markers, id: \.defID) { marker in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Paper.markerColor(marker.defID))
                        .frame(width: 12, height: 24)
                        .overlay {
                            RoundedRectangle(cornerRadius: 2)
                                .strokeBorder(Paper.ink.opacity(0.25), lineWidth: 0.8)
                        }
                        .accessibilityLabel(marker.def.name)
                }
            }
        }
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

extension ItemDef: Identifiable {}
