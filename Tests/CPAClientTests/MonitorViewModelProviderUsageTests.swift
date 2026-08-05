import Foundation
import XCTest
import CPAModels
@testable import CPAMonitorBar

@MainActor
final class MonitorViewModelProviderUsageTests: XCTestCase {
    func testAuthenticatedRefreshUsesKeeperProviderIDsAndPublishesResults() async {
        let snapshot = makeSnapshot(balance: 28.46)
        let monitor = RecordingProviderUsageMonitor(responses: [[
            "provider-1": .success(snapshot),
        ]])
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [makeProviderClient()],
            providerUsageConfigurations: [makeConfiguration(providerID: "provider-1")],
            providerUsageMonitor: monitor
        )
        let model = dependencies.makeModel()

        await model.start()

        let requests = await monitor.requests
        XCTAssertEqual(requests, [
            .init(
                keeperRoot: "https://keeper.example/cpa",
                providerIDs: ["provider-1", "provider-2"]
            ),
        ])
        XCTAssertEqual(model.providerUsageStates["provider-1"]?.snapshot, snapshot)
        XCTAssertNil(model.providerUsageStates["provider-2"])
    }

    func testFailedRefreshRetainsSnapshotAndLaterSuccessClearsError() async {
        let initial = makeSnapshot(balance: 28.46)
        let updated = makeSnapshot(balance: 25)
        let monitor = RecordingProviderUsageMonitor(responses: [
            ["provider-1": .success(initial)],
            ["provider-1": .failure(.serviceUnavailable)],
            ["provider-1": .success(updated)],
        ])
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [makeProviderClient()],
            providerUsageConfigurations: [makeConfiguration(providerID: "provider-1")],
            providerUsageMonitor: monitor
        )
        let model = dependencies.makeModel()
        await model.start()

        await model.refresh()
        XCTAssertEqual(model.providerUsageStates["provider-1"]?.snapshot, initial)
        XCTAssertEqual(
            model.providerUsageStates["provider-1"]?.errorMessage,
            ProviderUsageError.serviceUnavailable.localizedDescription
        )

        await model.refresh()
        XCTAssertEqual(model.providerUsageStates["provider-1"]?.snapshot, updated)
        XCTAssertNil(model.providerUsageStates["provider-1"]?.errorMessage)
        XCTAssertEqual(model.providerUsageStates["provider-1"]?.isLoading, false)
    }

    func testLogoutClearsStatesAndCancelsPendingProviderRefresh() async {
        let monitor = SuspendingProviderUsageMonitor(response: [
            "provider-1": .success(makeSnapshot(balance: 28.46)),
        ])
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [makeProviderClient()],
            providerUsageConfigurations: [makeConfiguration(providerID: "provider-1")],
            providerUsageMonitor: monitor
        )
        let model = dependencies.makeModel()
        let startTask = Task { await model.start() }
        let started = await eventually { await monitor.requestCount == 1 }
        XCTAssertTrue(started)

        await model.logout()
        await startTask.value

        XCTAssertTrue(model.providerUsageStates.isEmpty)
        let cancellationCount = await monitor.cancellationCount
        XCTAssertEqual(cancellationCount, 1)
    }

    func testConnectionGenerationRejectsOldProviderResult() async {
        let monitor = SuspendingProviderUsageMonitor(response: [
            "provider-1": .success(makeSnapshot(balance: 28.46)),
        ])
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [makeProviderClient()],
            providerUsageConfigurations: [makeConfiguration(providerID: "provider-1")],
            providerUsageMonitor: monitor
        )
        let model = dependencies.makeModel()
        let startTask = Task { await model.start() }
        let started = await eventually { await monitor.requestCount == 1 }
        XCTAssertTrue(started)

        model.resetConnectionState()
        await startTask.value

        XCTAssertTrue(model.providerUsageStates.isEmpty)
    }

    func testOverlappingRefreshKeepsNewestTaskOwnershipAndResult() async throws {
        let monitor = ControlledProviderUsageMonitor()
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [CountingClient()],
            providerUsageConfigurations: [makeConfiguration(providerID: "provider-1")],
            providerUsageMonitor: monitor
        )
        let model = dependencies.makeModel()
        let response = try JSONDecoder().decode(
            UsageIdentitiesPageResponse.self,
            from: Data(#"{"identities":[{"id":"provider-1"}]}"#.utf8)
        )
        let generation = model.connectionGeneration
        let oldSnapshot = makeSnapshot(balance: 10)
        let newSnapshot = makeSnapshot(balance: 20)

        let first = Task {
            await model.refreshProviderUsage(using: response, generation: generation)
        }
        let firstStarted = await eventually { await monitor.requestCount == 1 }
        XCTAssertTrue(firstStarted)
        let second = Task {
            await model.refreshProviderUsage(using: response, generation: generation)
        }
        let secondStarted = await eventually { await monitor.requestCount == 2 }
        XCTAssertTrue(secondStarted)

        await monitor.resumeRequest(
            at: 0,
            with: ["provider-1": .success(oldSnapshot)]
        )
        await first.value
        XCTAssertNotNil(model.providerUsageTask)

        await monitor.resumeRequest(
            at: 1,
            with: ["provider-1": .success(newSnapshot)]
        )
        await second.value
        XCTAssertEqual(model.providerUsageStates["provider-1"]?.snapshot, newSnapshot)
        XCTAssertNil(model.providerUsageTask)
    }

    private func makeProviderClient() -> CountingClient {
        CountingClient(
            authenticated: true,
            providerResponseBody: #"{"identities":[{"id":"provider-1","displayName":"Sub2API"},{"id":"provider-2","displayName":"Backup"}]}"#
        )
    }

    private func makeConfiguration(
        providerID: String
    ) -> ProviderUsageConfiguration {
        ProviderUsageConfiguration(
            providerID: providerID,
            baseURL: "https://usage.example",
            isEnabled: true
        )
    }

    private func makeSnapshot(balance: Double) -> ProviderUsageSnapshot {
        ProviderUsageSnapshot(
            mode: .wallet(balance: balance),
            currency: "USD",
            expiresAt: nil,
            fetchedAt: Date(timeIntervalSince1970: balance)
        )
    }
}

private actor ControlledProviderUsageMonitor: ProviderUsageMonitoring {
    private var continuations: [CheckedContinuation<
        [String: ProviderUsageRefreshResult], Never
    >?] = []

    var requestCount: Int { continuations.count }

    func refresh(
        keeperRoot: String,
        providerIDs: [String]
    ) async -> [String: ProviderUsageRefreshResult] {
        _ = keeperRoot
        _ = providerIDs
        return await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func validate(
        configuration: ProviderUsageConfiguration,
        key: String
    ) async throws -> ProviderUsageSnapshot {
        _ = configuration
        _ = key
        throw ProviderUsageError.serviceUnavailable
    }

    func resumeRequest(
        at index: Int,
        with result: [String: ProviderUsageRefreshResult]
    ) {
        continuations[index]?.resume(returning: result)
        continuations[index] = nil
    }
}
