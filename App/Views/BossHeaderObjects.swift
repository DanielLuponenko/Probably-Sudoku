import SwiftUI
import ProbablySudokuEngine

/// Physical rule objects fit in the existing boss-header allocation.
struct BossInkPadStatus: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.bossMotionIsActive) private var presented
    @Environment(\.scenePhase) private var scenePhase
    let ready: Bool
    @State private var pulse = 0

    private var canAnimate: Bool { !reduceMotion && presented && scenePhase == .active }

    var body: some View {
        ZStack {
            Canvas { context, size in
                let outer = CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2)
                let inset = outer.insetBy(dx: 4, dy: 4)
                context.fill(Path(roundedRect: outer.offsetBy(dx: 0, dy: 1), cornerRadius: 5),
                             with: .color(Color(hex: 0x766444)))
                context.fill(Path(roundedRect: outer, cornerRadius: 5),
                             with: .linearGradient(Gradient(colors: [Color(hex: 0xC7B78F), Color(hex: 0x95805A)]),
                                                   startPoint: outer.origin,
                                                   endPoint: CGPoint(x: outer.maxX, y: outer.maxY)))
                context.fill(Path(roundedRect: inset, cornerRadius: 2),
                             with: .linearGradient(Gradient(colors: ready
                                ? [Color(hex: 0x537263), Color(hex: 0x192F25)]
                                : [Color(hex: 0xD2C6AE), Color(hex: 0xB6A88E)]),
                                startPoint: inset.origin, endPoint: CGPoint(x: inset.maxX, y: inset.maxY)))
                if ready {
                    // A wet edge and a soft reflected streak distinguish an
                    // inked felt pad without depending on a colour change.
                    var gloss = Path()
                    gloss.move(to: CGPoint(x: inset.minX + 3, y: inset.minY + 2))
                    gloss.addQuadCurve(to: CGPoint(x: inset.maxX - 5, y: inset.minY + 3),
                                       control: CGPoint(x: inset.midX, y: inset.minY - 1))
                    context.stroke(gloss, with: .color(.white.opacity(0.45)),
                                   style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
                } else {
                    for i in 0..<7 {
                        let x = inset.minX + CGFloat(i) * inset.width / 7
                        var crack = Path()
                        crack.move(to: CGPoint(x: x, y: inset.minY + 2))
                        crack.addLine(to: CGPoint(x: x + 3, y: inset.midY))
                        crack.addLine(to: CGPoint(x: x + 1, y: inset.maxY - 2))
                        context.stroke(crack, with: .color(Color(hex: 0x8A7C62).opacity(0.4)), lineWidth: 0.8)
                    }
                }
            }
            HStack(spacing: 5) {
                Image(systemName: ready ? "drop.fill" : "drop")
                    .font(.system(size: 15, weight: .semibold))
                    .overlay {
                        if !ready {
                            Rectangle().fill(GameplaySurface.ink.opacity(0.75))
                                .frame(width: 18, height: 1.6).rotationEffect(.degrees(-40))
                        }
                    }
                Text(ready ? "INKED" : "DRY")
                    .font(.system(size: 13, weight: .heavy, design: .serif))
                    .tracking(0.7)
            }
            .foregroundStyle(ready ? GameplaySurface.ivory : GameplaySurface.ink)
            .padding(.horizontal, 10)
        }
        .frame(width: 105, height: 32)
        .shadow(color: .black.opacity(0.14), radius: 1, y: 1)
        .keyframeAnimator(initialValue: 1.0, trigger: pulse) { content, scale in
            content.scaleEffect(canAnimate ? scale : 1)
        } keyframes: { _ in
            CubicKeyframe(0.90, duration: 0.09)
            CubicKeyframe(1, duration: 0.20)
        }
        .animation(canAnimate ? .easeOut(duration: 0.25) : nil, value: ready)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ready ? "Inked. Marker placement bonus ready." : "Dry. Fill a plain square to re-ink.")
        .onChange(of: ready) { _, _ in if canAnimate { pulse += 1 } }
    }
}

struct BossReviewApprovalStatus: View {
    let approved: Set<BossReviewUnit>

    var body: some View {
        HStack(spacing: 5) {
            BossApprovalStamp(unit: .row, approved: approved.contains(.row))
            BossApprovalStamp(unit: .col, approved: approved.contains(.col))
            BossApprovalStamp(unit: .box, approved: approved.contains(.box))
        }
        .frame(maxWidth: 145)
        .frame(height: 34)
        .accessibilityElement(children: .combine)
    }
}

private struct BossApprovalStamp: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.bossMotionIsActive) private var presented
    @Environment(\.scenePhase) private var scenePhase
    let unit: BossReviewUnit
    let approved: Bool
    @State private var pulse = 0

    private var canAnimate: Bool { !reduceMotion && presented && scenePhase == .active }
    private var label: String {
        switch unit {
        case .row: "ROW"
        case .col: "COL"
        case .box: "BOX"
        }
    }

    var body: some View {
        VStack(spacing: 1) {
            Canvas { context, size in
                let side = min(size.width, size.height)
                let grid = CGRect(x: (size.width - side) / 2, y: 0, width: side, height: side)
                let cell = side / 3
                for row in 0..<3 {
                    for column in 0..<3 {
                        let active = unit == .box || (unit == .row && row == 1) || (unit == .col && column == 1)
                        let tile = CGRect(x: grid.minX + CGFloat(column) * cell + 0.45,
                                          y: CGFloat(row) * cell + 0.45,
                                          width: cell - 0.9, height: cell - 0.9)
                        context.fill(Path(roundedRect: tile, cornerRadius: 0.6),
                                     with: .color(active ? GameplaySurface.sage : GameplaySurface.sage.opacity(0.12)))
                    }
                }
            }
            .frame(height: 17)
            Text(label)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(0.3)
        }
        .foregroundStyle(GameplaySurface.ink)
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .background(approved ? Color(hex: 0xE0E8D9) : GameplaySurface.ivory,
                    in: RoundedRectangle(cornerRadius: 3))
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(approved ? GameplaySurface.sage : GameplaySurface.softInk.opacity(0.35),
                              lineWidth: approved ? 1.8 : 0.7)
        }
        .overlay(alignment: .topTrailing) {
            if approved {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(GameplaySurface.ivory)
                    .frame(width: 14, height: 14)
                    .background(GameplaySurface.sage, in: Circle())
                    .overlay(Circle().strokeBorder(GameplaySurface.ivory, lineWidth: 1))
                    .offset(x: 2, y: -2)
                    .transition(.scale(scale: 1.65).combined(with: .opacity))
            }
        }
        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
        .keyframeAnimator(initialValue: 1.0, trigger: pulse) { content, scale in
            content.scaleEffect(canAnimate ? scale : 1)
                .rotationEffect(.degrees(approved ? -2 : 0))
        } keyframes: { _ in
            CubicKeyframe(0.90, duration: 0.08)
            CubicKeyframe(1, duration: 0.19)
        }
        .animation(canAnimate ? .easeOut(duration: 0.22) : nil, value: approved)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(unit == .col ? "Column" : unit == .row ? "Row" : "Box") \(approved ? "approved" : "needed")")
        .onChange(of: approved) { old, new in if !old, new, canAnimate { pulse += 1 } }
    }
}

/// Each impression is tied to an actual charged placement, including a wrong
/// placement. The operation ID, not the changing preview score, drives it.
struct BossCoinTollStatus: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.bossMotionIsActive) private var presented
    @Environment(\.scenePhase) private var scenePhase
    let chargeID: String?
    let chargedThisTurn: Int
    @State private var coinBeat = 0

    private var canAnimate: Bool { !reduceMotion && presented && scenePhase == .active }

    var body: some View {
        HStack(spacing: 5) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LinearGradient(colors: [Color(hex: 0xB7A78A), Color(hex: 0x7C705B)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 29, height: 18)
                Capsule().fill(Color(hex: 0x292B24)).frame(width: 19, height: 3).offset(y: -14)
                Circle().fill(LinearGradient(colors: [Paper.coin, Paper.coinRim], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Circle().strokeBorder(Paper.coinRim, lineWidth: 1))
                    .overlay(Text("N").font(Print.subheading(10)).foregroundStyle(GameplaySurface.ink))
                    .frame(width: 18, height: 18).offset(y: -15)
                    .keyframeAnimator(initialValue: 0.0, trigger: coinBeat) { coin, drop in
                        coin.offset(y: canAnimate ? drop : 0)
                            .rotation3DEffect(.degrees(canAnimate ? drop * 5 : 0), axis: (x: 0, y: 1, z: 0))
                            .opacity(canAnimate ? max(0, 1 - drop / 18) : 1)
                    } keyframes: { _ in
                        CubicKeyframe(-3, duration: 0.08)
                        CubicKeyframe(18, duration: 0.18)
                        CubicKeyframe(18, duration: 0.10)
                        CubicKeyframe(0, duration: 0.16)
                    }
            }
            .frame(width: 34, height: 36)
            VStack(alignment: .trailing, spacing: 1) {
                Text("−1 coin / fill").font(Print.subheading(12))
                Text("\(chargedThisTurn) charged this turn").font(Print.caption(9))
                    .foregroundStyle(GameplaySurface.softInk)
            }
        }
        .frame(height: 37)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Every placement costs one coin, correct or wrong. \(chargedThisTurn) charged this turn.")
        .onChange(of: chargeID) { _, new in if new != nil, canAnimate { coinBeat += 1 } }
    }
}

struct BossRoyaltySeals: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.bossMotionIsActive) private var presented
    @Environment(\.scenePhase) private var scenePhase
    let signed: Int
    let nextCost: Int

    private var canAnimate: Bool { !reduceMotion && presented && scenePhase == .active }

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: 2).fill(GameplaySurface.ivory)
                            .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Paper.coinRim.opacity(0.6), lineWidth: 0.7))
                        VStack(spacing: 3) {
                            Capsule().fill(GameplaySurface.softInk.opacity(0.25)).frame(width: 11, height: 1)
                            Capsule().fill(GameplaySurface.softInk.opacity(0.25)).frame(width: 8, height: 1)
                        }
                        if index < signed {
                            EncounterWaxSeal(label: "✓", color: Paper.redPencil)
                                .frame(width: 18, height: 18).offset(y: 2)
                                .transition(.scale(scale: 1.6).combined(with: .opacity))
                        }
                    }
                    .frame(width: 21, height: 29)
                    .rotationEffect(.degrees(index < signed ? (index.isMultiple(of: 2) ? -3 : 3) : 0))
                }
            }
            VStack(alignment: .trailing, spacing: 1) {
                Text(nextCost > 0 ? "+\(nextCost.formatted())" : "SEALED")
                    .font(Print.numeral(13, weight: .bold)).foregroundStyle(nextCost > 0 ? Paper.redPencil : GameplaySurface.sage)
                Text(nextCost > 0 ? "target / Buff" : "Target fixed")
                    .font(Print.caption(9)).foregroundStyle(GameplaySurface.softInk)
            }
            .lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(height: 36)
        .animation(canAnimate ? .spring(response: 0.24, dampingFraction: 0.8) : nil, value: signed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(signed) of 3 royalty seals. " + (nextCost > 0 ? "Next Buff adds \(nextCost) to the target." : "No further target increases."))
    }
}

struct BossSleepingCopyStatus: View {
    let slot: Int?

    var body: some View {
        HStack(spacing: 7) {
            ZStack {
                RoundedRectangle(cornerRadius: 3).fill(GameplaySurface.ivory)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(GameplaySurface.softInk.opacity(0.6), lineWidth: 1))
                Text(slot.map { "\($0 + 1)" } ?? "—")
                    .font(Print.numeral(20, weight: .bold)).foregroundStyle(GameplaySurface.softInk)
                BossSleepingBookmarkSeal().offset(y: 11)
            }
            .frame(width: 28, height: 31).rotationEffect(.degrees(-5))
            VStack(alignment: .trailing, spacing: 1) {
                Text(slot.map { "Slot \($0 + 1) sleeps" } ?? "No copy asleep")
                    .font(Print.subheading(12)).lineLimit(1).minimumScaleFactor(0.8)
                Text("Passive upgrades stay")
                    .font(Print.caption(9)).foregroundStyle(GameplaySurface.softInk)
            }
        }
        .frame(height: 38)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(slot.map { "Bookmark in slot \($0 + 1) sleeps this turn. Its triggered effects are disabled; passive upgrades stay active." } ?? "No Bookmark asleep this turn.")
    }
}

/// The erased receipt sits off the board. Its stamp confirms an actual
/// suppressed clear; it never obscures the now-filled Sudoku unit.
struct BossMirrorReceipt: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.bossMotionIsActive) private var presented
    @Environment(\.scenePhase) private var scenePhase
    let clearID: String?
    @State private var stampBeat = 0

    private var canAnimate: Bool { !reduceMotion && presented && scenePhase == .active }

    var body: some View {
        HStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 2).fill(GameplaySurface.ivory)
                    .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(GameplaySurface.softInk.opacity(0.6), lineWidth: 0.8))
                    .rotationEffect(.degrees(4)).offset(x: 2, y: 1)
                VStack(spacing: 2) {
                    Text("LINE").font(Print.caption(8)).tracking(0.8)
                    Text("0").font(Print.numeral(20, weight: .bold))
                }
                .foregroundStyle(Paper.redPencil)
                .frame(width: 35, height: 31)
                .background(GameplaySurface.ivory, in: RoundedRectangle(cornerRadius: 2))
                .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Paper.redPencil, lineWidth: 1.2))
                .rotationEffect(.degrees(-4))
                .keyframeAnimator(initialValue: 1.0, trigger: stampBeat) { content, scale in
                    content.scaleEffect(canAnimate ? scale : 1)
                } keyframes: { _ in
                    CubicKeyframe(1.12, duration: 0.07)
                    CubicKeyframe(0.91, duration: 0.08)
                    CubicKeyframe(1, duration: 0.19)
                }
            }
            .frame(width: 39, height: 34)
            VStack(alignment: .trailing, spacing: 1) {
                Text("Line bonus: 0").font(Print.subheading(12))
                Text("Fills still score").font(Print.caption(9)).foregroundStyle(GameplaySurface.softInk)
            }
        }
        .frame(height: 36)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Line clear bonuses are zero. Correct placements still score.")
        .onChange(of: clearID) { _, new in if new != nil, canAnimate { stampBeat += 1 } }
    }
}

struct BossBinderyDirection: View {
    let pinned: Bool
    let reversed: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) {
                if pinned {
                    Image(systemName: "pin.fill").font(.system(size: 10))
                    Text(reversed ? "← READ" : "READ →").font(Print.subheading(12)).tracking(1)
                } else {
                    Image(systemName: "arrow.left.arrow.right").font(.system(size: 12))
                    Text("Arrange first").font(Print.subheading(12))
                }
            }
            .foregroundStyle(pinned ? GameplaySurface.sage : Paper.coinRim)
            Text(pinned ? "Bookmark order pinned" : "First action pins order")
                .font(Print.caption(10)).foregroundStyle(GameplaySurface.softInk)
        }
        .frame(height: 35)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pinned ? "Bookmark order pinned. This turn reads \(reversed ? "right to left" : "left to right")." : "Arrange Bookmarks before your first action. Their order will then be pinned for this puzzle.")
    }
}

struct BossPublicistPunchcard: View {
    let paid: Int

    var body: some View {
        HStack(spacing: 6) {
            VStack(spacing: 2) {
                Text("PAID").font(Print.caption(8)).tracking(0.8)
                Text("\(paid)").font(Print.numeral(18, weight: .bold))
            }
            .foregroundStyle(GameplaySurface.sage)
            .frame(width: 35, height: 31)
            .background(GameplaySurface.ivory, in: RoundedRectangle(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(GameplaySurface.sage, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
            VStack(alignment: .trailing, spacing: 1) {
                Text("One flat bonus").font(Print.subheading(12))
                Text("per Bookmark / turn").font(Print.caption(9)).foregroundStyle(GameplaySurface.softInk)
            }
        }
        .frame(height: 35)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(paid) Bookmark flat bonuses paid this turn. Each Bookmark pays its flat placement or line clear bonus once per turn; other effects stay active.")
    }
}
