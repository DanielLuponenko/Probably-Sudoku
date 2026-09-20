import SwiftUI
import ProbablySudokuEngine

/// The target remains in its ordinary score row. A spent Royalty Buff tucks a
/// short contract tab into that number; restoring the same target is silent.
struct BossTargetNumber: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.bossMotionIsActive) private var presented
    @Environment(\.bossEntranceIsDeferred) private var deferred
    let target: Int
    let boss: BossModifier?
    let fontSize: CGFloat
    var entranceKey: String? = nil
    var consumeEntrance: ((String) -> Bool)? = nil
    @State private var increase: Int?
    @State private var changeID = UUID()
    @State private var landed = true
    @State private var stagedTarget: Int?
    @State private var showsExpansion = false
    @State private var resolvedEntranceKey: String?

    private var entryRequest: String { "\(entranceKey ?? "none"):\(presented):\(deferred):\(scenePhase == .active):\(reduceMotion)" }

    var body: some View {
        Text("/ \((stagedTarget ?? target).formatted())")
            .font(Print.numeral(fontSize, weight: .medium))
            .foregroundStyle(GameplaySurface.softInk)
            .contentTransition(.numericText())
            .animation(reduceMotion || boss != .royaltyContract ? nil : .easeOut(duration: 0.2), value: target)
            .accessibilityLabel("Target, \(target)")
            .overlay(alignment: .topTrailing) {
                if increase != nil || showsExpansion {
                    HStack(spacing: 3) {
                        Image(systemName: showsExpansion ? "doc.on.doc" : "signature").font(.system(size: 9))
                        Text(showsExpansion ? "×4" : "+\((increase ?? 0).formatted())").font(Print.numeral(11, weight: .semibold))
                    }
                    .foregroundStyle(GameplaySurface.sage)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Paper.pageWarm)
                    .overlay { UnevenRoundedRectangle(topLeadingRadius: 1, bottomLeadingRadius: 1,
                                                       bottomTrailingRadius: 1, topTrailingRadius: 5)
                        .strokeBorder(GameplaySurface.sage.opacity(0.65), lineWidth: 0.8) }
                    .shadow(color: Paper.ink.opacity(0.12), radius: 1, y: 1)
                    .offset(y: landed ? -18 : -26)
                    .opacity(landed ? 1 : 0)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                }
            }
            .onChange(of: target) { old, new in
                guard boss == .royaltyContract, new > old else { return }
                increase = new - old
                changeID = UUID()
            }
            .task(id: changeID) {
                guard increase != nil else { return }
                landed = reduceMotion
                if !reduceMotion {
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.18)) { landed = true }
                }
                do { try await Task.sleep(for: .milliseconds(950)) } catch { return }
                guard !Task.isCancelled else { return }
                increase = nil
            }
            .task(id: entryRequest) {
                guard boss == .heavyLifter, let entranceKey, resolvedEntranceKey != entranceKey else { return }
                if deferred, !reduceMotion, scenePhase != .background {
                    stagedTarget = target / 4
                    return
                }
                resolvedEntranceKey = entranceKey
                guard consumeEntrance?(entranceKey) == true, !reduceMotion,
                      presented, scenePhase == .active else { stagedTarget = nil; return }
                stagedTarget = target / 4
                showsExpansion = true
                await Task.yield()
                guard !Task.isCancelled else { stagedTarget = nil; showsExpansion = false; return }
                withAnimation(.easeOut(duration: 0.35)) { stagedTarget = nil }
                do { try await Task.sleep(for: .milliseconds(700)) } catch { showsExpansion = false; return }
                showsExpansion = false
            }
            .onDisappear {
                if let entranceKey { _ = consumeEntrance?(entranceKey) }
            }
            .onChange(of: reduceMotion) { _, reduced in
                if reduced { stagedTarget = nil; showsExpansion = false; landed = true }
            }
    }
}
