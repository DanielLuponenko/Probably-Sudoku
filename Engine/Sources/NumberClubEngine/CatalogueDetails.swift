import Foundation

/// Text and artwork addresses from the approved catalogue. Gameplay lives in
/// the engine's item runtimes; Shop cards and inspection share this one source.
public struct CatalogueDetails: Codable, Sendable, Identifiable {
    public let id: String
    public let code: String
    public let name: String
    public let category: String
    public let rarity: String
    public let price: Int
    public let effect: String
    public let shortEffect: String
    public let trigger: String
    public let limit: String
    public let icon: String
    public let sheet: String

    public static let all: [CatalogueDetails] = {
        guard let url = Bundle.module.url(forResource: "expanded-catalogue", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([CatalogueDetails].self, from: data) else {
            assertionFailure("The bundled item catalogue must be present and valid")
            return []
        }
        return entries
    }()
    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    public static func item(_ id: String) -> CatalogueDetails? { byID[id] }
}
