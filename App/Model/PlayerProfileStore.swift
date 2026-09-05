import Foundation
import Observation
import ProbablySudokuEngine

/// Everything the player keeps: permanent currency, the cosmetics they own,
/// and the five they are wearing.
///
/// Kept apart from `GameModel` on purpose. A Book is thrown away when it ends
/// — that is the whole shape of the game — and none of this can be allowed to
/// go with it. It is also apart from `RunStore`, so a cosmetic added next
/// month cannot make an old `progress.json` fail to decode and take the
/// player's obstacle unlocks with it.
@MainActor
@Observable
final class PlayerProfileStore {

    /// One store for the app. The reward hook lives in `GameModel.persist()`,
    /// which is nowhere near a view, so an environment-only store would have
    /// nothing to talk to.
    static let shared = PlayerProfileStore()

    private(set) var profile: PlayerProfile

    #if DEBUG
    /// Screenshot/test launches with explicit profile arguments must not be
    /// overwritten a moment later by the simulator's cached cloud profile.
    @ObservationIgnored private var hasDebugProfileOverride = false
    /// `-grantClubCurrency`'s balance. Held off `PlayerProfile` so it cannot
    /// be encoded, written to disk, or published to CloudSync.
    @ObservationIgnored private var debugCurrencyOverride: Int?
    /// Test seam only: observes the v2 equip publish without touching the
    /// real CloudSync/NSUbiquitousKeyValueStore.
    @ObservationIgnored var debugPublishEquippedHook: ((EquippedCosmetics, Date) -> Void)?
    #endif

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("profile.json")
    }

    init(profile: PlayerProfile? = nil) {
        if let profile {
            self.profile = profile
            self.profile.normalize()
            return
        }
        if let data = try? Data(contentsOf: Self.fileURL),
           let stored = try? JSONDecoder().decode(PlayerProfile.self, from: data) {
            self.profile = stored
        } else {
            self.profile = PlayerProfile()
        }
        applyDebugArguments()
    }

    // MARK: Reading

    var currency: Int {
        #if DEBUG
        if let debugCurrencyOverride { return debugCurrencyOverride }
        #endif
        return profile.cosmeticCurrency
    }

    var needsFirstRunTutorial: Bool { !profile.hasStartedFirstRunTutorial }

    /// The cosmetic catalogue is retired from gameplay. Keep legacy profile
    /// data decodable, but resolve every surface to the one core appearance.
    var theme: CosmeticTheme { .standard }

    func owns(_ item: CosmeticItem) -> Bool {
        item.isDefault || profile.ownedCosmeticIDs.contains(item.id)
    }

    func isEquipped(_ item: CosmeticItem) -> Bool {
        profile.equipped[item.category] == item.id
    }

    func canPurchase(_ item: CosmeticItem) -> Bool {
        !owns(item) && currency >= item.price
    }

    func equipped(in category: CosmeticCategory) -> CosmeticItem? {
        CosmeticCatalog.item(profile.equipped[category])
    }

    // MARK: Writing

    enum PurchaseError: Error {
        case alreadyOwned
        case cannotAfford
    }

    /// Pays a reward once and only once.
    ///
    /// The guard is the point of the whole method: a results page can appear
    /// three times for one finished Book — it is a page in a book, and pages
    /// get turned back to — and a reward paid from `onAppear` would pay three
    /// times. Callers pass an id that describes the *event*, not the moment.
    @discardableResult
    func earn(_ event: CosmeticRewardEvent) -> Bool {
        guard !profile.rewardedCompletionIDs.contains(event.id) else { return false }
        profile.rewardedCompletionIDs.insert(event.id)
        profile.earnedRewardAmounts[event.id] = max(0, event.amount)
        save()
        return true
    }

    @discardableResult
    func earn(_ events: [CosmeticRewardEvent]) -> Int {
        events.reduce(0) { total, event in earn(event) ? total + event.amount : total }
    }

    func purchase(_ item: CosmeticItem) throws {
        guard !owns(item) else { throw PurchaseError.alreadyOwned }
        guard currency >= item.price else { throw PurchaseError.cannotAfford }
        #if DEBUG
        if debugCurrencyOverride != nil {
            debugCurrencyOverride! -= item.price
            profile.ownedCosmeticIDs.insert(item.id)
            save()
            return
        }
        #endif
        profile.purchaseAmounts[item.id] = item.price
        profile.ownedCosmeticIDs.insert(item.id)
        save()
    }

    /// Wearing something you already own costs nothing, every time.
    func equip(_ item: CosmeticItem) {
        guard owns(item) else { return }
        guard profile.equipped[item.category] != item.id else { return }
        profile.equipped[item.category] = item.id
        let decisionAt = Date()
        profile.equippedDecisionAt = decisionAt
        save()
        publishEquipDecision(decisionAt: decisionAt)
    }

    /// The only v2 publish path. QA/test choices stay in memory and never
    /// leak into the shared iCloud key-value store.
    private func publishEquipDecision(decisionAt: Date) {
        #if DEBUG
        guard !hasDebugProfileOverride else { return }
        if let debugPublishEquippedHook {
            debugPublishEquippedHook(profile.equipped, decisionAt)
            return
        }
        #endif
        CloudSync.shared.publish(equipped: profile.equipped, decisionAt: decisionAt)
    }

    func startFirstRunTutorial() {
        guard !profile.hasStartedFirstRunTutorial else { return }
        profile.hasStartedFirstRunTutorial = true
        save()
    }

    // MARK: - Achievements

    func hasEarnedAchievement(_ id: String) -> Bool {
        profile.earnedAchievementIDs.contains(id)
    }

    /// Applies an engine-derived achievement event once. The closure can update
    /// durable progress as well as request awards; both are persisted together
    /// before Game Center is asked to mirror any newly earned identifiers.
    private func recordAchievementChange(_ change: (inout PlayerProfile) -> Set<String>) {
        let before = profile
        let requested = change(&profile)
        let newlyEarned = requested.subtracting(profile.earnedAchievementIDs)
        profile.earnedAchievementIDs.formUnion(requested)
        guard profile != before else { return }
        save()
        for id in newlyEarned {
            guard let definition = AchievementCatalog.definition(for: id) else { continue }
            GameCenterService.shared.recordAchievement(definition.gameCenterID)
        }
    }

    func recordReachedLevel(_ level: Int) {
        recordAchievementChange { profile in
            profile.achievementProgress.highestLevelReached = max(profile.achievementProgress.highestLevelReached,
                                                                    level)
            var awards: Set<String> = []
            if level >= 5 { awards.insert("reach-level-5") }
            if level >= 7 { awards.insert("reach-level-7") }
            if level >= 9 { awards.insert("reach-level-9") }
            return awards
        }
    }

    func recordBossDefeated(encounterID: String) {
        recordAchievementChange { profile in
            profile.achievementProgress.completedBossEncounterIDs.insert(encounterID)
            var awards: Set<String> = []
            if profile.achievementProgress.completedBossEncounterIDs.count >= 10 {
                awards.insert("beat-ten-bosses")
            }
            return awards
        }
    }

    func recordBookCompleted(volume: Int, obstacle: Obstacle) {
        recordAchievementChange { profile in
            profile.achievementProgress.completedBookVolumes.insert(volume)
            var awards: Set<String> = ["finish-book"]
            if profile.achievementProgress.completedBookVolumes.count >= AchievementCatalog.allBookVolumes {
                awards.insert("finish-every-book")
            }
            if obstacle == .shortHandedAndBlocked { awards.insert("obstacle-three-book") }
            return awards
        }
    }

    func recordPlacement(_ outcome: PlacementOutcome, duringKeepFilling: Bool) {
        recordAchievementChange { _ in
            var awards: Set<String> = []
            if outcome.fullClear { awards.insert("full-clear") }
            if outcome.fullClear && duringKeepFilling { awards.insert("keep-filling-full-clear") }
            let clearedKinds = Set(outcome.lineClears.map(\.rawValue))
            if clearedKinds == ["row", "col", "box"] { awards.insert("three-way-clear") }
            return awards
        }
    }

    func recordPuzzleFinished(score: Int, wasBoss: Bool, hadWrongPlacement: Bool,
                              usedClue: Bool, wasLastTurn: Bool) {
        recordAchievementChange { _ in
            var awards: Set<String> = []
            if score >= 100_000 { awards.insert("hundred-thousand") }
            if wasBoss && !hadWrongPlacement { awards.insert("flawless-boss") }
            if !usedClue { awards.insert("no-clue") }
            if wasLastTurn { awards.insert("last-turn-win") }
            return awards
        }
    }

    func recordCoinBalance(_ coins: Int) {
        guard coins >= 30 else { return }
        recordAchievementChange { _ in ["hold-thirty-coins"] }
    }

    func recordPurchase(kind: ItemKind, bookmarkCount: Int) {
        recordAchievementChange { _ in
            var awards: Set<String> = []
            if kind == .subscription { awards.insert("buy-subscription") }
            if bookmarkCount >= 5 { awards.insert("five-bookmarks") }
            return awards
        }
    }

    func recordSale(boughtAtLevel: Int?, currentLevel: Int) {
        guard boughtAtLevel == currentLevel else { return }
        recordAchievementChange { _ in ["same-shop-sale"] }
    }

    func recordSkipsUsed(_ count: Int) {
        guard count >= 2 else { return }
        recordAchievementChange { _ in ["two-skips"] }
    }

    /// Remote profile data is merged, never blindly assigned. An unavailable,
    /// corrupt, or newer-schema cloud value therefore leaves local play alone.
    func merge(remote: PlayerProfile) {
        #if DEBUG
        guard !hasDebugProfileOverride else { return }
        #endif
        let before = profile
        profile.merge(remote: remote)
        guard profile != before else { return }
        let remotelyEarned = profile.earnedAchievementIDs.subtracting(before.earnedAchievementIDs)
        save()
        // A second device may have earned these while this one was offline.
        // Queue the same local-first truth for Game Center after the merge;
        // `recordAchievement` is idempotent and silent while signed out.
        for id in remotelyEarned {
            guard let definition = AchievementCatalog.definition(for: id) else { continue }
            GameCenterService.shared.recordAchievement(definition.gameCenterID)
        }
    }

    /// Applies a newer choice from the dedicated v2 key without echoing it as
    /// a new local decision. Ownership arrives on profile.v1 and may race this
    /// payload; do not commit the clock if normalization had to reject an ID.
    func applyRemoteEquipped(_ equipped: EquippedCosmetics, decisionAt: Date) {
        #if DEBUG
        guard !hasDebugProfileOverride else { return }
        #endif
        guard decisionAt > profile.equippedDecisionAt else { return }
        var candidate = profile
        candidate.equipped = equipped
        candidate.normalize()
        guard candidate.equipped == equipped else { return }
        profile = candidate
        profile.equippedDecisionAt = decisionAt
        save()
    }

    private func save() {
        #if DEBUG
        if hasDebugProfileOverride || debugPublishEquippedHook != nil { return }
        #endif
        profile.lastModifiedAt = Date()
        guard let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
        CloudSync.shared.publish(profile: profile)
    }

    // MARK: QA

    private func applyDebugArguments() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        var hasLaunchOverride = false
        if arguments.contains("-resetProfile") {
            profile = PlayerProfile()
            hasLaunchOverride = true
        }
        if let at = arguments.firstIndex(of: "-grantClubCurrency"), at + 1 < arguments.count,
           let amount = Int(arguments[at + 1]) {
            debugCurrencyOverride = amount
            hasLaunchOverride = true
        }
        if arguments.contains("-unlockAllCosmetics") {
            profile.ownedCosmeticIDs.formUnion(CosmeticCatalog.items.map(\.id))
            hasLaunchOverride = true
        }
        // `-equipCosmetic dk_baize,nb_oldstyle` puts skins on without going
        // through the counter, so what they do to a Puzzle can be looked at.
        if let at = arguments.firstIndex(of: "-equipCosmetic"), at + 1 < arguments.count {
            for id in arguments[at + 1].split(separator: ",").map(String.init) {
                guard let item = CosmeticCatalog.item(id) else { continue }
                profile.ownedCosmeticIDs.insert(item.id)
                profile.equipped[item.category] = item.id
            }
            // Cloud data may arrive after this store is created. Keep this
            // launch-only selection long enough to inspect it; the override is
            // never written to disk, so it cannot become a player preference.
            profile.lastModifiedAt = .distantFuture
            hasLaunchOverride = true
        }
        // A cloud callback may arrive after the debug store is created. Keep
        // all explicit launch overrides authoritative for this QA session;
        // they are deliberately never persisted below.
        if hasLaunchOverride {
            profile.lastModifiedAt = .distantFuture
            hasDebugProfileOverride = true
        }
        // Deliberately not saved: a QA grant that survived the next launch
        // would quietly become the player's real balance.
        #endif
    }

    #if DEBUG
    /// Visual QA only. Production code can earn an achievement exclusively
    /// through the engine-derived methods above; this lets every card and its
    /// persistent state be checked without replaying a whole Book.
    func qaEarnAchievement(_ id: String) {
        guard AchievementCatalog.definition(for: id) != nil else { return }
        recordAchievementChange { _ in [id] }
    }

    func resetFirstRunTutorial() {
        profile.hasStartedFirstRunTutorial = false
        save()
    }

    /// Unit-test stand-in for `-grantClubCurrency`; process launch arguments
    /// cannot be varied inside one test process.
    func debugApplyCurrencyGrant(_ amount: Int) {
        debugCurrencyOverride = amount
        hasDebugProfileOverride = true
    }
    #endif
}
