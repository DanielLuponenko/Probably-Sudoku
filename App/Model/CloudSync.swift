import Foundation

/// Versioned, non-blocking transport for the small pieces of state a player
/// expects to follow them between devices. This is deliberately only a
/// transport layer: choosing between two live Books belongs to KAN-61.
final class CloudSync {
    static let shared = CloudSync()
    /// Posted on the main queue after iCloud has supplied (or refreshed) its
    /// key-value snapshot. Views can re-read their local/remote presentation
    /// state without making launch wait for the network.
    static let didReceiveExternalChange = Notification.Name("CloudSync.didReceiveExternalChange")

    private enum Key {
        static let profile = "sync.profile.v1"
        static let equipped = "sync.equipped.v2"
        static let run = "sync.run.v1"
    }

    private struct Envelope: Codable {
        static let schema = 1
        let schema: Int
        let modifiedAt: Date
        let payload: Data
    }

    private let store = NSUbiquitousKeyValueStore.default
    private var profileReceiver: ((PlayerProfile) -> Void)?
    private var equippedReceiver: ((EquippedCosmetics, Date) -> Void)?
    private var observer: NSObjectProtocol?

    private init() {}

    /// Safe to call at launch: synchronization is asynchronous and a signed-out
    /// device simply remains local. No UI depends on the outcome.
    func start(receivingProfiles receiver: @escaping (PlayerProfile) -> Void,
               receivingEquipped equippedReceiver: @escaping (EquippedCosmetics, Date) -> Void) {
        profileReceiver = receiver
        self.equippedReceiver = equippedReceiver
        if observer == nil {
            observer = NotificationCenter.default.addObserver(
                forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: store,
                queue: .main
            ) { [weak self] _ in
                self?.receiveExternalChange()
            }
        }
        store.synchronize()
        receiveExternalChange()
    }

    func publish(profile: PlayerProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        publish(data, key: Key.profile, modifiedAt: profile.lastModifiedAt)
    }

    /// Written only for an explicit local equip decision. Unrelated profile
    /// saves must never make a stale appearance choice look newer.
    func publish(equipped: EquippedCosmetics, decisionAt: Date) {
        guard let data = try? JSONEncoder().encode(equipped) else { return }
        publish(data, key: Key.equipped, modifiedAt: decisionAt)
    }

    func publish(run data: Data?) {
        guard let data else {
            store.removeObject(forKey: Key.run)
            store.synchronize()
            return
        }
        publish(data, key: Key.run, modifiedAt: Date())
    }

    /// KAN-61 reads this only after the player explicitly chooses which
    /// unfinished Book to continue. Never make launch silently replace the
    /// local run with it.
    func remoteRunData() -> Data? {
        read(key: Key.run)
    }

    private func publish(_ payload: Data, key: String, modifiedAt: Date) {
        let envelope = Envelope(schema: Envelope.schema, modifiedAt: modifiedAt, payload: payload)
        guard let data = try? JSONEncoder().encode(envelope) else { return }
        store.set(data, forKey: key)
        store.synchronize()
    }

    private func deliverRemoteProfile() {
        guard let remote: PlayerProfile = read(key: Key.profile) else { return }
        profileReceiver?(remote)
    }

    private func deliverRemoteEquipped() {
        guard let (equipped, decisionAt): (EquippedCosmetics, Date) = readEnvelope(key: Key.equipped)
        else { return }
        equippedReceiver?(equipped, decisionAt)
    }

    private func receiveExternalChange() {
        deliverRemoteProfile()
        deliverRemoteEquipped()
        NotificationCenter.default.post(name: Self.didReceiveExternalChange, object: self)
    }

    private func read<T: Decodable>(key: String) -> T? {
        readEnvelope(key: key)?.0
    }

    private func readEnvelope<T: Decodable>(key: String) -> (T, Date)? {
        guard let data = store.data(forKey: key),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.schema == Envelope.schema,
              let value = try? JSONDecoder().decode(T.self, from: envelope.payload)
        else { return nil }
        return (value, envelope.modifiedAt)
    }
}
