import SwiftUI
import ProbablySudokuEngine

/// A physical change to the actual receipt. The printed before/after values
/// come from one committed operation; neither preview nor animation computes
/// or applies another score effect.
struct BossScoreReceipt: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.bossMotionIsActive) private var presented
    @Environment(\.scenePhase) private var scenePhase
    let operation: ScoreOperation
    var settlement: BossBankSettlement? = nil
    var fontSize: CGFloat = 13
    var consumeEvent: (() -> Bool)? = nil
    @State private var progress: Double = 1

    static func supports(_ operation: ScoreOperation, banked: Bool) -> Bool {
        if operation.kind == .zero {
            return operation.sourceID == "boss.censor" || operation.sourceID == "boss.mirror"
        }
        switch operation.sourceID {
        case "boss.sashimi": return banked && operation.kind == .multiplyMult
        case "boss.backPage": return operation.kind == .setBase
        case "boss.chainStitcher": return operation.kind == .multiplyPoints
        case "boss.wordCount": return operation.kind == .subtractPoints && operation.amount > 0
        case "boss.orphanLine": return banked && operation.kind == .subtractPoints
        case "boss.serialPublisher", "boss.rivalColumn": return banked && operation.kind == .settleBank
        default: return false
        }
    }

    private var before: String {
        ScorePerformance.number(operation.kind == .multiplyMult ? operation.before.mult : operation.before.points)
    }
    private var after: String {
        ScorePerformance.number(operation.kind == .multiplyMult ? operation.after.mult : operation.after.points)
    }

    private var effect: BossReceiptTreatment { BossReceiptTreatment(sourceID: operation.sourceID) }
    private var unit: String {
        operation.kind == .multiplyMult ? "Mult" : operation.kind == .settleBank ? "score" : "Points"
    }

    var body: some View {
        HStack(spacing: 5) {
            Text(operation.sourceName + " ·")
            Text(before)
                .strikethrough(effect == .stamp && progress > 0.3, color: Paper.redPencil)
                .foregroundStyle(GameplaySurface.softInk)
            Text("→")
                .accessibilityHidden(true)
            Text(after + " " + unit)
                .bold()
                .foregroundStyle(Paper.redPencil)
                .scaleEffect(effect == .stamp ? 1 + 0.17 * (1 - progress) : 1)
                .rotation3DEffect(.degrees(effect == .flip ? -70 * (1 - progress) : 0), axis: (x: 1, y: 0, z: 0))
                .rotationEffect(.degrees(effect == .stamp ? -3 * (1 - progress) : 0))
                .offset(y: effect == .tear ? 3 * (1 - progress) : effect == .stamp ? -3 * (1 - progress) : 0)
                .overlay(alignment: .bottom) {
                    BossReceiptStroke(treatment: effect, progress: progress)
                        .frame(height: 4)
                        .offset(y: 2)
                        .accessibilityHidden(true)
                }
            if effect == .band, let settlement, settlement.carryAfter > 0 {
                Text("\(settlement.carryAfter.formatted()) held")
                    .font(Print.caption(max(10, fontSize - 2)))
                    .foregroundStyle(GameplaySurface.sage)
            }
        }
        .font(Print.caption(fontSize))
        .foregroundStyle(GameplaySurface.ink)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(operation.sourceName), \(before) to \(after) \(unit)\(settlement.map { ", \($0.carryAfter) carried" } ?? "")")
        .task(id: operation.id) {
            guard consumeEvent?() ?? true, !reduceMotion, presented, scenePhase == .active else { progress = 1; return }
            progress = 0
            do { try await Task.sleep(for: .milliseconds(16)) } catch { progress = 1; return }
            guard !Task.isCancelled, !reduceMotion, presented, scenePhase == .active else { progress = 1; return }
            withAnimation(.easeOut(duration: 0.22)) { progress = 1 }
        }
        .onChange(of: presented) { _, active in if !active { progress = 1 } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { progress = 1 } }
        .onChange(of: reduceMotion) { _, reduced in if reduced { progress = 1 } }
    }
}

enum BossReceiptTreatment: Equatable {
    case stamp, flip, thread, measure, tear, band, underline

    init(sourceID: String) {
        switch sourceID {
        case "boss.backPage": self = .flip
        case "boss.chainStitcher": self = .thread
        case "boss.wordCount": self = .measure
        case "boss.orphanLine": self = .tear
        case "boss.serialPublisher": self = .band
        case "boss.rivalColumn": self = .underline
        case "boss.sashimi": self = .tear
        default: self = .stamp
        }
    }
}

private struct BossReceiptStroke: View {
    let treatment: BossReceiptTreatment
    let progress: Double

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let width = size.width * progress
            switch treatment {
            case .stamp, .flip: return
            case .thread:
                path.move(to: .zero)
                path.addCurve(to: CGPoint(x: width, y: 0),
                              control1: CGPoint(x: width * 0.33, y: 5),
                              control2: CGPoint(x: width * 0.66, y: -2))
            case .measure:
                path.move(to: .zero); path.addLine(to: CGPoint(x: width, y: 0))
                for tick in stride(from: CGFloat.zero, through: width, by: 6) {
                    path.move(to: CGPoint(x: tick, y: 0)); path.addLine(to: CGPoint(x: tick, y: 3))
                }
            case .tear:
                path.move(to: .zero)
                for tooth in stride(from: CGFloat.zero, through: width, by: 5) {
                    path.addLine(to: CGPoint(x: tooth + 2, y: 2))
                    path.addLine(to: CGPoint(x: min(width, tooth + 5), y: 0))
                }
            case .band:
                context.fill(Path(CGRect(x: 0, y: -1, width: width, height: 4)),
                             with: .color(GameplaySurface.sage.opacity(0.24)))
                return
            case .underline:
                path.move(to: .zero); path.addLine(to: CGPoint(x: width, y: 0))
            }
            context.stroke(path, with: .color(GameplaySurface.sage),
                           style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
        .allowsHitTesting(false)
    }
}
