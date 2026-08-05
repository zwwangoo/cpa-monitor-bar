import Foundation

protocol ProviderUsageConfigurationStoring: Sendable {
    func load(keeperRoot: String) throws -> [ProviderUsageConfiguration]
    func save(
        _ values: [ProviderUsageConfiguration],
        keeperRoot: String
    ) throws
}

enum ProviderUsageConfigurationStorageError: LocalizedError, Equatable {
    case corruptedData

    var errorDescription: String? {
        "本地供应商用量配置已损坏，未更改监控 Key"
    }
}

final class UserDefaultsProviderUsageConfigurationStore:
    ProviderUsageConfigurationStoring, @unchecked Sendable {
    private struct Envelope: Codable {
        var version = 1
        var keepers: [String: [ProviderUsageConfiguration]] = [:]
    }

    private let defaults: UserDefaults
    private let key: String
    private let lock = NSLock()

    init(
        defaults: UserDefaults = .standard,
        key: String = "providerUsageConfigurations"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func load(keeperRoot: String) throws -> [ProviderUsageConfiguration] {
        lock.lock()
        defer { lock.unlock() }
        return try storedEnvelope().keepers[keeperRoot] ?? []
    }

    func save(
        _ values: [ProviderUsageConfiguration],
        keeperRoot: String
    ) throws {
        lock.lock()
        defer { lock.unlock() }
        var value = try storedEnvelope()
        if values.isEmpty {
            value.keepers.removeValue(forKey: keeperRoot)
        } else {
            value.keepers[keeperRoot] = values
        }
        let data = try JSONEncoder().encode(value)
        defaults.set(data, forKey: key)
    }

    private func storedEnvelope() throws -> Envelope {
        guard let storedValue = defaults.object(forKey: key) else {
            return Envelope()
        }
        guard let data = storedValue as? Data,
              let decoded = try? JSONDecoder().decode(Envelope.self, from: data),
              decoded.version == 1 else {
            throw ProviderUsageConfigurationStorageError.corruptedData
        }
        return decoded
    }
}

protocol ProviderUsageCredentialStoring: Sendable {
    func loadKey(scope: ProviderUsageScope) async throws -> String?
    func updateKeys(
        keeperRoot: String,
        upserts: [String: String],
        keeping providerIDs: Set<String>
    ) async throws
}
