import SwiftUI
import ProbablySudokuEngine

enum BossHandTreatment: Hashable {
    case none, queueFront, queueWaiting, bookend, lowBookend, highBookend, middle
    case printReady, repeatWaiting, packetOpen, packetWaiting(Int), sealed
    case zeroPoints, basePoints(Int)

    static func resolve(index: Int?, puzzle: PuzzleState?) -> Self {
        guard let p = puzzle, let index, p.hand.indices.contains(index) else { return .none }
        let released = BuffRuntime.releaseAllows(handIndex: index, puzzle: p)
        let blocked = p.isBlocked(handIndex: index) && !released
        // An Obstacle bar must not masquerade as a place in the queue or an
        // unopened packet. Preserve the ordinary crossed-card treatment.
        if p.isIndependentlyBlocked(handIndex: index), !released,
           p.boss != .returnSlip, p.boss != .handyDandy { return .none }
        switch p.boss {
        case .galleyQueue: return blocked ? .queueWaiting : .queueFront
        case .bookends:
            guard !blocked else { return .middle }
            let available = p.hand.indices.filter {
                !p.isIndependentlyBlocked(handIndex: $0) || BuffRuntime.releaseAllows(handIndex: $0, puzzle: p)
            }.map { p.hand[$0] }
            if available.min() == available.max() { return .bookend }
            if p.hand[index] == available.min() { return .lowBookend }
            if p.hand[index] == available.max() { return .highBookend }
            return .bookend // A Release Buff can also free a middle card.
        case .reprintBan:
            return blocked && p.bossState.usedDigits.contains(p.hand[index]) ? .repeatWaiting : .printReady
        case .collator:
            return blocked && p.bossState.waitingIDs.contains(p.handCards[index].id)
                ? .packetWaiting(min(2, p.bossState.correctFills)) : .packetOpen
        case .returnSlip, .handyDandy:
            return p.isTossBlocked(handIndex: index) && blocked ? .sealed : .none
        case .censor: return p.phase == .playing && p.hand[index] == p.censoredDigit ? .zeroPoints : .none
        case .backPage: return p.phase == .playing ? .basePoints(BossScoring.naturalBase(digit: p.hand[index], puzzle: p)) : .none
        default: return .none
        }
    }

    var isWaiting: Bool {
        switch self {
        case .queueWaiting, .middle, .repeatWaiting, .packetWaiting, .sealed: true
        default: false
        }
    }

    var isBookend: Bool {
        switch self {
        case .bookend, .lowBookend, .highBookend: true
        default: false
        }
    }

    var isReady: Bool {
        switch self {
        case .queueFront, .bookend, .lowBookend, .highBookend, .printReady, .packetOpen: true
        default: false
        }
    }

    var accessibilityStatus: String? {
        switch self {
        case .none: nil
        case .queueFront: "At the front of the queue, ready to play"
        case .queueWaiting: "Waiting behind the two oldest available cards"
        case .bookend: "Ready to play"
        case .lowBookend: "Lowest available number, ready to play"
        case .highBookend: "Highest available number, ready to play"
        case .middle: "Between the bookends, waiting"
        case .printReady: "Ready to print"
        case .repeatWaiting: "Already used this turn; play an unused number first"
        case .packetOpen: "Open packet, ready to play"
        case .packetWaiting(let fills): "Sealed packet, \(fills) of 2 correct fills"
        case .sealed: "Sealed until next turn"
        case .zeroPoints: "Censored number, no placement points; still playable"
        case .basePoints(let points): "\(points) natural placement points before modifiers"
        }
    }
}

/// The boss acts on the card itself: a waiting sleeve, a ready tray, a heavy
/// bookend or a red USED stamp. The number's centre stays completely clear.
struct BossHandTreatmentView: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.bossMotionIsActive) private var presented
    @Environment(\.scenePhase) private var scenePhase
    let treatment: BossHandTreatment

    private let brass = Color(red: 0.62, green: 0.46, blue: 0.22)
    private let sleeve = Color(red: 0.77, green: 0.73, blue: 0.64)
    private var canAnimate: Bool { !reduceMotion && presented && scenePhase == .active }

    var body: some View {
        GeometryReader { proxy in
            let bandHeight = min(16, max(12, proxy.size.height * 0.27))
            ZStack(alignment: .bottom) {
                if treatment != .none {
                    if treatment.isBookend {
                        bookendPosts
                            .transition(.scale(scale: 1.10).combined(with: .opacity))
                    } else if treatment == .queueFront {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(GameplaySurface.sage, lineWidth: 2.5)
                    } else if treatment.isWaiting {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(treatment == .repeatWaiting ? Paper.redPencil : sleeve, lineWidth: 2)
                    }

                    band(width: proxy.size.width)
                        .frame(maxWidth: .infinity)
                        .frame(height: bandHeight)
                        .background(bandFill)
                        .overlay(alignment: .top) {
                            Rectangle().fill(.white.opacity(treatment.isReady ? 0.30 : 0.55)).frame(height: 1)
                        }
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 4,
                                                         bottomTrailingRadius: 4, topTrailingRadius: 0))
                        .shadow(color: .black.opacity(0.10), radius: 1, y: -1)
                        .padding(.horizontal, 1)
                        .padding(.bottom, 1)
                        .id(treatment)
                        .transition(.asymmetric(insertion: .offset(y: 12).combined(with: .opacity),
                                                removal: .offset(y: 18).combined(with: .opacity)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .clipped()
        }
        .animation(canAnimate ? .spring(response: 0.38, dampingFraction: 0.8) : nil, value: treatment)
        .allowsHitTesting(false).accessibilityHidden(true)
    }

    private var bandFill: Color {
        if treatment.isBookend { return brass }
        if treatment.isReady { return GameplaySurface.sage }
        if treatment == .repeatWaiting || treatment == .sealed { return Paper.redPencil }
        if treatment == .zeroPoints { return GameplaySurface.ink }
        if case .basePoints = treatment { return GameplaySurface.sage }
        return sleeve
    }

    private var bookendPosts: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [brass.opacity(0.65), brass, brass.opacity(0.75)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 4)
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(colors: [brass.opacity(0.75), brass, brass.opacity(0.65)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(width: 4)
        }
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    @ViewBuilder private func band(width: CGFloat) -> some View {
        HStack(spacing: 2) {
            switch treatment {
            case .none: EmptyView()
            case .queueFront, .printReady, .packetOpen, .bookend:
                Image(systemName: "checkmark").font(.system(size: 7, weight: .black))
                Text("PLAY")
            case .lowBookend:
                Image(systemName: "arrow.down").font(.system(size: 7, weight: .black))
                Text("LOW")
            case .highBookend:
                Text("HIGH")
                Image(systemName: "arrow.up").font(.system(size: 7, weight: .black))
            case .queueWaiting, .middle:
                Image(systemName: "lock.fill").font(.system(size: 7, weight: .bold))
                Text("WAIT")
            case .repeatWaiting:
                Image(systemName: "lock.fill").font(.system(size: 7, weight: .bold))
                Text("USED")
            case .packetWaiting(let fills):
                Image(systemName: "lock.fill").font(.system(size: 7, weight: .bold))
                ForEach(0..<2, id: \.self) { dot in
                    Circle().fill(dot < fills ? GameplaySurface.ink : .clear)
                        .overlay(Circle().stroke(GameplaySurface.ink, lineWidth: 1))
                        .frame(width: 5, height: 5)
                }
            case .sealed:
                Text("SEALED")
            case .zeroPoints:
                Text("0 pts")
            case .basePoints(let points):
                Text("\(points) pts")
            }
        }
        .font(.system(size: min(10, width * 0.20), weight: .heavy, design: .rounded))
        .foregroundStyle(treatment == .queueWaiting || treatment == .middle || isPacketWaiting
                         ? GameplaySurface.ink : GameplaySurface.ivory)
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .padding(.horizontal, 3)
    }

    private var isPacketWaiting: Bool {
        if case .packetWaiting = treatment { return true }
        return false
    }
}
