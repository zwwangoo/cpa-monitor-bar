import XCTest
import CPAClient
@testable import CPAMonitorBar

@MainActor
final class MonitorViewModelTests: XCTestCase {
    func testMissingConfigurationMakesEveryActionANoOp() async {
        let dependencies = Dependencies(savedURL: nil)
        let model = dependencies.makeModel()

        await model.start()
        await model.login(password: "secret")
        await model.refresh()
        await model.logout()

        XCTAssertEqual(model.configurationState, .unconfigured)
        XCTAssertEqual(model.baseURL, "")
        XCTAssertEqual(model.statusText, "尚未配置")
        XCTAssertEqual(dependencies.clientFactory.callCount, 0)
        XCTAssertEqual(dependencies.credentialFactory.callCount, 0)
    }

    func testUnsupportedPersistedURLIsUnconfiguredWithoutCreatingDependencies() async {
        let dependencies = Dependencies(savedURL: "ftp://example.com/cpa")
        let model = dependencies.makeModel()

        await model.start()

        XCTAssertEqual(model.configurationState, .unconfigured)
        XCTAssertEqual(model.baseURL, "")
        XCTAssertEqual(dependencies.clientFactory.callCount, 0)
        XCTAssertEqual(dependencies.credentialFactory.callCount, 0)
    }

    func testValidPersistedURLStartsWithHealthThenSession() async {
        let client = CountingClient(authenticated: false)
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa/",
            clients: [client]
        )
        let model = dependencies.makeModel()

        await model.start()
        let calls = await client.calls

        XCTAssertEqual(model.configurationState, .configured)
        XCTAssertEqual(model.baseURL, "https://keeper.example/cpa")
        XCTAssertEqual(calls, [.health, .session])
        XCTAssertEqual(dependencies.clientFactory.callCount, 1)
        XCTAssertEqual(dependencies.credentialFactory.callCount, 1)
        XCTAssertEqual(dependencies.credentialFactory.store.loadCount, 1)
    }

    func testApplyingURLNormalizesPersistsResetsAndChecksHealthThenSession() async throws {
        let oldClient = CountingClient(authenticated: true)
        let newClient = CountingClient(authenticated: false)
        let dependencies = Dependencies(
            savedURL: "https://old.example/cpa",
            clients: [oldClient, newClient]
        )
        let model = dependencies.makeModel()
        await model.start()
        XCTAssertTrue(model.isAuthenticated)
        XCTAssertNotNil(model.overview.value)

        try await model.updateBaseURL("  https://new.example  ")
        let newCalls = await newClient.calls

        XCTAssertEqual(model.baseURL, "https://new.example/cpa")
        XCTAssertEqual(dependencies.baseURLStore.baseURL, model.baseURL)
        XCTAssertEqual(model.configurationState, .configured)
        XCTAssertFalse(model.isAuthenticated)
        XCTAssertFalse(model.isRefreshing)
        XCTAssertNil(model.loginError)
        XCTAssertNil(model.keeperStatus.value)
        XCTAssertNil(model.keeperStatus.errorMessage)
        XCTAssertNil(model.overview.value)
        XCTAssertNil(model.realtime.value)
        XCTAssertNil(model.analysis.value)
        XCTAssertEqual(newCalls, [.health, .session])
    }

    func testConfiguredHealthErrorStaysConfiguredAndOffline() async {
        let client = CountingClient(healthError: .network("offline"))
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client]
        )
        let model = dependencies.makeModel()

        await model.start()
        let calls = await client.calls

        XCTAssertEqual(model.configurationState, .configured)
        XCTAssertEqual(model.statusText, "离线")
        XCTAssertNotNil(model.health.errorMessage)
        XCTAssertEqual(calls, [.health])
    }

    func testPollingRecoversAfterInitialHealthFailure() async {
        let client = CountingClient(healthError: .network("offline"))
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client]
        )
        let model = dependencies.makeModel(pollingInterval: .milliseconds(10))

        await model.start()
        XCTAssertEqual(model.statusText, "离线")

        let recovered = await eventually {
            let calls = await client.calls
            return calls.filter { $0 == .health }.count >= 2 && calls.contains(.session)
        }
        XCTAssertTrue(recovered)
        XCTAssertEqual(model.statusText, "未登录")
    }

    func testPollingContinuesWhileUnauthenticated() async {
        let client = CountingClient(authenticated: false)
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client]
        )
        let model = dependencies.makeModel(pollingInterval: .milliseconds(10))

        await model.start()

        let polledAgain = await eventually {
            let calls = await client.calls
            return calls.filter { $0 == .session }.count >= 2
        }
        XCTAssertTrue(polledAgain)
        XCTAssertFalse(model.isAuthenticated)
    }

    func testLogoutKeepsHealthAndSessionPollingActive() async {
        let client = CountingClient(authenticated: true)
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client]
        )
        let model = dependencies.makeModel(pollingInterval: .milliseconds(10))
        await model.start()

        await model.logout()

        let polledAfterLogout = await eventually {
            let calls = await client.calls
            guard let logoutIndex = calls.firstIndex(of: .logout) else { return false }
            return calls[logoutIndex...].contains(.health)
                && calls[logoutIndex...].contains(.session)
        }
        XCTAssertTrue(polledAfterLogout)
        XCTAssertFalse(model.isAuthenticated)
    }

    func testDegradedHealthDoesNotStartSessionCheck() async {
        let client = CountingClient(healthStatus: "degraded")
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client]
        )
        let model = dependencies.makeModel()

        await model.start()
        let calls = await client.calls

        XCTAssertEqual(calls, [.health])
        XCTAssertEqual(model.statusText, "离线")
        XCTAssertEqual(model.health.errorMessage, "健康检查状态异常：degraded")
    }

    func testStoppedKeeperIsReportedAsServiceFailure() async {
        let client = CountingClient(authenticated: true, keeperRunning: false)
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client]
        )
        let model = dependencies.makeModel()

        await model.start()

        XCTAssertEqual(model.statusText, "服务异常")
        XCTAssertEqual(model.statusSymbol, "exclamationmark.triangle.fill")
    }

    func testAuthenticatedRefreshLoadsDetailsThenQuotaCacheForAuthFiles() async {
        let client = CountingClient(authenticated: true)
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client]
        )
        let model = dependencies.makeModel()

        await model.start()
        let calls = await client.calls

        XCTAssertEqual(model.events.value?.events.count, 0)
        XCTAssertEqual(model.keeperVersion.value?.version, "v1.13.5")
        XCTAssertEqual(model.authFiles.value?.identities.first?.identity, "auth-1")
        XCTAssertEqual(model.providers.value?.identities.count, 0)
        XCTAssertEqual(model.quotaCache.value?.items.count, 0)
        XCTAssertTrue(calls.contains(.events))
        XCTAssertTrue(calls.contains(.version))
        XCTAssertTrue(calls.contains(.authFiles))
        XCTAssertTrue(calls.contains(.providers))
        XCTAssertTrue(calls.contains(.quotaCache(["auth-1"])))
        XCTAssertLessThan(
            try XCTUnwrap(calls.firstIndex(of: .authFiles)),
            try XCTUnwrap(calls.firstIndex(of: .quotaCache(["auth-1"])))
        )
    }

    func testLoadMoreEventsAppendsUniqueEventsAndStopsAtLastPage() async {
        let client = CountingClient(
            authenticated: true,
            eventResponseBodies: [
                1: #"{"events":[{"id":"1"},{"id":"2"}],"total_count":3,"page":1,"page_size":20,"total_pages":2}"#,
                2: #"{"events":[{"id":"2"},{"id":"3"}],"total_count":3,"page":2,"page_size":20,"total_pages":2}"#,
            ]
        )
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client]
        )
        let model = dependencies.makeModel()
        await model.start()

        XCTAssertTrue(model.canLoadMoreEvents)
        await model.loadMoreEvents()
        await model.loadMoreEvents()
        let requestedPages = await client.eventPageRequests

        XCTAssertEqual(model.events.value?.events.compactMap(\.id), ["1", "2", "3"])
        XCTAssertEqual(model.events.value?.page, 2)
        XCTAssertFalse(model.canLoadMoreEvents)
        XCTAssertEqual(requestedPages, [1, 2])
    }

}
