import SwiftUI
import NumberClubEngine

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
