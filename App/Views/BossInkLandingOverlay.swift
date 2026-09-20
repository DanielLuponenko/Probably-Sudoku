import SwiftUI
import ProbablySudokuEngine

struct BossInkLandingEvent: Equatable {
    let id: UUID
    let squares: Set<Square>
}

private struct BossInkRequest: Equatable {
    let event: BossInkLandingEvent?
    let canAnimate: Bool
    let deferred: Bool
}

/// Saved fouls are the standing truth. Only a committed presentation receipt
/// can introduce a droplet; mounting a saved board never invents an impact.
struct BossInkLandingOverlay: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.bossMotionIsActive) private var presentationIsActive
    @Environment(\.bossEntranceIsDeferred) private var entranceIsDeferred
    let squares: Set<Square>
    let reduceMotion: Bool
    var event: BossInkLandingEvent? = nil
    var consumeEvent: ((UUID) -> Bool)? = nil
    var elapsedOverride: Double? = nil
    @State private var activeEvent: BossInkLandingEvent?
    @State private var trigger = false

    private var canAnimate: Bool {
        !reduceMotion && presentationIsActive && scenePhase == .active && elapsedOverride == nil
    }

    var body: some View {
        GeometryReader { proxy in
            let cell = min(proxy.size.width, proxy.size.height) / 9
            KeyframeAnimator(initialValue: 1.0, trigger: trigger) { elapsed in
                ZStack {
                    ForEach(squares.sorted(), id: \.index) { square in
                        let moving = canAnimate && activeEvent?.squares.contains(square) == true
                        BossInkDrawing(size: cell, squareIndex: square.index,
                                       elapsed: elapsedOverride ?? (moving ? elapsed : 1))
                            .position(x: (CGFloat(square.col) + 0.5) * cell,
                                      y: (CGFloat(square.row) + 0.5) * cell)
                    }
                }
            } keyframes: { _ in
                MoveKeyframe(0)
                LinearKeyframe(1, duration: 0.62)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onDisappear { if let event { _ = consumeEvent?(event.id) } }
        .task(id: BossInkRequest(event: event, canAnimate: canAnimate,
                                deferred: entranceIsDeferred)) {
            guard let event else { activeEvent = nil; return }
            if !canAnimate, entranceIsDeferred, scenePhase != .background, !reduceMotion { return }
            guard consumeEvent?(event.id) ?? true else { return }
            guard canAnimate else { activeEvent = nil; return }
            activeEvent = event
            await Task.yield()
            guard !Task.isCancelled else { activeEvent = nil; return }
            trigger.toggle()
        }
    }
}

/// Authored variations use only a public square index. The heavy liquid
/// spreads into an irregular inset pool, retaining a tiny wet highlight.
struct BossInkDrawing: View {
    let size: CGFloat
    let squareIndex: Int
    let elapsed: Double

    var body: some View {
        Canvas { context, _ in
            let fall = min(1, max(0, elapsed / 0.28))
            let spread = min(1, max(0, (elapsed - 0.24) / 0.45))
            let center = CGPoint(x: size / 2, y: size * 0.52)
            if fall < 1 {
                let radius = size * (0.065 + 0.035 * fall)
                let drop = CGRect(x: center.x - radius,
                                  y: center.y - size * 0.38 * (1 - fall * fall) - radius,
                                  width: radius * 2, height: radius * (3 - fall))
                context.fill(Path(ellipseIn: drop), with: .color(Color(hex: 0x192526)))
            }
            guard spread > 0 else { return }
            let scale = 0.17 + 0.83 * (1 - pow(1 - spread, 3))
            var pool = Path()
            let count = 32
            for index in 0...count {
                let angle = Double(index) * .pi * 2 / Double(count)
                let edge = 0.33 + 0.032 * sin(angle * 5 + Double(squareIndex))
                    + 0.02 * cos(angle * 9 + Double(squareIndex % 7))
                let point = CGPoint(x: center.x + cos(angle) * size * edge * scale,
                                    y: center.y + sin(angle) * size * edge * scale * 0.88)
                if index == 0 { pool.move(to: point) } else { pool.addLine(to: point) }
            }
            pool.closeSubpath()
            context.fill(pool, with: .radialGradient(
                Gradient(colors: [Color(hex: 0x384541), Color(hex: 0x1B2725), Color(hex: 0x101A18)]),
                center: CGPoint(x: center.x - size * 0.08, y: center.y - size * 0.10),
                startRadius: 0, endRadius: size * 0.38))
            context.stroke(pool, with: .color(.black.opacity(0.22)), lineWidth: size * 0.018)
            for index in 0..<4 {
                let angle = Double(index) * 1.55 + Double(squareIndex % 9) * 0.11
                let radius = size * (index.isMultiple(of: 2) ? 0.023 : 0.015) * scale
                let x = center.x + cos(angle) * size * 0.39 * scale
                let y = center.y + sin(angle) * size * 0.36 * scale
                context.fill(Path(ellipseIn: CGRect(x: x - radius, y: y - radius,
                                                    width: radius * 2, height: radius * 2)),
                             with: .color(Color(hex: 0x25312C).opacity(0.9)))
            }
            let shine = CGRect(x: size * 0.34, y: size * 0.32,
                               width: size * 0.15 * scale, height: size * 0.035 * scale)
            context.fill(Path(ellipseIn: shine), with: .color(.white.opacity(0.22 * spread)))
        }
        .frame(width: size, height: size)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
