import SwiftUI
import ProbablySudokuEngine

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
        // Bookmarks
        case "bm_morning_edition", "bm_evening_edition": return "newspaper"
        case "bm_local_gossip": return "bubble.left.and.bubble.right"
        case "bm_sports_section": return "figure.run"
        case "bm_society_pages": return "crown"
        case "bm_op_ed", "bm_editorial_board", "bm_letters_to_the_editor": return "text.quote"
        case "bm_front_page_splash", "bm_extra_extra": return "megaphone"
        case "bm_rolling_presses", "bm_syndication", "bm_stop_the_presses": return "gearshape.2"
        case "bm_the_sunday_supplement": return "book.pages"
        case "bm_finance_pages", "bm_market_wrap": return "chart.line.uptrend.xyaxis"
        case "bm_paper_route": return "bicycle"
        case "bm_auction_notices": return "hammer"
        case "bm_help_wanted": return "person.badge.plus"
        case "bm_weather_forecast": return "cloud.sun"
        case "bm_puzzle_corner": return "puzzlepiece"
        case "bm_late_city_final": return "moon.stars"
        case "bm_crossword_daily": return "square.grid.3x3"
        default: return "circle"
        }
    }
}
