import Foundation
import ProbablySudokuEngine
import SwiftUI

/// Keep game observation here, not on ContentView: a placement can change
/// the compound Engine value without rebuilding the entire front door.
struct GameMusicObserver: View {
    let model: GameModel?
    let isClosingBook: Bool

    private var cue: GameMusicCue {
        guard let model, !model.wantsMenu, !isClosingBook else { return .bookshop }
        let isEncounter = model.run.slot == .boss
            && (model.page == .briefing || model.page == .puzzle)
        return .forEncounter(book: model.run.book,
                             boss: isEncounter ? (model.puzzle?.boss ?? model.run.pendingBoss) : nil)
    }

    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onChange(of: cue, initial: true) { GameAudio.shared.selectMusic(cue) }
    }
}

/// Music is presentation-only: selecting a cue never advances the run RNG.
enum GameMusicCue: String, CaseIterable, Sendable {
    case bookshop = "bookshop-theme"
    case quietMargins = "quiet-margins"
    case rainyMargins = "rainy-margins"
    case redInk = "red-ink-deadline"
    case finalDraft = "final-draft"

    static func forBook(_ book: Book) -> Self {
        switch book {
        case .probably, .genuinely, .smallVictories, .wellEarned: .bookshop
        case .noPressure, .snackBreak, .trustMe, .bites: .quietMargins
        case .slightlyHarder, .overthinking, .rainyDay, .secondThoughts: .rainyMargins
        }
    }

    static func forEncounter(book: Book, boss: BossModifier?) -> Self {
        guard let boss else { return forBook(book) }
        return boss.isFinalBoss ? .finalDraft : .redInk
    }

    func url(in bundle: Bundle) -> URL? {
        bundle.url(forResource: rawValue, withExtension: "m4a")
            ?? bundle.url(forResource: rawValue, withExtension: "m4a", subdirectory: "Audio")
    }
}
