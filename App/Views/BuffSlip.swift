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
    private var isPeek: Bool { buff?.defID == Buffs.peek }
    private var bossBlockReason: String? {
        guard let buff else { return nil }
        if model.puzzle?.boss == .buffborger {
            return "The Fine Print seals Buffs for this Puzzle. Effects you already activated keep working."
        }
        if model.puzzle?.boss?.disablesClues == true,
           [Buffs.peek, Buffs.litmus, Buffs.foldTest].contains(buff.defID) {
            return "The Paywall seals this Clue effect. Keep this Buff for a later Puzzle."
        }
        return nil
    }
    private var repeatedEffect: ItemDef? {
        guard buff?.defID == Buffs.carbonReceipt,
              let id = model.puzzle?.buffState.lastEligibleUse else { return nil }
        return Catalog.item(id)
    }
    private var currentBuffIndex: Int? {
        guard let buff else { return nil }
        return InventorySale(buff: buff, index: index).resolvedIndex(in: model.run)
    }
    private var canUse: Bool {
        !wasUsed && currentBuffIndex != nil
            && (buff.map { BuffRuntime.canUse(buffID: $0.id, run: model.run) } ?? false)
    }

    var body: some View {
        PaperSlip(
            title: buff?.def.name ?? "Buff",
            subtitle: nil,
            closeLabel: "Keep it",
            dismissesOnBackground: false,
            maximumWidth: 480,
            fitsContent: true,
            footer: AnyView(useButton),
            onClose: onDone
        ) {
            VStack(alignment: .leading, spacing: 14) {
                if let buff {
                    BuffEffectPrint(definition: buff.def)
                    if let consequence = BossBuffRules.explanation(definition: buff.defID, puzzle: model.puzzle) {
                        Text(consequence)
                            .font(Print.body(15 * textScale))
                            .foregroundStyle(theme.paper.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("buff.bossConsequence")
                    }
                }

                if let repeatedEffect {
                    HStack(alignment: .top, spacing: 10) {
                        ItemArtwork(id: repeatedEffect.id, size: 38)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Repeats \(repeatedEffect.name)").font(Print.subheading(16 * textScale))
                            Text(CatalogueDetails.item(repeatedEffect.id)?.shortEffect ?? repeatedEffect.text)
                                .font(Print.body(15 * textScale)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if let bossBlockReason {
                    HStack(alignment: .top, spacing: 9) {
                        BossActionSeal().padding(.top, 3)
                        Text(bossBlockReason).font(Print.body(14 * textScale))
                            .foregroundStyle(theme.paper.ink).fixedSize(horizontal: false, vertical: true)
                    }
                } else if !canUse && !wasUsed {
                    Text("No eligible target right now. This Buff stays in your inventory.")
                        .font(Print.body(14 * textScale)).foregroundStyle(theme.paper.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if isPeek, bossBlockReason == nil {
                    Text("Choose a number from your hand next. Peek is spent only when it reveals a legal square.")
                        .font(Print.body(12 * textScale)).foregroundStyle(theme.paper.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let useError {
                    Text(useError)
                        .font(Print.body(12 * textScale))
                        .foregroundStyle(palette.resolved(for: theme.paper).danger)
                        .fixedSize(horizontal: false, vertical: true)
                }


            }
        }
    }
    private var useButton: some View {
        PaperButton(title: repeatedEffect.map { "Repeat \($0.name)" } ?? (isPeek ? "Choose number" : "Use"), kind: .primary, isEnabled: canUse) {
                    guard canUse, let currentBuffIndex else { return }
                    wasUsed = true
                    if model.useBuff(at: currentBuffIndex) {
                        onDone()
                    } else {
                        wasUsed = false
                        useError = model.message
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
                ItemArtwork(id: definition.id, size: 56)
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
