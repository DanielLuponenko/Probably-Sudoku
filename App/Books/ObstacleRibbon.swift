import SwiftUI
import ProbablySudokuEngine

/// The obstacles, as the ribbons sewn into the Book.
///
/// They used to be a swiper in the band above the Book, which made choosing
/// one a separate control on a separate surface. A ribbon is not a control —
/// it is part of the Book, it is where you have your finger, and pulling on
/// one is the plainest possible way of saying "start here". The Book takes the
/// colour of the ribbon you pick, so the choice is visible on the object for
/// as long as you hold it.
enum ObstacleRibbon {
    /// One colour per obstacle. Sized for nine: the ladder is not finished, and
    /// the strip should not have to be redesigned when the rest arrive.
    private static let palette: [Color] = [
        Color(hex: 0xA9BE7E),   // I
        Color(hex: 0xD98E4B),   // II
        Color(hex: 0xD9B23F),   // III
        Color(hex: 0x7FB0A8),   // IV
        Color(hex: 0xB07FA8),   // V
        Color(hex: 0xC96A5B),   // VI
        Color(hex: 0x6E8BB0),   // VII
        Color(hex: 0x8E9E5E),   // VIII
        Color(hex: 0x8A6BA8),   // IX
    ]

    static func colour(for obstacle: Obstacle) -> Color {
        colour(forSlot: obstacle.rawValue)
    }

    /// By position on the strip, so a slot with no obstacle written for it yet
    /// still has the colour it will have when there is one.
    static func colour(forSlot slot: Int) -> Color {
        palette[(slot - 1) % palette.count]
    }

    /// A figure, not the Roman numeral off the obstacle's name: "VIII" cannot
    /// be read at the width of a tab, and there will be an eighth.
    static func numeral(for obstacle: Obstacle) -> String {
        "\(obstacle.rawValue)"
    }

    /// The cloth of a Book bound to this obstacle. Darkened, because boards are
    /// dyed cloth and a ribbon is dyed silk.
    static func cloth(for obstacle: Obstacle) -> Color {
        colour(for: obstacle).mixed(with: Color(hex: 0x2A2622), by: 0.42)
    }
}
