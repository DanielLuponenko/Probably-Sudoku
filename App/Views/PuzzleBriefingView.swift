import SwiftUI
import NumberClubEngine

/// The loose page before a Puzzle begins. It makes the Clipping visible before
/// the player commits, while still keeping Bosses free of any skip control.
struct PuzzleBriefingView: View {
    @Bindable var model: GameModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.run.slot == .boss ? "Boss Puzzle" : "Next Puzzle")
                .pageHeading(30)
            Text("Level \(model.run.level) · Puzzle \(model.run.slot.rawValue + 1) of 3")
                .font(Print.caption(12)).tracking(1.2).textCase(.uppercase)
                .foregroundStyle(Paper.inkSoft)
            Rectangle().fill(Paper.rule).frame(height: 1)

            if let clipping = model.run.currentClipping {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CLIPPING ON OFFER")
                        .font(Print.caption(11)).tracking(1.3)
                        .foregroundStyle(Paper.redPencil)
                    Text(clipping.name).font(Print.subheading(22)).foregroundStyle(Paper.ink)
                    Text(clipping.detail).font(Print.body(14)).foregroundStyle(Paper.inkSoft)
                    Text("Skip this Puzzle — \(model.run.skipsRemaining) of 2 left this Book")
                        .font(Print.caption(12)).foregroundStyle(Paper.inkFaint)
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 4).fill(Paper.pageWarm))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Paper.rule, lineWidth: 1))
            } else if model.run.slot == .boss {
                Text("Boss Puzzles must be played.")
                    .font(Print.body(15)).foregroundStyle(Paper.inkSoft)
            } else {
                Text("Both Clippings have been used for this Book.")
                    .font(Print.body(15)).foregroundStyle(Paper.inkSoft)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                if model.run.currentClipping != nil {
                    PaperButton(title: "Take Clipping", kind: .quiet) { model.skipCurrentPuzzle() }
                }
                PaperButton(title: "Play Puzzle", kind: .primary) { model.beginPuzzle() }
            }
            PageNumber(level: model.run.level, slot: model.run.slot.rawValue)
        }
    }
}
