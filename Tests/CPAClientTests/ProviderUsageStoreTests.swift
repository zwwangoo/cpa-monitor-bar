import Foundation
import XCTest
@testable import CPAMonitorBar

final class ProviderUsageStoreTests: XCTestCase {
    func testConfigurationsAreIsolatedByKeeperRoot() throws {
        let suiteName = "ProviderUsageStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsProviderUsageConfigurationStore(defaults: defaults)
        let first = configuration(
            providerID: "provider-1",
            baseURL: "https://first.example"
        )

        try store.save([first], keeperRoot: "https://keeper-a.example/cpa")

        XCTAssertEqual(
            try store.load(keeperRoot: "https://keeper-a.example/cpa"),
            [first]
        )
        XCTAssertEqual(
            try store.load(keeperRoot: "https://keeper-b.example/cpa"),
            []
        )
    }

    func testUpdatingOneKeeperPreservesOtherKeeperConfigurations() throws {
        let suiteName = "ProviderUsageStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsProviderUsageConfigurationStore(defaults: defaults)
        let first = configuration(providerID: "1", baseURL: "https://one.example")
        let second = configuration(providerID: "2", baseURL: "https://two.example")
        let replacement = configuration(providerID: "3", baseURL: "https://three.example")
        try store.save([first], keeperRoot: "keeper-a")
        try store.save([second], keeperRoot: "keeper-b")

        try store.save([replacement], keeperRoot: "keeper-a")

        XCTAssertEqual(try store.load(keeperRoot: "keeper-a"), [replacement])
        XCTAssertEqual(try store.load(keeperRoot: "keeper-b"), [second])
    }

    func testCorruptedConfigurationDataFailsClosed() throws {
        let suiteName = "ProviderUsageStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("not-json".utf8), forKey: "providerUsageConfigurations")
        let store = UserDefaultsProviderUsageConfigurationStore(defaults: defaults)

        XCTAssertThrowsError(try store.load(keeperRoot: "keeper-a"))
    }

    func testCorruptedConfigurationDataIsNotOverwrittenBySave() throws {
        let suiteName = "ProviderUsageStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let corrupted = Data("not-json".utf8)
        defaults.set(corrupted, forKey: "providerUsageConfigurations")
        let store = UserDefaultsProviderUsageConfigurationStore(defaults: defaults)

        XCTAssertThrowsError(
            try store.save(
                [configuration(providerID: "provider", baseURL: "https://usage.example")],
                keeperRoot: "keeper"
            )
        )

        XCTAssertEqual(
            defaults.data(forKey: "providerUsageConfigurations"),
            corrupted
        )
    }

    func testConfigurationPersistenceNeverContainsProviderKey() throws {
        let suiteName = "ProviderUsageStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsProviderUsageConfigurationStore(defaults: defaults)

        try store.save(
            [configuration(providerID: "provider", baseURL: "https://usage.example")],
            keeperRoot: "keeper"
        )

        let data = try XCTUnwrap(defaults.data(forKey: "providerUsageConfigurations"))
        let serialized = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertFalse(serialized.contains(#""key""#))
    }

    private func configuration(
        providerID: String,
        baseURL: String
    ) -> ProviderUsageConfiguration {
        ProviderUsageConfiguration(
            providerID: providerID,
            baseURL: baseURL,
            isEnabled: true
        )
    }
}
