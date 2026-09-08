import SwiftUI
import ProbablySudokuEngine

/// §12 — a Buff is one-shot and consumed on use, so spending one should be a
/// decision rather than a tap that makes an icon vanish. This says what it
/// does, and asks for the number when the Buff needs one.
struct BuffSlip: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.bookPresentation) private var bookTheme
    @Environment(\.levelPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    @Bindable var model: GameModel
    var index: Int
    var onDone: () -> Void

    @State private var chosen: Digit?
    @State private var useError: String?
    @State private var wasUsed = false

    // The consumed item leaves the inventory before its slip finishes fading.
    // Its printed metadata must stay on that outgoing slip, not become the
    // next inventory slot's name and instructions halfway through dismissal.
    @State private var buff: OwnedBuff?

    init(model: GameModel, index: Int, onDone: @escaping () -> Void) {
        self.model = model
        self.index = index
        self.onDone = onDone
        self._buff = State(initialValue: model.run.buffs.indices.contains(index)
                           ? model.run.buffs[index] : nil)
    }
    /// Paper Crane is the only Buff that asks you to pick a number.
    private var needsDigit: Bool { buff?.defID == Buffs.paperCrane }
    private var canUse: Bool {
        !wasUsed && buff != nil && model.run.buffs.indices.contains(index)
            && model.run.buffs[index].defID == buff?.defID
            && (!needsDigit || chosen != nil)
    }

    var body: some View {
        PaperSlip(
            title: buff?.def.name ?? "Buff",
            subtitle: nil,
            closeLabel: "Keep it",
            dismissesOnBackground: false,
            maximumWidth: 480,
            fitsContent: true,
            onClose: onDone
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if let buff {
                    BuffEffectPrint(definition: buff.def)
                }

                if needsDigit {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose a number")
                            .font(Print.caption(11 * textScale))
                            .foregroundStyle(theme.paper.softInk)

                        // Offered from the Hand, since that is what is in front
                        // of the player; the bonus lasts the rest of the Puzzle
                        // whether or not that number is still held.
                        let numbers = Array(Set(model.hand)).sorted()
                        if numbers.isEmpty {
                            Text("Nothing in hand to choose from.")
                                .font(Print.body(12.5 * textScale))
                                .foregroundStyle(theme.paper.faintInk)
                        } else {
                            // Nine distinct held numbers must not compress
                            // into nine tiny targets on a narrow phone.
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 7)],
                                      spacing: 7) {
                                ForEach(numbers, id: \.self) { digit in
                                    Button {
                                        withAnimation(.snappy(duration: 0.15)) { chosen = digit }
                                    } label: {
                                        Text("\(digit.rawValue)")
                                            .font(Print.numeral(22, weight: .medium))
                                            .foregroundStyle(theme.paper.ink)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 46)
                                            .background {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(chosen == digit
                                                          ? bookTheme.accent.opacity(0.16)
                                                          : theme.paper.warm)
                                            }
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .strokeBorder(chosen == digit
                                                                  ? bookTheme.quietInk(onDarkPaper: theme.paper.isDark)
                                                                  : theme.paper.ruleInk,
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

                Text("Use it now, or keep it for later. Using it spends this copy.")
                    .font(Print.body(12 * textScale))
                    .foregroundStyle(theme.paper.softInk)
                    .fixedSize(horizontal: false, vertical: true)

                if let useError {
                    Text(useError)
                        .font(Print.body(12 * textScale))
                        .foregroundStyle(palette.resolved(for: theme.paper).danger)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PaperButton(title: "Use", kind: .primary, isEnabled: canUse) {
                    guard canUse else { return }
                    wasUsed = true
                    if model.useBuff(at: index, digit: chosen) {
                        onDone()
                    } else {
                        wasUsed = false
                        useError = model.message
                    }
                }
            }
        }
    }
}

/// The same item illustration as its inventory tab, printed beside the real
/// rule text. Static ink and paper: no texture decoding or idle animation loop.
private struct BuffEffectPrint: View {
    let definition: ItemDef
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.bookPresentation) private var bookTheme
    @ScaledMetric(relativeTo: .body) private var copySize: CGFloat = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                PrintedItemIllustration {
                    Image(systemName: ItemIcon.symbol(for: definition.id))
                        .font(.system(size: 23, weight: .light))
                        .foregroundStyle(bookTheme.quietInk(onDarkPaper: theme.paper.isDark))
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(definition.text)
                        .font(Print.body(copySize))
                        .foregroundStyle(theme.paper.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("buff.effect")
                    RarityImprint(rarity: definition.rarity)
                }
            }

            Rectangle()
                .fill(theme.paper.ruleInk.opacity(0.65))
                .frame(height: 1)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }
}
