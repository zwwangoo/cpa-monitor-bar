import Foundation

extension KeyedDecodingContainer {
    func flexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let value = try? decode(Double.self, forKey: key) { return value }
        if let text = try? decode(String.self, forKey: key), let value = Double(text) {
            return value
        }
        return nil
    }

    func flexibleIntIfPresent(forKey key: Key) throws -> Int? {
        guard let value = try flexibleDoubleIfPresent(forKey: key) else { return nil }
        guard value.isFinite else { return nil }
        return Int(exactly: value)
    }

    func flexibleBoolIfPresent(forKey key: Key) throws -> Bool? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        if let value = try? decode(Bool.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return value != 0 }
        guard let text = try? decode(String.self, forKey: key) else { return nil }
        switch text.lowercased() {
        case "true", "1": return true
        case "false", "0": return false
        default: return nil
        }
    }
}
