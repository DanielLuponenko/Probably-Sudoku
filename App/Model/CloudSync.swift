import Foundation

/// Versioned, non-blocking transport for the small pieces of state a player
/// expects to follow them between devices. This is deliberately only a
/// transport layer: RunStore owns the single resumable Book policy.
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
        var discardedRuns: [RunStore.DiscardedRunIdentity]? = nil
    }

    private let store = NSUbiquitousKeyValueStore.default
    private var profileReceiver: ((PlayerProfile) -> Void)?
    private var equippedReceiver: ((EquippedCosmetics, Date) -> Void)?
    private var observer: NSObjectProtocol?

    private init() {}

    private var isolatesCloudForQA: Bool {
        #if DEBUG && targetEnvironment(simulator)
        ProcessInfo.processInfo.arguments.contains("-isolateCloudQA")
        #else
        false
        #endif
    }

    /// Safe to call at launch: synchronization is asynchronous and a signed-out
    /// device simply remains local. No UI depends on the outcome.
    func start(receivingProfiles receiver: @escaping (PlayerProfile) -> Void,
               receivingEquipped equippedReceiver: @escaping (EquippedCosmetics, Date) -> Void) {
        guard !isolatesCloudForQA else { return }
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
        guard !isolatesCloudForQA else { return }
        guard let data = try? JSONEncoder().encode(profile) else { return }
        publish(data, key: Key.profile, modifiedAt: profile.lastModifiedAt)
    }

    /// Written only for an explicit local equip decision. Unrelated profile
    /// saves must never make a stale appearance choice look newer.
    func publish(equipped: EquippedCosmetics, decisionAt: Date) {
        guard !isolatesCloudForQA else { return }
        guard let data = try? JSONEncoder().encode(equipped) else { return }
        publish(data, key: Key.equipped, modifiedAt: decisionAt)
    }

    /// Legacy envelopes still contain the original Game JSON in payload.
    /// An empty payload plus discarded identities is a durable deletion; the
    /// metadata can also accompany a different, still-active remote Book.
    struct RunSnapshot {
        var data: Data?
        var discardedRuns: [RunStore.DiscardedRunIdentity] = []
        /// Evidence for rollback, not a last-writer-wins authority rule.
        var modifiedAt: Date? = nil
        var envelopeData: Data? = nil
        var isUnreadable = false
    }

    func publish(run data: Data?, discardedRuns: [RunStore.DiscardedRunIdentity] = []) {
        guard !isolatesCloudForQA else { return }
        let snapshot = Self.snapshotAfterPublishing(run: data, discardedRuns: discardedRuns,
                                                   previous: remoteRunSnapshot())
        guard let encoded = try? Self.encodedRunEnvelope(snapshot) else { return }
        store.set(encoded, forKey: Key.run)
        store.synchronize()
    }

    /// RunStore archives and retires observed alternatives before publishing
    /// a deletion. Clearing the sole active Book must not promote another one.
    static func snapshotAfterPublishing(run data: Data?, discardedRuns: [RunStore.DiscardedRunIdentity],
                                        previous: RunSnapshot) -> RunSnapshot {
        let discarded = RunStore.DiscardedRunIdentity.merged(previous.discardedRuns, discardedRuns)
        return RunSnapshot(data: data, discardedRuns: discarded)
    }

    func remoteRunSnapshot() -> RunSnapshot {
        guard !isolatesCloudForQA else { return RunSnapshot(data: nil) }
        return Self.runSnapshot(fromEnvelope: store.data(forKey: Key.run))
    }

    func remoteRunData() -> Data? {
        guard !isolatesCloudForQA else { return nil }
        return Self.runData(fromEnvelope: store.data(forKey: Key.run))
    }

    /// Pure transport boundaries allow storage tests to simulate delayed cloud
    /// delivery without connecting to the player's ubiquitous key-value store.
    static func runSnapshot(fromEnvelope data: Data?) -> RunSnapshot {
        guard let data else { return RunSnapshot(data: nil) }
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.schema == Envelope.schema else {
            return RunSnapshot(data: nil, envelopeData: data, isUnreadable: true)
        }
        return RunSnapshot(data: envelope.payload.isEmpty ? nil : envelope.payload,
                           discardedRuns: envelope.discardedRuns ?? [],
                           modifiedAt: envelope.modifiedAt, envelopeData: data)
    }

    static func runData(fromEnvelope data: Data?) -> Data? {
        let snapshot = runSnapshot(fromEnvelope: data)
        if let game = RunStore.game(from: snapshot.data),
           snapshot.discardedRuns.contains(RunStore.DiscardedRunIdentity(game)) { return nil }
        // Payload is Game JSON, not a second JSON-encoded Data value.
        return snapshot.data
    }

    static func encodedRunEnvelope(_ snapshot: RunSnapshot, modifiedAt: Date = Date()) throws -> Data {
        try JSONEncoder().encode(Envelope(schema: Envelope.schema, modifiedAt: modifiedAt,
            payload: snapshot.data ?? Data(),
            discardedRuns: snapshot.discardedRuns.isEmpty ? nil : snapshot.discardedRuns))
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
        guard !isolatesCloudForQA else { return }
        deliverRemoteProfile()
        deliverRemoteEquipped()
        NotificationCenter.default.post(name: Self.didReceiveExternalChange, object: self)
    }

    private func read<T: Decodable>(key: String) -> T? {
        readEnvelope(key: key)?.0
    }

    private func readEnvelope<T: Decodable>(key: String) -> (T, Date)? {
        guard !isolatesCloudForQA else { return nil }
        guard let data = store.data(forKey: key),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.schema == Envelope.schema,
              let value = try? JSONDecoder().decode(T.self, from: envelope.payload)
        else { return nil }
        return (value, envelope.modifiedAt)
    }
}
