import Foundation
import XCTest
@testable import CPAMonitorBar

final class ProviderUsageMonitorTests: XCTestCase {
    func testMissingKeyDoesNotCreateAdapter() async {
        let factory = RecordingProviderUsageAdapterFactory(results: [:])
        let monitor = ProviderUsageMonitor(
            configurationStore: MemoryProviderUsageConfigurationStore(values: [
                configuration(providerID: "provider-2"),
            ]),
            credentialStore: MemoryProviderUsageCredentialStore(keys: [:]),
            adapterFactory: { try factory.make(configuration: $0, root: $1) }
        )

        let result = await monitor.refresh(
            keeperRoot: "https://keeper.example/cpa",
            providerIDs: ["provider-1", "provider-2"]
        )

        XCTAssertEqual(result, ["provider-2": .failure(.missingKey)])
        XCTAssertEqual(factory.createdProviderIDs, [])
    }

    func testProvidersSucceedAndFailIndependently() async {
        let success = snapshot(balance: 28.46)
        let factory = RecordingProviderUsageAdapterFactory(results: [
            "provider-1": .success(success),
            "provider-2": .failure(.authenticationRequired),
        ])
        let monitor = ProviderUsageMonitor(
            configurationStore: MemoryProviderUsageConfigurationStore(values: [
                configuration(providerID: "provider-1"),
                configuration(providerID: "provider-2"),
            ]),
            credentialStore: MemoryProviderUsageCredentialStore(keys: [
                "provider-1": "key-1",
                "provider-2": "key-2",
            ]),
            adapterFactory: { try factory.make(configuration: $0, root: $1) }
        )

        let result = await monitor.refresh(
            keeperRoot: "https://keeper.example/cpa",
            providerIDs: ["provider-1", "provider-2", "provider-3"]
        )

        XCTAssertEqual(result["provider-1"], .success(success))
        XCTAssertEqual(result["provider-2"], .failure(.authenticationRequired))
        XCTAssertNil(result["provider-3"])
    }

    func testRefreshLimitsConcurrencyToThree() async {
        let tracker = ProviderUsageConcurrencyTracker()
        let configurations = (1...6).map {
            configuration(providerID: "provider-\($0)")
        }
        let keys = Dictionary(uniqueKeysWithValues: (1...6).map {
            ("provider-\($0)", "key-\($0)")
        })
        let factory: ProviderUsageAdapterFactory = { _, _ in
            ConcurrencyTrackingProviderUsageAdapter(tracker: tracker)
        }
        let monitor = ProviderUsageMonitor(
            configurationStore: MemoryProviderUsageConfigurationStore(
                values: configurations
            ),
            credentialStore: MemoryProviderUsageCredentialStore(keys: keys),
            adapterFactory: factory
        )

        let result = await monitor.refresh(
            keeperRoot: "keeper",
            providerIDs: configurations.map(\.providerID)
        )

        XCTAssertEqual(result.count, 6)
        let maximumConcurrency = await tracker.maximumConcurrency
        XCTAssertEqual(maximumConcurrency, 3)
    }

    func testCancellationDoesNotStartAnotherChunk() async {
        let tracker = ProviderUsageCancellationTracker()
        let configurations = (1...6).map {
            configuration(providerID: "provider-\($0)")
        }
        let keys = Dictionary(uniqueKeysWithValues: (1...6).map {
            ("provider-\($0)", "key-\($0)")
        })
        let factory = RecordingProviderUsageAdapterFactory(results: [:])
        let adapterFactory: ProviderUsageAdapterFactory = { configuration, root in
            _ = try factory.make(configuration: configuration, root: root)
            return CancellationTrackingProviderUsageAdapter(tracker: tracker)
        }
        let monitor = ProviderUsageMonitor(
            configurationStore: MemoryProviderUsageConfigurationStore(
                values: configurations
            ),
            credentialStore: MemoryProviderUsageCredentialStore(keys: keys),
            adapterFactory: adapterFactory
        )

        let task = Task {
            await monitor.refresh(
                keeperRoot: "keeper",
                providerIDs: configurations.map(\.providerID)
            )
        }
        while factory.createdProviderIDs.count < 3 {
            await Task.yield()
        }
        task.cancel()
        _ = await task.value

        XCTAssertEqual(factory.createdProviderIDs.count, 3)
        let cancellations = await tracker.cancellations
        XCTAssertEqual(cancellations, 3)
    }

    func testValidateUsesDraftKeyWithoutSavingIt() async throws {
        let success = snapshot(balance: 9)
        let factory = RecordingProviderUsageAdapterFactory(results: [
            "provider-1": .success(success),
        ])
        let credentials = MemoryProviderUsageCredentialStore(keys: [:])
        let monitor = ProviderUsageMonitor(
            configurationStore: MemoryProviderUsageConfigurationStore(values: []),
            credentialStore: credentials,
            adapterFactory: { try factory.make(configuration: $0, root: $1) }
        )

        let result = try await monitor.validate(
            configuration: configuration(providerID: "provider-1"),
            key: "draft-key"
        )

        XCTAssertEqual(result, success)
        let savedKeys = await credentials.savedKeys
        XCTAssertEqual(savedKeys, [:])
    }

    private func configuration(
        providerID: String,
        baseURL: String = "https://usage.example"
    ) -> ProviderUsageConfiguration {
        ProviderUsageConfiguration(
            providerID: providerID,
            baseURL: baseURL,
            isEnabled: true
        )
    }

    private func snapshot(balance: Double) -> ProviderUsageSnapshot {
        ProviderUsageSnapshot(
            mode: .wallet(balance: balance),
            currency: "USD",
            expiresAt: nil,
            fetchedAt: Date(timeIntervalSince1970: 1)
        )
    }
}

final class MemoryProviderUsageConfigurationStore:
    ProviderUsageConfigurationStoring, @unchecked Sendable {
    var values: [ProviderUsageConfiguration]

    init(values: [ProviderUsageConfiguration]) { self.values = values }
    func load(keeperRoot: String) throws -> [ProviderUsageConfiguration] {
        _ = keeperRoot
        return values
    }
    func save(
        _ values: [ProviderUsageConfiguration],
        keeperRoot: String
    ) throws {
        _ = keeperRoot
        self.values = values
    }
}

actor MemoryProviderUsageCredentialStore: ProviderUsageCredentialStoring {
    private var keys: [String: String]
    private let shouldFailUpdate: Bool
    private(set) var savedKeys: [String: String] = [:]
    private(set) var deletedProviderIDs: [String] = []

    init(keys: [String: String], shouldFailUpdate: Bool = false) {
        self.keys = keys
        self.shouldFailUpdate = shouldFailUpdate
    }

    func loadKey(scope: ProviderUsageScope) -> String? {
        keys[scope.providerID]
    }

    func updateKeys(
        keeperRoot: String,
        upserts: [String: String],
        keeping providerIDs: Set<String>
    ) throws {
        _ = keeperRoot
        if shouldFailUpdate {
            throw LocalCredentialStorageError.io(EIO)
        }
        for providerID in keys.keys.sorted() where !providerIDs.contains(providerID) {
            keys.removeValue(forKey: providerID)
            deletedProviderIDs.append(providerID)
        }
        for (providerID, key) in upserts {
            keys[providerID] = key
            savedKeys[providerID] = key
        }
    }

    var allKeys: [String: String] { keys }
}

final class RecordingProviderUsageAdapterFactory: @unchecked Sendable {
    private let lock = NSLock()
    private var identifiers: [String] = []
    private let results: [String: Result<ProviderUsageSnapshot, ProviderUsageError>]

    var createdProviderIDs: [String] {
        lock.withLock { identifiers }
    }

    init(results: [String: Result<ProviderUsageSnapshot, ProviderUsageError>]) {
        self.results = results
    }

    func make(
        configuration: ProviderUsageConfiguration,
        root: ProviderUsageServiceRoot
    ) throws -> any ProviderUsageAdapter {
        _ = root
        lock.withLock { identifiers.append(configuration.providerID) }
        return StubProviderUsageAdapter(
            result: results[configuration.providerID] ?? .failure(.serviceUnavailable)
        )
    }
}

struct StubProviderUsageAdapter: ProviderUsageAdapter {
    let result: Result<ProviderUsageSnapshot, ProviderUsageError>

    func fetchUsage(key: String) async throws -> ProviderUsageSnapshot {
        _ = key
        return try result.get()
    }
}

actor ProviderUsageConcurrencyTracker {
    private var current = 0
    private(set) var maximumConcurrency = 0

    func begin() {
        current += 1
        maximumConcurrency = max(maximumConcurrency, current)
    }

    func end() { current -= 1 }
}

struct ConcurrencyTrackingProviderUsageAdapter: ProviderUsageAdapter {
    let tracker: ProviderUsageConcurrencyTracker

    func fetchUsage(key: String) async throws -> ProviderUsageSnapshot {
        _ = key
        await tracker.begin()
        try await Task.sleep(for: .milliseconds(20))
        await tracker.end()
        return ProviderUsageSnapshot(
            mode: .wallet(balance: 1),
            currency: "USD",
            expiresAt: nil,
            fetchedAt: Date(timeIntervalSince1970: 1)
        )
    }
}

actor ProviderUsageCancellationTracker {
    private(set) var cancellations = 0

    func recordCancellation() {
        cancellations += 1
    }
}

struct CancellationTrackingProviderUsageAdapter: ProviderUsageAdapter {
    let tracker: ProviderUsageCancellationTracker

    func fetchUsage(key: String) async throws -> ProviderUsageSnapshot {
        _ = key
        do {
            try await Task.sleep(for: .seconds(30))
        } catch is CancellationError {
            await tracker.recordCancellation()
            throw CancellationError()
        }
        return ProviderUsageSnapshot(
            mode: .wallet(balance: 1),
            currency: "USD",
            expiresAt: nil,
            fetchedAt: Date(timeIntervalSince1970: 1)
        )
    }
}
