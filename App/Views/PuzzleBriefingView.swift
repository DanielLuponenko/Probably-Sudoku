import SwiftUI
import ProbablySudokuEngine

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

            LevelPuzzlePlan(currentSlot: model.run.slot)

            if let clipping = model.run.currentClipping {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CLIPPING ON OFFER")
                        .font(Print.caption(11)).tracking(1.3)
                        .foregroundStyle(Paper.redPencil)
                    Text(clipping.name).font(Print.subheading(22)).foregroundStyle(Paper.ink)
                    Text(clipping.detail).font(Print.body(14)).foregroundStyle(Paper.inkSoft)
                    Text("Skip this Puzzle — \(model.run.skipsRemaining) of 2 Clippings left this Book")
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
                    PaperButton(title: "Skip + reward", kind: .quiet) { model.skipCurrentPuzzle() }
                }
                PaperButton(title: "Play Puzzle", kind: .primary) { model.beginPuzzle() }
            }
            PageNumber(level: model.run.level, slot: model.run.slot.rawValue)
        }
    }
}

/// The three commitments in a Level are shown before the player begins the
/// current one. Progress only moves left to right: normal Puzzles can offer a
/// Clipping, while the Boss is visibly mandatory and has no skip path.
private struct LevelPuzzlePlan: View {
    var currentSlot: PuzzleSlot

    var body: some View {
        HStack(spacing: 8) {
            ForEach(PuzzleSlot.allCases, id: \.rawValue) { slot in
                let isCurrent = slot == currentSlot
                let isPassed = slot.rawValue < currentSlot.rawValue
                VStack(alignment: .leading, spacing: 4) {
                    Text(slot == .boss ? "BOSS" : "PUZZLE \(slot.rawValue + 1)")
                        .font(Print.caption(9.5))
                        .tracking(0.8)
                        .foregroundStyle(isCurrent ? Paper.page : Paper.inkFaint)
                    Text(slotTitle(slot))
                        .font(Print.subheading(14))
                        .foregroundStyle(isCurrent ? Paper.page : Paper.ink)
                    Text(status(for: slot, current: isCurrent, passed: isPassed))
                        .font(Print.caption(9.5))
                        .foregroundStyle(isCurrent ? Paper.page.opacity(0.78) : Paper.inkSoft)
                }
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .padding(8)
                .background(isCurrent ? Paper.ink : Paper.pageWarm,
                            in: RoundedRectangle(cornerRadius: 4))
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(slot == .boss ? Paper.redPencil.opacity(0.65) : Paper.rule,
                                      lineWidth: slot == .boss ? 1.4 : 1)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .accessibilityLabel("Level plan")
    }

    private func slotTitle(_ slot: PuzzleSlot) -> String {
        switch slot {
        case .easy: "Opening"
        case .medium: "Middle"
        case .boss: "Finale"
        }
    }

    private func status(for slot: PuzzleSlot, current: Bool, passed: Bool) -> String {
        if passed { return "Complete or skipped" }
        if current { return slot == .boss ? "Must play" : "Choose now" }
        return slot == .boss ? "Must play" : "Up next"
    }
}
