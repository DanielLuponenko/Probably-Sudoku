import Foundation
import Observation

/// Everything the player keeps: permanent currency, the cosmetics they own,
/// and the five they are wearing.
///
/// Kept apart from `GameModel` on purpose. A Book is thrown away when it ends
/// — that is the whole shape of the game — and none of this can be allowed to
/// go with it. It is also apart from `RunStore`, so a cosmetic added next
/// month cannot make an old `progress.json` fail to decode and take the
/// player's obstacle unlocks with it.
@Observable
final class PlayerProfileStore {

    /// One store for the app. The reward hook lives in `GameModel.persist()`,
    /// which is nowhere near a view, so an environment-only store would have
    /// nothing to talk to.
    static let shared = PlayerProfileStore()

    private(set) var profile: PlayerProfile

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

    var currency: Int { profile.cosmeticCurrency }

    var needsFirstRunTutorial: Bool { !profile.hasStartedFirstRunTutorial }

    var theme: CosmeticTheme { CosmeticCatalog.theme(for: profile.equipped) }

    func owns(_ item: CosmeticItem) -> Bool {
        item.isDefault || profile.ownedCosmeticIDs.contains(item.id)
    }

    func isEquipped(_ item: CosmeticItem) -> Bool {
        profile.equipped[item.category] == item.id
    }

    func canPurchase(_ item: CosmeticItem) -> Bool {
        !owns(item) && profile.cosmeticCurrency >= item.price
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
        profile.cosmeticCurrency += max(0, event.amount)
        save()
        return true
    }

    @discardableResult
    func earn(_ events: [CosmeticRewardEvent]) -> Int {
        events.reduce(0) { total, event in earn(event) ? total + event.amount : total }
    }

    func purchase(_ item: CosmeticItem) throws {
        guard !owns(item) else { throw PurchaseError.alreadyOwned }
        guard profile.cosmeticCurrency >= item.price else { throw PurchaseError.cannotAfford }
        profile.cosmeticCurrency -= item.price
        profile.ownedCosmeticIDs.insert(item.id)
        save()
    }

    /// Wearing something you already own costs nothing, every time.
    func equip(_ item: CosmeticItem) {
        guard owns(item) else { return }
        guard profile.equipped[item.category] != item.id else { return }
        profile.equipped[item.category] = item.id
        save()
    }

    func startFirstRunTutorial() {
        guard !profile.hasStartedFirstRunTutorial else { return }
        profile.hasStartedFirstRunTutorial = true
        save()
    }

    /// Remote profile data is merged, never blindly assigned. An unavailable,
    /// corrupt, or newer-schema cloud value therefore leaves local play alone.
    func merge(remote: PlayerProfile) {
        let before = profile
        profile.merge(remote: remote)
        guard profile != before else { return }
        save()
    }

    private func save() {
        profile.lastModifiedAt = Date()
        guard let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
        CloudSync.shared.publish(profile: profile)
    }

    // MARK: QA

    private func applyDebugArguments() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-resetProfile") {
            profile = PlayerProfile()
        }
        if let at = arguments.firstIndex(of: "-grantClubCurrency"), at + 1 < arguments.count,
           let amount = Int(arguments[at + 1]) {
            profile.cosmeticCurrency = amount
        }
        if arguments.contains("-unlockAllCosmetics") {
            profile.ownedCosmeticIDs.formUnion(CosmeticCatalog.items.map(\.id))
        }
        // `-equipCosmetic dk_baize,nb_oldstyle` puts skins on without going
        // through the counter, so what they do to a Puzzle can be looked at.
        if let at = arguments.firstIndex(of: "-equipCosmetic"), at + 1 < arguments.count {
            for id in arguments[at + 1].split(separator: ",").map(String.init) {
                guard let item = CosmeticCatalog.item(id) else { continue }
                profile.ownedCosmeticIDs.insert(item.id)
                profile.equipped[item.category] = item.id
            }
        }
        // Deliberately not saved: a QA grant that survived the next launch
        // would quietly become the player's real balance.
        #endif
    }

    #if DEBUG
    func resetFirstRunTutorial() {
        profile.hasStartedFirstRunTutorial = false
        save()
    }
    #endif
}
