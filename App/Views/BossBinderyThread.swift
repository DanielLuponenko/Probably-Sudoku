import SwiftUI

/// The pinned inventory's lower edge is stitched together. A small needle
/// follows actual Bookmark receipts in the engine's saved scoring order.
struct BossBinderyThread: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.bossMotionIsActive) private var presented
    @Environment(\.scenePhase) private var scenePhase
    let centers: [CGFloat]
    let activeSlot: Int?
    let beatID: UUID?
    var eventKey: String?
    var consumeEvent: (String) -> Bool
    @State private var needleX: CGFloat?
    @State private var passage = 0

    private var canAnimate: Bool { !reduceMotion && presented && scenePhase == .active }

    var body: some View {
        GeometryReader { proxy in
            let y = proxy.size.height - 5
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    guard let first = centers.first, let last = centers.last else { return }
                    var thread = Path()
                    thread.move(to: CGPoint(x: first - 5, y: y))
                    thread.addLine(to: CGPoint(x: last + 5, y: y))
                    for x in centers {
                        thread.addEllipse(in: CGRect(x: x - 3, y: y - 2, width: 6, height: 4))
                    }
                    context.stroke(thread, with: .color(Color(red: 0.50, green: 0.37, blue: 0.22)),
                                   style: StrokeStyle(lineWidth: 1.65, lineCap: .round))
                    context.stroke(thread, with: .color(Color(hex: 0xE0CA93).opacity(0.8)),
                                   style: StrokeStyle(lineWidth: 0.6, lineCap: .round, dash: [2, 3]))
                }
                .modifier(BossObjectArrival(eventKey: eventKey, consume: consumeEvent))
                if let needleX {
                    BossBinderyShuttle()
                        .frame(width: 18, height: 7)
                        .rotationEffect(.degrees(-18))
                        .keyframeAnimator(initialValue: 0.0, trigger: passage) { content, lift in
                            content.offset(y: canAnimate ? lift : 0)
                        } keyframes: { _ in
                            CubicKeyframe(-4, duration: 0.08)
                            CubicKeyframe(1, duration: 0.12)
                            CubicKeyframe(0, duration: 0.10)
                        }
                        .position(x: needleX, y: y)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: beatID) { _, id in
            guard presented, scenePhase == .active, let id, let activeSlot,
                  centers.indices.contains(activeSlot), consumeEvent("bindery-source:\(id)") else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                needleX = centers[activeSlot]
            }
            if canAnimate { passage += 1 }
        }
        .onChange(of: presented) { _, shown in if !shown { needleX = nil } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { needleX = nil } }
    }
}

private struct BossBinderyShuttle: View {
    var body: some View {
        Canvas { context, size in
            var body = Path()
            body.move(to: CGPoint(x: 0, y: size.height / 2))
            body.addQuadCurve(to: CGPoint(x: size.width, y: size.height / 2), control: CGPoint(x: size.width * 0.5, y: -2))
            body.addQuadCurve(to: CGPoint(x: 0, y: size.height / 2), control: CGPoint(x: size.width * 0.5, y: size.height + 2))
            context.fill(body, with: .linearGradient(Gradient(colors: [Color(hex: 0xE9D3A2), Color(hex: 0xA47B45)]),
                                                     startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            context.stroke(body, with: .color(Color(hex: 0x5F4C31)), lineWidth: 0.8)
            context.stroke(Path(ellipseIn: CGRect(x: size.width * 0.35, y: size.height * 0.3,
                                                  width: size.width * 0.3, height: size.height * 0.4)),
                           with: .color(Color(hex: 0x584B36)), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
    }
}
