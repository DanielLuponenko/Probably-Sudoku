import SwiftUI
import NumberClubEngine

/// The panel below the book during an active puzzle. It shows what you own —
/// Buffs you can spend and the Ads and Markers running in the background —
/// never shop stock.
struct OwnedPanelView: View {
    @Bindable var model: GameModel
    var onUseBuff: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Buffs")
                    .font(Print.caption(12))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Paper.inkSoft)
                Rectangle().fill(Paper.rule.opacity(0.6)).frame(height: 1)
            }

            HStack(spacing: 10) {
                ForEach(0..<ItemKind.buff.capacity, id: \.self) { index in
                    if index < model.run.buffs.count {
                        BuffSlot(def: model.run.buffs[index].def) { onUseBuff(index) }
                    } else {
                        EmptyBuffSlot()
                    }
                }

                if !model.run.ads.isEmpty || !model.run.markers.isEmpty {
                    Rectangle().fill(Paper.rule.opacity(0.5)).frame(width: 1, height: 44)
                    RunningTotals(ads: model.run.ads, markers: model.run.markers,
                                  hidden: model.markersAreHidden)
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Paper.page)
                .overlay { PaperGrain(opacity: 0.04) }
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Paper.pageEdge, lineWidth: 1) }
                .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
        }
    }
}

private struct BuffSlot: View {
    var def: ItemDef
    var use: () -> Void

    var body: some View {
        Button(action: use) {
            VStack(spacing: 5) {
                Image(systemName: ItemIcon.symbol(for: def.id))
                    .font(.system(size: 19, weight: .regular))
                    .foregroundStyle(Paper.ink)
                Text(def.name)
                    .font(Print.caption(9))
                    .tracking(0.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Paper.inkSoft)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background { RoundedRectangle(cornerRadius: 5).fill(Paper.pageWarm) }
            .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(Paper.rule, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Use \(def.name). \(def.text)")
    }
}

private struct EmptyBuffSlot: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .strokeBorder(Paper.rule.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .accessibilityLabel("Empty Buff slot")
    }
}

/// A quiet reminder of what is running: Ads by count, Markers by their colour.
private struct RunningTotals: View {
    var ads: [OwnedAd]
    var markers: [OwnedMarker]
    var hidden: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: "newspaper")
                    .font(.system(size: 12))
                    .foregroundStyle(Paper.inkSoft)
                Text("\(ads.count)/\(ItemKind.ad.capacity)")
                    .font(Print.numeral(12, weight: .semibold))
                    .foregroundStyle(Paper.ink)
            }
            HStack(spacing: 4) {
                if hidden {
                    Image(systemName: "eye.slash")
                        .font(.system(size: 11))
                        .foregroundStyle(Paper.inkSoft)
                    Text("Fogged")
                        .font(Print.caption(10))
                        .foregroundStyle(Paper.inkSoft)
                } else {
                    ForEach(markers, id: \.defID) { marker in
                        Circle()
                            .fill(Paper.markerColor(marker.defID))
                            .frame(width: 11, height: 11)
                            .overlay { Circle().strokeBorder(Paper.ink.opacity(0.3), lineWidth: 0.8) }
                    }
                    if markers.isEmpty {
                        Text("No Markers")
                            .font(Print.caption(10))
                            .foregroundStyle(Paper.inkFaint)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Book-illustration icons, drawn from SF Symbols so they scale, respect the
/// text weight, and come with VoiceOver descriptions for free.
enum ItemIcon {
    static func symbol(for id: String) -> String {
        switch id {
        // Buffs
        case "bf_peek": return "magnifyingglass"
        case "bf_redraw": return "arrow.triangle.2.circlepath"
        case "bf_overtime": return "clock.badge.checkmark"
        case "bf_double_down": return "multiply.circle"
        case "bf_insurance": return "shield"
        case "bf_second_print": return "doc.on.doc"
        case "bf_lucky_dip": return "hand.draw"
        case "bf_bird_seed": return "bird"
        case "bf_fresh_ink": return "drop"
        case "bf_paper_crane": return "paperplane"
        // Markers
        case let id where id.hasPrefix("mk_"): return "square.fill"
        // Ads
        case "ad_morning_edition", "ad_evening_edition": return "newspaper"
        case "ad_local_gossip": return "bubble.left.and.bubble.right"
        case "ad_sports_section": return "figure.run"
        case "ad_society_pages": return "crown"
        case "ad_op_ed", "ad_editorial_board", "ad_letters_to_the_editor": return "text.quote"
        case "ad_front_page_splash", "ad_extra_extra": return "megaphone"
        case "ad_rolling_presses", "ad_syndication", "ad_stop_the_presses": return "gearshape.2"
        case "ad_the_sunday_supplement": return "book.pages"
        case "ad_finance_pages", "ad_market_wrap": return "chart.line.uptrend.xyaxis"
        case "ad_paper_route": return "bicycle"
        case "ad_auction_notices": return "hammer"
        case "ad_help_wanted": return "person.badge.plus"
        case "ad_weather_forecast": return "cloud.sun"
        case "ad_puzzle_corner": return "puzzlepiece"
        case "ad_late_city_final": return "moon.stars"
        case "ad_crossword_daily": return "square.grid.3x3"
        default: return "circle"
        }
    }
}
