import Foundation
import XCTest
@testable import CPAMonitorBar

@MainActor
final class MonitorViewModelQuotaRefreshTests: XCTestCase {
    func testIgnoresUnexpectedTasksReturnedByServer() async {
        let client = CountingClient(
            authenticated: true,
            quotaRefreshBatchBody: #"{"tasks":[{"authIndex":"unexpected"}]}"#
        )
        let model = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client]
        ).makeModel()
        await model.start()

        model.refreshQuota(authIndexes: ["auth-1"])
        let finished = await eventually { !model.isRefreshingQuota }
        let calls = await client.calls

        XCTAssertTrue(finished)
        XCTAssertFalse(calls.contains(.quotaRefreshStatus("unexpected")))
        XCTAssertEqual(model.quotaRefreshError, "1 个账号刷新失败")
    }

    func testRejectsQuotaRefreshLargerThanClientLimit() async {
        let client = CountingClient(authenticated: true)
        let model = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client]
        ).makeModel()
        await model.start()
        let indexes = (0...MonitorViewModel.maximumQuotaRefreshTasks).map { "auth-\($0)" }

        model.refreshQuota(authIndexes: indexes)
        let calls = await client.calls

        XCTAssertFalse(calls.contains(.refreshQuota(indexes)))
        XCTAssertNotNil(model.quotaRefreshError)
    }

    func testPollsAcceptedTasksAndReloadsCache() async {
        let refreshedCache = #"{"items":[{"auth_index":"auth-1","status":"completed","quota":{"quota":[{"key":"5h","remainingFraction":0.9}]}}]}"#
        let client = CountingClient(
            authenticated: true,
            quotaRefreshBatchBody: #"{"tasks":[{"authIndex":"auth-1"}],"rejected":[{"authIndex":"auth-2","error":"unsupported"}]}"#,
            quotaRefreshTaskBodies: [
                "auth-1": [
                    #"{"authIndex":"auth-1","status":"queued"}"#,
                    #"{"authIndex":"auth-1","status":"completed","quota":{"quota":[]}}"#,
                ],
            ],
            quotaCacheResponseBodies: [#"{"items":[]}"#, refreshedCache]
        )
        let model = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client]
        ).makeModel()
        await model.start()

        model.refreshQuota(authIndexes: ["auth-1", "auth-1", " "])
        let finished = await eventually { !model.isRefreshingQuota }
        let calls = await client.calls

        XCTAssertTrue(finished)
        XCTAssertTrue(calls.contains(.refreshQuota(["auth-1"])))
        XCTAssertEqual(calls.filter { $0 == .quotaRefreshStatus("auth-1") }.count, 2)
        XCTAssertEqual(model.quotaCache.value?.items.first?.authIndex, "auth-1")
        XCTAssertEqual(model.quotaRefreshError, "1 个账号刷新失败")
    }

    func testConnectionStateChangeStopsPollingWithoutAnotherRequest() async throws {
        let queued = #"{"authIndex":"auth-1","status":"queued"}"#
        let client = CountingClient(
            authenticated: true,
            quotaRefreshBatchBody: #"{"tasks":[{"authIndex":"auth-1"}]}"#,
            quotaRefreshTaskBodies: ["auth-1": [queued, queued, queued]]
        )
        let model = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client]
        ).makeModel(quotaRefreshPollingInterval: .milliseconds(50))
        await model.start()
        model.refreshQuota(authIndexes: ["auth-1"])
        let started = await eventually {
            await client.calls.contains(.quotaRefreshStatus("auth-1"))
        }
        let countBeforeCancellation = await statusCallCount(client)

        _ = model.beginConnectionStateChange()
        try await Task.sleep(for: .milliseconds(80))
        let countAfterCancellation = await statusCallCount(client)

        XCTAssertTrue(started)
        XCTAssertFalse(model.isRefreshingQuota)
        XCTAssertEqual(countAfterCancellation, countBeforeCancellation)
    }

    func testDuplicateRejectionJoinsExistingRefreshTask() async {
        let client = CountingClient(
            authenticated: true,
            quotaRefreshBatchBody: #"{"tasks":[],"rejected":[{"authIndex":"auth-1","error":"duplicate"}]}"#,
            quotaRefreshTaskBodies: [
                "auth-1": [#"{"authIndex":"auth-1","status":"completed","quota":{"quota":[]}}"#],
            ]
        )
        let model = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client]
        ).makeModel()
        await model.start()

        model.refreshQuota(authIndexes: ["auth-1"])
        let finished = await eventually { !model.isRefreshingQuota }
        let calls = await client.calls

        XCTAssertTrue(finished)
        XCTAssertTrue(calls.contains(.quotaRefreshStatus("auth-1")))
        XCTAssertNil(model.quotaRefreshError)
    }

    func testAuthenticationFailureEndsSession() async {
        let client = CountingClient(
            authenticated: true,
            quotaRefreshError: .authenticationRequired
        )
        let model = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client]
        ).makeModel()
        await model.start()

        model.refreshQuota(authIndexes: ["auth-1"])
        let finished = await eventually { !model.isRefreshingQuota }

        XCTAssertTrue(finished)
        XCTAssertFalse(model.isAuthenticated)
        XCTAssertEqual(model.loginError, "需要重新登录")
        XCTAssertEqual(model.quotaRefreshError, "需要重新登录")
    }

    private func statusCallCount(_ client: CountingClient) async -> Int {
        await client.calls.filter {
            if case .quotaRefreshStatus = $0 { return true }
            return false
        }.count
    }
}
