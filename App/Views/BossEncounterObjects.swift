import SwiftUI

/// Encounter controls occupy the existing boss header. They only send an
/// explicit choice to the model; settling an animation never performs an action.
struct BossCollateralEnvelope: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.bossMotionIsActive) private var presented
    @Environment(\.scenePhase) private var scenePhase
    let selectedDigit: Int?
    let pledgedDigit: Int?
    let multBonus: Int
    let canPledge: Bool
    var isPreparationOpen = true
    let pledge: () -> Void
    @State private var sealBeat = 0

    private var canAnimate: Bool { !reduceMotion && presented && scenePhase == .active }
    private var accessible: Bool { dynamicTypeSize.isAccessibilitySize }
    private var spokenLabel: String {
        if let pledgedDigit { return "\(pledgedDigit) pledged for plus \(multBonus) Mult. The same tile returns when you bank." }
        guard isPreparationOpen else { return "Pledging closed until the next turn." }
        guard let selectedDigit else { return "Select a hand tile to pledge for plus \(multBonus) Mult." }
        return canPledge ? "Pledge \(selectedDigit) for plus \(multBonus) Mult this turn."
            : "This tile cannot be pledged. Choose another hand tile."
    }

    var body: some View {
        Button(action: pledge) {
            HStack(spacing: 6) {
                ZStack {
                    if let digit = pledgedDigit ?? selectedDigit {
                        Text("\(digit)")
                            .font(Print.numeral(20, weight: .semibold))
                            .foregroundStyle(GameplaySurface.ink)
                            .frame(width: 23, height: 28)
                            .background(GameplaySurface.ivory, in: RoundedRectangle(cornerRadius: 3))
                            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Paper.coinRim.opacity(0.7), lineWidth: 0.7))
                            .rotationEffect(.degrees(pledgedDigit == nil ? -7 : 0))
                            .offset(y: pledgedDigit == nil ? -7 : -1)
                    }
                    CollateralEnvelopePaper(sealed: pledgedDigit != nil)
                        .frame(width: 45, height: 29).offset(y: 6)
                    if pledgedDigit != nil {
                        EncounterWaxSeal(label: "+\(multBonus)", color: Paper.redPencil)
                            .frame(width: 23, height: 23).offset(x: 11, y: 8)
                    }
                }
                .frame(width: 47, height: 41)
                .keyframeAnimator(initialValue: 0.0, trigger: sealBeat) { content, depression in
                    content.offset(y: canAnimate ? depression : 0)
                        .scaleEffect(canAnimate ? 1 - abs(depression) * 0.016 : 1)
                } keyframes: { _ in
                    CubicKeyframe(-3, duration: 0.08)
                    CubicKeyframe(3, duration: 0.10)
                    CubicKeyframe(0, duration: 0.24)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(pledgedDigit.map { "\($0) pledged" }
                         ?? selectedDigit.map { canPledge ? "Pledge \($0)" : (isPreparationOpen ? "Choose another" : "Next turn") }
                         ?? (isPreparationOpen ? "Pick a tile" : "Next turn"))
                        .font(Print.subheading(accessible ? min(16 * textScale, 22) : 12))
                        .lineLimit(1).minimumScaleFactor(accessible ? 1 : 0.8)
                    Text(pledgedDigit == nil ? "+\(multBonus) Mult" : "Returns at bank")
                        .font(Print.caption(accessible ? min(14 * textScale, 18) : 10))
                        .lineLimit(1).minimumScaleFactor(accessible ? 1 : 0.8)
                        .foregroundStyle(pledgedDigit == nil ? GameplaySurface.sage : GameplaySurface.softInk)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 4)
            .frame(height: accessible ? 60 : 44)
            .background(GameplaySurface.ivory.opacity(0.7), in: RoundedRectangle(cornerRadius: 5))
            .overlay(RoundedRectangle(cornerRadius: 5)
                .strokeBorder(canPledge && selectedDigit != nil ? Paper.coinRim : GameplaySurface.softInk.opacity(0.25), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(EncounterChoiceButtonStyle())
        .disabled(!canPledge || selectedDigit == nil || pledgedDigit != nil)
        .foregroundStyle(GameplaySurface.ink)
        .animation(canAnimate ? .spring(response: 0.30, dampingFraction: 0.78) : nil, value: pledgedDigit)
        .accessibilityLabel(spokenLabel)
        .accessibilityHint(pledgedDigit == nil && canPledge ? "Choose before taking an action this turn." : "")
        .onChange(of: pledgedDigit) { old, new in
            if old == nil, new != nil, canAnimate { sealBeat += 1 }
        }
    }
}

private struct CollateralEnvelopePaper: View {
    let sealed: Bool

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(roundedRect: rect, cornerRadius: 2),
                         with: .linearGradient(Gradient(colors: [Color(hex: 0xEBDABB), Color(hex: 0xC5B18B)]),
                                               startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            context.stroke(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 2),
                           with: .color(Color(hex: 0x8C7753)), lineWidth: 0.8)
            var seams = Path()
            seams.move(to: CGPoint(x: 0, y: size.height))
            seams.addLine(to: CGPoint(x: size.width / 2, y: size.height * 0.38))
            seams.addLine(to: CGPoint(x: size.width, y: size.height))
            context.stroke(seams, with: .color(Color(hex: 0xAD9974)), lineWidth: 0.7)
            var flap = Path()
            flap.move(to: CGPoint(x: 0, y: 0))
            flap.addLine(to: CGPoint(x: size.width / 2, y: sealed ? size.height * 0.62 : size.height * 0.23))
            flap.addLine(to: CGPoint(x: size.width, y: 0))
            flap.closeSubpath()
            context.fill(flap, with: .color(Color(hex: 0xF2E5CF)))
            context.stroke(flap, with: .color(Color(hex: 0xAF9872)), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.14), radius: 1, y: 1)
        .accessibilityHidden(true)
    }
}

/// A/B are destinations, not separate scoring formulas. Targets may differ
/// by one point, so each stack receives its own authoritative target.
struct BossSplitEditionStacks: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.bossMotionIsActive) private var presented
    @Environment(\.scenePhase) private var scenePhase
    let scores: [Int]
    let targets: [Int]
    let selected: Int
    let canSelect: Bool
    let select: (Int) -> Void

    private var canAnimate: Bool { !reduceMotion && presented && scenePhase == .active }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { edition in
                let score = scores.indices.contains(edition) ? scores[edition] : 0
                let target = targets.indices.contains(edition) ? targets[edition] : 0
                Button { select(edition) } label: {
                    EditionStackPaper(edition: edition, score: score, target: target,
                                      selected: selected == edition, locked: !canSelect)
                        .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 60 : 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(EncounterChoiceButtonStyle())
                .disabled(!canSelect)
                .accessibilityLabel("Edition \(edition == 0 ? "A" : "B"), \(score) of \(target) points")
                .accessibilityValue(selected == edition ? "Selected" : "")
                .accessibilityHint(canSelect ? "Send this turn's score to this edition." : "Destination is fixed until the next turn.")
            }
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 60 : 44)
        .animation(canAnimate ? .spring(response: 0.30, dampingFraction: 0.76) : nil, value: selected)
        .animation(canAnimate ? .easeOut(duration: 0.28) : nil, value: scores)
    }
}

private struct EditionStackPaper: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.bossMotionIsActive) private var presented
    @Environment(\.scenePhase) private var scenePhase
    let edition: Int
    let score: Int
    let target: Int
    let selected: Bool
    let locked: Bool
    @State private var printBeat = 0

    private var complete: Bool { target > 0 && score >= target }
    private var ink: Color { complete ? GameplaySurface.sage : GameplaySurface.ink }
    private var canAnimate: Bool { !reduceMotion && presented && scenePhase == .active }
    private var accessible: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        VStack(spacing: 1) {
            HStack(spacing: 3) {
                Text(edition == 0 ? "A" : "B")
                    .font(Print.subheading(accessible ? min(14 * textScale, 20) : 11))
                Spacer(minLength: 0)
                Text(score.formatted())
                    .font(Print.numeral(accessible ? min(16 * textScale, 20) : 12, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(accessible ? 0.9 : 0.8)
            }
            Text("/ \(target.formatted())")
            .font(Print.caption(accessible ? min(12 * textScale, 18) : 9))
            .lineLimit(1).minimumScaleFactor(accessible ? 1 : 0.85)
            .frame(maxWidth: .infinity, alignment: .leading)
            GeometryReader { proxy in
                Capsule().fill(ink.opacity(0.12))
                    .overlay(alignment: .leading) {
                        Capsule().fill(complete ? GameplaySurface.sage : Paper.coinRim)
                            .frame(width: proxy.size.width * min(1, max(0, Double(score) / Double(max(1, target)))))
                    }
            }
            .frame(height: 3).padding(.top, 1)
        }
        .foregroundStyle(ink).padding(.horizontal, 5).padding(.vertical, 3)
        .frame(maxWidth: .infinity).frame(height: accessible ? 60 : 39)
        .background {
            ZStack {
                ForEach(1..<4, id: \.self) { layer in
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: 0xDBD0B9))
                        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(GameplaySurface.softInk.opacity(0.22), lineWidth: 0.5))
                        .offset(x: CGFloat(layer) * 0.6, y: CGFloat(layer))
                }
                RoundedRectangle(cornerRadius: 2).fill(GameplaySurface.ivory)
                    .overlay(RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(selected ? Paper.coinRim : GameplaySurface.softInk.opacity(0.35), lineWidth: selected ? 1.7 : 0.7))
            }
        }
        .overlay(alignment: .top) {
            if selected {
                Capsule().fill(LinearGradient(colors: [Color(hex: 0xD7BD73), Paper.coinRim], startPoint: .top, endPoint: .bottom))
                    .frame(width: 19, height: 4).offset(y: -1)
                    .overlay(alignment: .top) {
                        Image(systemName: complete ? "checkmark.seal.fill" : locked ? "pin.fill" : "arrow.down")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(complete ? GameplaySurface.sage : GameplaySurface.ink)
                            .offset(y: -4)
                    }
            } else if complete {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundStyle(GameplaySurface.sage)
                    .offset(y: -4)
            }
        }
        .keyframeAnimator(initialValue: 0.0, trigger: printBeat) { content, press in
            content.offset(y: canAnimate ? press : 0)
        } keyframes: { _ in
            CubicKeyframe(-4, duration: 0.08)
            CubicKeyframe(2, duration: 0.12)
            CubicKeyframe(0, duration: 0.22)
        }
        .onChange(of: score) { old, new in if new > old, canAnimate { printBeat += 1 } }
    }
}

/// One sheet, one impression. The press only moves for a real bank event;
/// changing a live score preview never spends or animates the only bank.
struct BossLastEditionPress: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.bossMotionIsActive) private var presented
    @Environment(\.scenePhase) private var scenePhase
    let banksRemaining: Int
    let pendingScore: Int
    var bankEventID: UUID?
    @State private var printBeat = 0

    private var canAnimate: Bool { !reduceMotion && presented && scenePhase == .active }

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                // The two rails and platen form a small physical press.
                HStack(spacing: 28) {
                    Capsule().fill(GameplaySurface.sage).frame(width: 4)
                    Capsule().fill(GameplaySurface.sage).frame(width: 4)
                }
                .frame(height: 34)
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2).fill(GameplaySurface.sage)
                        .frame(width: 40, height: 7)
                    Text(banksRemaining > 0 ? "1" : "—")
                        .font(Print.numeral(17, weight: .bold)).foregroundStyle(GameplaySurface.ink)
                        .frame(width: 27, height: 24)
                        .background(GameplaySurface.ivory, in: RoundedRectangle(cornerRadius: 1))
                    RoundedRectangle(cornerRadius: 1).fill(Color(hex: 0x8E7650)).frame(width: 42, height: 4)
                }
                .keyframeAnimator(initialValue: 0.0, trigger: printBeat) { content, press in
                    content.scaleEffect(y: canAnimate ? 1 - press * 0.15 : 1, anchor: .bottom)
                } keyframes: { _ in
                    CubicKeyframe(-0.3, duration: 0.12)
                    CubicKeyframe(1, duration: 0.12)
                    CubicKeyframe(1, duration: 0.12)
                    CubicKeyframe(0, duration: 0.28)
                }
                Capsule().fill(Paper.coinRim).frame(width: 19, height: 3)
                    .rotationEffect(.degrees(banksRemaining > 0 ? -35 : 25), anchor: .leading)
                    .offset(x: 20, y: -9)
            }
            .frame(width: 48, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(banksRemaining > 0 ? "ONE BANK" : "PRINTED")
                    .font(Print.caption(dynamicTypeSize.isAccessibilitySize ? 16 : 10)).tracking(0.7)
                Text("\(pendingScore.formatted())")
                    .font(Print.numeral(dynamicTypeSize.isAccessibilitySize ? 22 : 17, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 0.8 : 0.65)
                    .contentTransition(.numericText())
            }
            .foregroundStyle(GameplaySurface.sage)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 60 : 44)
        .animation(canAnimate ? .spring(response: 0.35, dampingFraction: 0.7) : nil, value: banksRemaining)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(banksRemaining > 0 ? "One bank. Current score \(pendingScore)." : "Final edition printed. \(pendingScore) points.")
        .onChange(of: bankEventID) { _, new in if new != nil, canAnimate { printBeat += 1 } }
    }
}

/// A committed choice stays readable as live encounter status. Disabled
/// buttons keep their semantics without the standard style fading the score.
private struct EncounterChoiceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.82 : 1)
    }
}

struct EncounterWaxSeal: View {
    let label: String
    var color: Color = Paper.redPencil

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [color.opacity(0.8), color], startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: 1.5).padding(1)
            Circle().strokeBorder(Color.white.opacity(0.28), lineWidth: 0.7).padding(3)
            Text(label).font(.system(size: 10, weight: .black, design: .serif))
                .foregroundStyle(GameplaySurface.ivory).lineLimit(1).minimumScaleFactor(0.7)
                .padding(3)
        }
        .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
        .accessibilityHidden(true)
    }
}
