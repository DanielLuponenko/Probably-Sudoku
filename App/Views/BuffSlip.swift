import SwiftUI
import ProbablySudokuEngine

/// §12 — a Buff is one-shot and consumed on use, so spending one should be a
/// decision rather than a tap that makes an icon vanish. This says what it
/// does, and asks for the number when the Buff needs one.
struct BuffSlip: View {
    @Bindable var model: GameModel
    var index: Int
    var onDone: () -> Void

    @State private var chosen: Digit?
    @State private var useError: String?

    private var buff: OwnedBuff? {
        model.run.buffs.indices.contains(index) ? model.run.buffs[index] : nil
    }
    /// Paper Crane is the only Buff that asks you to pick a number.
    private var needsDigit: Bool { buff?.defID == Buffs.paperCrane }
    private var canUse: Bool { !needsDigit || chosen != nil }

    var body: some View {
        PaperSlip(
            title: buff?.def.name ?? "Buff",
            subtitle: buff?.def.text,
            closeLabel: "Keep it",
            dismissesOnBackground: false,
            onClose: onDone
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if needsDigit {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose a number")
                            .font(Print.caption(10)).tracking(1.6).textCase(.uppercase)
                            .foregroundStyle(Paper.inkSoft)

                        // Offered from the Hand, since that is what is in front
                        // of the player; the bonus lasts the rest of the Puzzle
                        // whether or not that number is still held.
                        let numbers = Array(Set(model.hand)).sorted()
                        if numbers.isEmpty {
                            Text("Nothing in hand to choose from.")
                                .font(Print.body(12.5))
                                .foregroundStyle(Paper.inkFaint)
                        } else {
                            HStack(spacing: 7) {
                                ForEach(numbers, id: \.self) { digit in
                                    Button {
                                        withAnimation(.snappy(duration: 0.15)) { chosen = digit }
                                    } label: {
                                        Text("\(digit.rawValue)")
                                            .font(Print.numeral(22, weight: .medium))
                                            .foregroundStyle(Paper.ink)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 46)
                                            .background {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(chosen == digit ? Paper.cellSelected
                                                                          : Paper.pageWarm)
                                            }
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .strokeBorder(chosen == digit ? Paper.sageDeep
                                                                                  : Paper.rule,
                                                                  lineWidth: chosen == digit ? 2 : 1)
                                            }
                                    }
                                    .buttonStyle(PressedPaperStyle())
                                    .accessibilityLabel("Number \(digit.rawValue)")
                                    .accessibilityAddTraits(chosen == digit ? [.isSelected] : [])
                                }
                            }
                        }
                    }
                }

                Text("Using it spends it.")
                    .font(Print.body(12))
                    .foregroundStyle(Paper.inkFaint)

                if let useError {
                    Text(useError)
                        .font(Print.body(12))
                        .foregroundStyle(Paper.redPencil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PaperButton(title: "Use", kind: .primary, isEnabled: canUse) {
                    if model.useBuff(at: index, digit: chosen) {
                        onDone()
                    } else {
                        useError = model.message
                    }
                }
            }
        }
    }
}
