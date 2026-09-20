import SwiftUI

/// A short object entrance, tied to a model-owned committed-event ledger.
/// Covering or discarding its page settles the cue rather than replaying it.
struct BossObjectArrival: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.bossMotionIsActive) private var presented
    @Environment(\.bossEntranceIsDeferred) private var deferred
    @Environment(\.gameReduceMotion) private var reduceMotion
    var eventKey: String?
    var consume: (String) -> Bool
    @State private var landed = true
    @State private var resolvedKey: String?

    private var request: String { "\(eventKey ?? "none"):\(presented):\(deferred):\(scenePhase == .active):\(reduceMotion)" }

    func body(content: Content) -> some View {
        content
            .offset(y: landed ? 0 : -6)
            .rotationEffect(.degrees(landed ? 0 : -5))
            .opacity(landed ? 1 : 0.2)
            .task(id: request) {
                guard let eventKey, resolvedKey != eventKey else { landed = true; return }
                if deferred, scenePhase != .background, !reduceMotion { landed = false; return }
                resolvedKey = eventKey
                guard consume(eventKey), !reduceMotion, presented, scenePhase == .active else {
                    landed = true; return
                }
                landed = false
                do { try await Task.sleep(for: .milliseconds(16)) } catch { landed = true; return }
                guard !Task.isCancelled, !reduceMotion, presented, scenePhase == .active else { landed = true; return }
                withAnimation(.easeOut(duration: 0.23)) { landed = true }
            }
            .onDisappear { if let eventKey { _ = consume(eventKey) } }
    }
}

struct BossFoldedCorner: View {
    var dark = false

    var body: some View {
        Canvas { context, size in
            var fold = Path()
            fold.move(to: .zero)
            fold.addLine(to: CGPoint(x: size.width, y: size.height))
            fold.addLine(to: CGPoint(x: 0, y: size.height))
            fold.closeSubpath()
            context.fill(fold, with: .linearGradient(Gradient(colors: dark
                ? [Color(hex: 0x8F8A75), Color(hex: 0x414C43)]
                : [Color(hex: 0xFFF9E8), Color(hex: 0xC4BDA8)]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            context.stroke(fold, with: .color(.black.opacity(0.26)), lineWidth: 0.7)
        }
        .frame(width: 15, height: 15)
        .shadow(color: .black.opacity(0.17), radius: 1, y: 1)
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct BossActionSeal: View {
    var dark = false

    var body: some View {
        ZStack {
            Rectangle().fill(Paper.pageWarm)
                .frame(width: 21, height: 7).rotationEffect(.degrees(-13))
                .overlay { Rectangle().strokeBorder(Paper.ink.opacity(0.2), lineWidth: 0.5)
                    .frame(width: 21, height: 7).rotationEffect(.degrees(-13)) }
            Circle().fill(dark ? Paper.pageWarm : GameplaySurface.sage)
                .frame(width: 13, height: 13)
            Image(systemName: "lock.fill").font(.system(size: 7, weight: .semibold))
                .foregroundStyle(dark ? GameplaySurface.ink : Paper.pageWarm)
        }
        .frame(width: 23, height: 16)
        .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// Applied only to the exact sleeping Bookmark. The band leaves its artwork
/// visible and says what the folded corner alone could not communicate.
struct BossSleepingBookmarkSeal: View {
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "moon.zzz.fill").font(.system(size: 7, weight: .semibold))
            Text("REST").font(.system(size: 8, weight: .heavy, design: .serif)).tracking(0.5)
        }
        .foregroundStyle(GameplaySurface.ivory)
        .padding(.horizontal, 4).frame(height: 13)
        .background(GameplaySurface.sage, in: RoundedRectangle(cornerRadius: 2))
        .overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(GameplaySurface.ivory.opacity(0.65), lineWidth: 0.6))
        .rotationEffect(.degrees(-4))
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct BossEditorFold: View {
    let handSize: Int

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(GameplaySurface.ivory)
                .overlay { RoundedRectangle(cornerRadius: 2).strokeBorder(GameplaySurface.softInk.opacity(0.5), lineWidth: 0.7) }
                .frame(width: 15, height: 19)
                .overlay(alignment: .topTrailing) { BossFoldedCorner().scaleEffect(0.75, anchor: .topTrailing) }
                .rotationEffect(.degrees(-10))
            Text("\(handSize) cards · one slot folded")
                .font(Print.caption(10)).foregroundStyle(GameplaySurface.softInk)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The Editor. Hand capacity \(handSize), one slot removed. No number removed from the Pool.")
    }
}

struct BossTurnCut: View {
    var body: some View {
        Canvas { context, size in
            var cut = Path()
            for x in stride(from: CGFloat.zero, through: size.width, by: 5) {
                cut.move(to: CGPoint(x: x, y: size.height / 2))
                cut.addLine(to: CGPoint(x: min(x + 3, size.width), y: size.height / 2))
            }
            context.stroke(cut, with: .color(Paper.redPencil.opacity(0.75)), lineWidth: 1)
        }
        .frame(width: 30, height: 8)
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct BossCrossedTossTab: View {
    var body: some View {
        Text("TOSS")
            .font(Print.caption(8))
            .tracking(1)
            .foregroundStyle(GameplaySurface.softInk)
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Paper.pageWarm)
            .overlay { Rectangle().fill(Paper.redPencil).frame(height: 1.2).rotationEffect(.degrees(-9)).padding(.horizontal, 2) }
            .rotationEffect(.degrees(-3))
            .shadow(color: Paper.ink.opacity(0.14), radius: 1, y: 1)
            .allowsHitTesting(false).accessibilityHidden(true)
    }
}
