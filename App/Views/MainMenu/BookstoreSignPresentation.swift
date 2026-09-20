import Foundation
import ProbablySudokuEngine

/// The chalk board keeps the Book's own benefit and describes the selected
/// Obstacle separately. Compact print is derived from the same engine values
/// that change the run; spoken copy uses the engine's full explanation.
struct BookstoreSignPresentation: Equatable {
    let title: String
    let effectLines: [String]
    let cacheKey: String
    let accessibilityLabel: String

    init(edition: BookEdition, obstacle: Obstacle) {
        title = edition.benefit.title
        cacheKey = "benefit|\(edition.id)" + (obstacle == .none ? "" : "|obstacle:\(obstacle.rawValue)")
        var hand: [String] = []
        var limits: [String] = []
        if obstacle.handSizeDelta != 0 {
            hand.append("\(Self.signed(obstacle.handSizeDelta)) HAND")
        }
        if obstacle.blockedNumbersEachTurn > 0 {
            hand.append("UP TO \(obstacle.blockedNumbersEachTurn) BLOCKED/TURN")
        }
        if obstacle.turnsDelta != 0 {
            limits.append("\(Self.signed(obstacle.turnsDelta)) TURN")
        }
        if obstacle.removesTosses { limits.append("NO TOSSES") }
        effectLines = [hand, limits].filter { !$0.isEmpty }.map { $0.joined(separator: " · ") }
        let benefit = "Book benefit: \(edition.benefit.title). \(edition.benefit.detail)"
        accessibilityLabel = obstacle == .none ? benefit
            : "\(benefit) Selected \(obstacle.name). \(obstacle.text)"
    }

    private static func signed(_ value: Int) -> String {
        value < 0 ? "−\(abs(value))" : "+\(value)"
    }
}
