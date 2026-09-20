import Foundation

/// JSON's sortedKeys option does not order Set elements or the alternating
/// arrays used by Dictionary when its key is a UUID/Square. Persist these
/// unordered facts canonically so save comparison is independent of hash order.
@propertyWrapper
public struct StableMap<Key: Codable & Hashable & Sendable, Value: Codable & Sendable>: Codable, Sendable {
    public var wrappedValue: [Key: Value]
    public init(wrappedValue: [Key: Value] = [:]) { self.wrappedValue = wrappedValue }

    public init(from decoder: Decoder) throws {
        // Accept previously synthesized dictionaries, including String/Int
        // keyed objects and UUID/Square keyed alternating arrays.
        if let previous = try? [Key: Value](from: decoder) {
            wrappedValue = previous
            return
        }
        var values = try decoder.unkeyedContainer()
        var result: [Key: Value] = [:]
        while !values.isAtEnd {
            let key = try values.decode(Key.self)
            let value = try values.decode(Value.self)
            guard result.updateValue(value, forKey: key) == nil else {
                throw DecodingError.dataCorruptedError(in: values, debugDescription: "Duplicate saved map key")
            }
        }
        wrappedValue = result
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        for key in try stableOrder(Array(wrappedValue.keys)) {
            try container.encode(key)
            try container.encode(wrappedValue[key]!)
        }
    }
}

extension StableMap: Equatable where Value: Equatable {}

@propertyWrapper
public struct StableOptionalMap<Key: Codable & Hashable & Sendable, Value: Codable & Sendable>: Codable, Sendable {
    public var wrappedValue: [Key: Value]?
    public init(wrappedValue: [Key: Value]? = nil) { self.wrappedValue = wrappedValue }
    public init(from decoder: Decoder) throws {
        if try decoder.singleValueContainer().decodeNil() { wrappedValue = nil }
        else { wrappedValue = try StableMap<Key, Value>(from: decoder).wrappedValue }
    }
    public func encode(to encoder: Encoder) throws {
        if let wrappedValue { try StableMap(wrappedValue: wrappedValue).encode(to: encoder) }
        else {
            var container = encoder.singleValueContainer()
            try container.encodeNil()
        }
    }
}

extension StableOptionalMap: Equatable where Value: Equatable {}

@propertyWrapper
public struct StableSet<Element: Codable & Hashable & Sendable>: Codable, Sendable, Equatable {
    public var wrappedValue: Set<Element>
    public init(wrappedValue: Set<Element> = []) { self.wrappedValue = wrappedValue }
    public init(from decoder: Decoder) throws { wrappedValue = try Set<Element>(from: decoder) }
    public func encode(to encoder: Encoder) throws {
        try stableOrder(Array(wrappedValue)).encode(to: encoder)
    }
}

@propertyWrapper
public struct StableSetMap<Key: Codable & Hashable & Sendable, Element: Codable & Hashable & Sendable>: Codable, Sendable, Equatable {
    public var wrappedValue: [Key: Set<Element>]
    public init(wrappedValue: [Key: Set<Element>] = [:]) { self.wrappedValue = wrappedValue }
    public init(from decoder: Decoder) throws {
        wrappedValue = try StableMap<Key, StableSet<Element>>(from: decoder).wrappedValue.mapValues(\.wrappedValue)
    }
    public func encode(to encoder: Encoder) throws {
        try StableMap(wrappedValue: wrappedValue.mapValues { StableSet(wrappedValue: $0) }).encode(to: encoder)
    }
}

private func stableOrder<Element: Encodable>(_ elements: [Element]) throws -> [Element] {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try elements.map { (value: $0, key: try encoder.encode($0)) }
        .sorted { $0.key.lexicographicallyPrecedes($1.key) }.map(\.value)
}

// Synthesis must also accept a field missing from older saves. Invalid present
// values still throw; absence alone supplies the collection's empty default.
extension KeyedDecodingContainer {
    public func decode<Key, Value>(_ type: StableMap<Key, Value>.Type, forKey key: K) throws -> StableMap<Key, Value> {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
    public func decode<Key, Value>(_ type: StableOptionalMap<Key, Value>.Type, forKey key: K) throws -> StableOptionalMap<Key, Value> {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
    public func decode<Element>(_ type: StableSet<Element>.Type, forKey key: K) throws -> StableSet<Element> {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
    public func decode<Key, Element>(_ type: StableSetMap<Key, Element>.Type, forKey key: K) throws -> StableSetMap<Key, Element> {
        try decodeIfPresent(type, forKey: key) ?? .init()
    }
}
