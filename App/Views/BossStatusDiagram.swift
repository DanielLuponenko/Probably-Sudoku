import SwiftUI
import ProbablySudokuEngine

/// Visible consequences before committing a turn. Every amount comes from
/// the same pure ledger preview used by the live score calculation.
struct BossStatusDiagram: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.bossMotionIsActive) private var presented
    @Environment(\.scenePhase) private var scenePhase
    let puzzle: PuzzleState

    static func supports(_ boss: BossModifier) -> Bool {
        [.serialPublisher, .rivalColumn, .wordCount, .pageCutter, .orphanLine,
         .accountant, .royaltyContract, .unluckyLucky, .mirror, .bindery, .publicist].contains(boss)
    }

    private var motion: Animation? {
        reduceMotion || !presented || scenePhase != .active ? nil : .easeOut(duration: 0.3)
    }

    var body: some View {
        Group {
            if puzzle.boss == .accountant {
                let costs = puzzle.turnScoringOperations.filter { $0.sourceID == "boss.accountant" && $0.kind == .coins }
                BossCoinTollStatus(chargeID: costs.last?.id, chargedThisTurn: costs.count)
            } else if puzzle.boss == .royaltyContract {
                BossRoyaltySeals(signed: puzzle.bossState.royaltyCount,
                                 nextCost: BossBuffRules.targetIncrease(puzzle: puzzle))
            } else if puzzle.phase == .keepFilling, puzzle.boss == .serialPublisher,
               puzzle.bossState.scoring.serialCarry > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    receipt(title: "HELD", value: puzzle.bossState.scoring.serialCarry,
                            ink: Paper.coinRim, stacked: true)
                    Text("Full Clear pays").font(Print.caption(10)).foregroundStyle(GameplaySurface.softInk)
                }
            } else if puzzle.phase != .playing {
                Text("Score frozen").font(Print.body(12)).foregroundStyle(GameplaySurface.softInk)
            } else {
                switch puzzle.boss {
                case .unluckyLucky:
                    BossSleepingCopyStatus(slot: puzzle.disabledBookmark)
                case .mirror:
                    BossMirrorReceipt(clearID: puzzle.turnScoringOperations.last { $0.sourceID == "boss.mirror" }?.id)
                case .bindery:
                    BossBinderyDirection(pinned: puzzle.bossState.scoring.binderyPinned,
                                         reversed: puzzle.turnNumber.isMultiple(of: 2))
                case .publicist:
                    BossPublicistPunchcard(paid: puzzle.bossState.scoring.publicistPaid.count)
                case .serialPublisher:
                    if let settlement = puzzle.pendingScoringLedger.bossSettlement {
                        HStack(spacing: 7) {
                            receipt(title: "BANK", value: settlement.paid, ink: GameplaySurface.sage)
                            receipt(title: "HOLD", value: settlement.carryAfter, ink: Paper.coinRim, stacked: true)
                        }
                        .accessibilityLabel("End Turn banks \(settlement.paid) score and holds \(settlement.carryAfter) for later turns.")
                    }
                case .rivalColumn:
                    if let settlement = puzzle.pendingScoringLedger.bossSettlement {
                        if let benchmark = settlement.benchmark {
                            VStack(alignment: .trailing, spacing: 3) {
                                HStack(spacing: 4) {
                                    Text("\(settlement.gross.formatted())").bold()
                                    Image(systemName: settlement.gross > benchmark ? "flag.checkered" : "arrow.up.right")
                                    Text("\(benchmark.formatted())")
                                }
                                .font(Print.numeral(14, weight: .medium))
                                .foregroundStyle(settlement.gross > benchmark ? GameplaySurface.sage : Paper.redPencil)
                                meter(fraction: Double(settlement.gross) / Double(max(1, benchmark + 1)),
                                      ink: settlement.gross > benchmark ? GameplaySurface.sage : Paper.redPencil)
                                Text(settlement.gross > benchmark ? "Now · Rival beaten" : "Now → Rival")
                                    .font(Print.caption(10)).foregroundStyle(GameplaySurface.softInk)
                            }
                            .accessibilityLabel("This bank \(settlement.gross). Rival \(benchmark). \(settlement.gross > benchmark ? "Rival beaten." : "Bank loses \(settlement.gross - settlement.paid) score unless you beat the rival.")")
                        } else {
                            Label("Set your first record", systemImage: "flag.checkered")
                                .font(Print.body(12)).foregroundStyle(GameplaySurface.softInk)
                        }
                    }
                case .wordCount:
                    let remaining = max(0, 150 - puzzle.bossState.scoring.wordCountSpent)
                    VStack(alignment: .trailing, spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: "printer.fill")
                            Text("\(remaining) / 150").monospacedDigit().bold()
                        }
                        .font(Print.numeral(14, weight: .medium)).foregroundStyle(GameplaySurface.sage)
                        meter(fraction: Double(remaining) / 150, ink: GameplaySurface.sage)
                        Text("Bonus points left").font(Print.caption(10)).foregroundStyle(GameplaySurface.softInk)
                    }
                    .accessibilityLabel("\(remaining) bonus placement points left this turn. Base points and clear bonuses are unchanged.")
                case .pageCutter:
                    VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 3) {
                        ForEach(0..<4, id: \.self) { index in
                            Text("\(index + 1)")
                                .font(Print.numeral(13, weight: .semibold))
                                .foregroundStyle(index < puzzle.bossState.correctFills ? GameplaySurface.ivory : GameplaySurface.ink)
                                .frame(width: 20, height: 22)
                                .background(index < puzzle.bossState.correctFills ? GameplaySurface.sage : GameplaySurface.ivory,
                                            in: RoundedRectangle(cornerRadius: 3))
                                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(GameplaySurface.sage, lineWidth: 1))
                        }
                        Image(systemName: "scissors").font(.system(size: 17)).foregroundStyle(Paper.redPencil)
                    }
                    Text("4 fills → bank").font(Print.caption(10)).foregroundStyle(GameplaySurface.softInk)
                    }
                    .accessibilityLabel("\(puzzle.bossState.correctFills) of 4 correct fills. The fourth automatically banks and ends the turn.")
                case .orphanLine:
                    HStack(spacing: 7) {
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 21)).foregroundStyle(Paper.coinRim)
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("−\(BossScoring.orphanDebit(puzzle)) pts").font(Print.numeral(16, weight: .semibold))
                                .foregroundStyle(Paper.redPencil)
                            Text("\(puzzle.hand.count) left at bank").font(Print.caption(10)).foregroundStyle(GameplaySurface.softInk)
                        }
                    }
                    .accessibilityLabel("Ending now loses \(BossScoring.orphanDebit(puzzle)) points before Mult with \(puzzle.hand.count) cards left.")
                default: EmptyView()
                }
            }
        }
        .contentTransition(.numericText())
        .animation(motion, value: puzzle.bossState.scoring)
        .animation(motion, value: puzzle.pendingBase)
        .animation(motion, value: puzzle.bossState.correctFills)
        .accessibilityElement(children: .combine)
    }

    private func meter(fraction: Double, ink: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(GameplaySurface.ink.opacity(0.12))
                Capsule().fill(ink).frame(width: proxy.size.width * max(0, min(1, fraction)))
            }
        }
        .frame(height: 7)
        .accessibilityHidden(true)
    }

    private func receipt(title: String, value: Int, ink: Color, stacked: Bool = false) -> some View {
        VStack(spacing: 1) {
            Text(title).font(Print.caption(9)).tracking(0.7)
            Text(value.formatted()).font(Print.numeral(14, weight: .bold))
                .lineLimit(1).minimumScaleFactor(0.65)
        }
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity).padding(.vertical, 3)
        .background {
            ZStack {
                if stacked {
                    RoundedRectangle(cornerRadius: 3).fill(Paper.pageWarm)
                        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(ink.opacity(0.5), lineWidth: 1))
                        .offset(x: 3, y: 3)
                }
                RoundedRectangle(cornerRadius: 3).fill(Paper.pageWarm)
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(ink, lineWidth: 1))
            }
        }
    }
}
