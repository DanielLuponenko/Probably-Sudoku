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
    private var observer: NSObjectProtocol?

    private init() {}

    /// Safe to call at launch: synchronization is asynchronous and a signed-out
    /// device simply remains local. No UI depends on the outcome.
    func start(receivingProfiles receiver: @escaping (PlayerProfile) -> Void) {
        profileReceiver = receiver
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

    private func receiveExternalChange() {
        deliverRemoteProfile()
        NotificationCenter.default.post(name: Self.didReceiveExternalChange, object: self)
    }

    private func read<T: Decodable>(key: String) -> T? {
        guard let data = store.data(forKey: key),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.schema == Envelope.schema
        else { return nil }
        return try? JSONDecoder().decode(T.self, from: envelope.payload)
    }
}
