import SwiftUI

/// Local decoration only. The shape receives no board, solution, Marker map,
/// selection or touch data: hidden ownership cannot influence its density.
struct BossFogLayer: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.bossMotionIsActive) private var presentationIsActive
    @Environment(\.bossEntranceIsDeferred) private var entranceIsDeferred
    @AppStorage(AppPreferences.Key.ambientMotion) private var ambientMotion = true
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var clock = BossMotionClock()
    var isActive = true
    var phaseOverride: Double? = nil
    var reduceMotionOverride: Bool? = nil
    var animatesEntrance = false
    var consumeEntrance: (() -> Bool)? = nil
    @State private var entranceResolved = false
    @State private var entranceProgress: Double = 1

    private var runs: Bool {
        Self.shouldAnimate(isActive: isActive, presented: presentationIsActive,
            sceneActive: scenePhase == .active, ambient: ambientMotion,
            reduced: reduceMotionOverride ?? reduceMotion, lowPower: lowPower)
            && phaseOverride == nil
    }

    static func shouldAnimate(isActive: Bool, presented: Bool, sceneActive: Bool,
                              ambient: Bool, reduced: Bool, lowPower: Bool) -> Bool {
        isActive && presented && sceneActive && ambient && !reduced && !lowPower
    }

    var body: some View {
        Group {
            if let phaseOverride {
                BossFogDrawing(elapsed: phaseOverride)
            } else if !runs {
                // A still composition also renders in frozen page snapshots
                // and ImageRenderer. Paused timelines can omit their content
                // from an offscreen render entirely.
                BossFogDrawing(elapsed: clock.elapsed(at: ProcessInfo.processInfo.systemUptime),
                               entrance: entranceProgress)
            } else {
                // Thirty local Canvas updates/sec; neither GameModel nor any
                // of the 81 cell views subscribes to this decorative clock.
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !runs)) { _ in
                    BossFogDrawing(elapsed: clock.elapsed(at: ProcessInfo.processInfo.systemUptime),
                                   entrance: entranceProgress)
                }
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: runs, initial: true) { _, active in
            clock.setRunning(active, at: ProcessInfo.processInfo.systemUptime)
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .task(id: FogEntranceRequest(canAnimate: runs,
                                    deferred: entranceIsDeferred && scenePhase != .background
                                        && !(reduceMotionOverride ?? reduceMotion))) {
            guard animatesEntrance, !entranceResolved else {
                if !runs { entranceProgress = 1 }
                return
            }
            if !runs, entranceIsDeferred, scenePhase != .background,
               !(reduceMotionOverride ?? reduceMotion) {
                entranceProgress = 0
                return
            }
            entranceResolved = true
            guard consumeEntrance?() ?? true, runs else { entranceProgress = 1; return }
            entranceProgress = 0
            await Task.yield()
            guard !Task.isCancelled else { entranceProgress = 1; return }
            withAnimation(.easeOut(duration: 0.65)) { entranceProgress = 1 }
        }
        .onDisappear {
            clock.setRunning(false, at: ProcessInfo.processInfo.systemUptime)
            if animatesEntrance { _ = consumeEntrance?() }
        }
    }
}

private struct FogEntranceRequest: Equatable {
    var canAnimate: Bool
    var deferred: Bool
}

/// Two irregular strata: a slow grey bank under a brighter, quicker ivory
/// wisp. Soft radial density extends across the centre, with denser edges.
/// Drawing below the cell glyphs keeps numeral ink and selection perfectly crisp.
struct BossFogDrawing: View {
    var elapsed: Double
    var entrance: Double = 1

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            guard side > 0 else { return }
            let time = elapsed.isFinite ? max(0, elapsed) : 0
            for layer in 0..<2 {
                let slow = layer == 0
                let speed = slow ? 0.075 : -0.115
                let tone = slow ? Color(red: 0.62, green: 0.65, blue: 0.63)
                    : Color(red: 0.995, green: 0.987, blue: 0.95)
                let seeds: [(Double, Double, Double)] = slow
                    ? [(-0.06, 0.12, 0.40), (0.42, 0.25, 0.37), (0.91, 0.14, 0.39),
                       (0.16, 0.65, 0.36), (0.70, 0.61, 0.41), (1.03, 0.95, 0.38)]
                    : [(-0.08, 0.47, 0.33), (0.33, 0.10, 0.35), (0.79, 0.42, 0.38),
                       (0.30, 0.78, 0.43), (0.83, 0.97, 0.38), (0.56, 0.51, 0.27)]
                for (index, seed) in seeds.enumerated() {
                    let phase = time * speed + Double(index) * 1.71
                    let driftX = sin(phase) * (slow ? 0.055 : 0.085)
                    let driftY = cos(phase * 0.73) * 0.055
                    let roll = (1 - max(0, min(1, entrance))) * (slow ? -0.68 : 0.68)
                    let center = CGPoint(x: side * (seed.0 + driftX + roll),
                                         y: side * (seed.1 + driftY))
                    let radius = side * seed.2
                    let alpha = (slow ? 0.34 : 0.77) * (0.91 + 0.09 * sin(phase * 1.23))
                    var wisp = context
                    wisp.translateBy(x: center.x, y: center.y)
                    wisp.scaleBy(x: 1, y: 0.70)
                    let oval = CGRect(x: -radius, y: -radius,
                                      width: radius * 2, height: radius * 2)
                    wisp.fill(Path(ellipseIn: oval), with: .radialGradient(
                        Gradient(stops: [.init(color: tone.opacity(alpha), location: 0),
                                         .init(color: tone.opacity(alpha * 0.64), location: 0.42),
                                         .init(color: tone.opacity(alpha * 0.17), location: 0.76),
                                         .init(color: tone.opacity(0), location: 1)]),
                        center: .zero, startRadius: 0, endRadius: radius))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
