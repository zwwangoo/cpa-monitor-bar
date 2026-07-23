import Foundation
import XCTest
@testable import CPAModels

final class ModelFixtureTests: XCTestCase {
    func testDecodesHealthSessionAndStatusWithUnknownFields() throws {
        let health: HealthResponse = try fixture("health")
        let session: AuthSessionResponse = try fixture("session")
        let status: KeeperStatusResponse = try fixture("status")

        XCTAssertEqual(health.status, "ok")
        XCTAssertTrue(session.authenticated)
        XCTAssertEqual(session.role, "admin")
        XCTAssertTrue(status.running)
        XCTAssertEqual(status.timezone, "Asia/Shanghai")
        XCTAssertNil(status.lastError)
    }

    func testDecodesKeeperVersion() throws {
        let payload = Data(#"{"version":"v1.13.5"}"#.utf8)

        let response = try JSONDecoder().decode(KeeperVersionResponse.self, from: payload)

        XCTAssertEqual(response.version, "v1.13.5")
    }

    func testOverviewPreservesOptionalCostAndFlexibleNumbers() throws {
        let overview: UsageOverviewResponse = try fixture("overview")

        XCTAssertEqual(overview.usage?.totalRequests, 42)
        XCTAssertEqual(overview.usage?.totalTokens, 12500)
        XCTAssertEqual(overview.summary?.rpm, 3.5)
        XCTAssertEqual(overview.summary?.totalCost, 1.25)
        XCTAssertEqual(overview.summary?.costAvailable, true)
        XCTAssertEqual(overview.serviceHealth?.successRate, 97.5)
        XCTAssertEqual(overview.successRate, 97.5)
    }

    func testOverviewDerivesSuccessRateWhenKeeperOmitsServiceHealth() throws {
        let payload = Data(#"""
        {
          "usage": {
            "total_requests": 145,
            "success_count": 142,
            "failure_count": 3,
            "total_tokens": 14765711
          },
          "summary": {"request_count": 145},
          "timezone": "Asia/Shanghai"
        }
        """#.utf8)

        let overview = try JSONDecoder().decode(
            UsageOverviewResponse.self,
            from: payload
        )

        XCTAssertNil(overview.serviceHealth)
        XCTAssertEqual(
            try XCTUnwrap(overview.successRate),
            142.0 / 145.0 * 100,
            accuracy: 0.0001
        )
    }

    func testOverviewKeepsSuccessRateUnavailableWhenThereAreNoRequests() throws {
        let payload = Data(#"{"usage":{"total_requests":0,"success_count":0,"failure_count":0}}"#.utf8)

        let overview = try JSONDecoder().decode(
            UsageOverviewResponse.self,
            from: payload
        )

        XCTAssertNil(overview.successRate)
    }

    func testAnalysisCompositionDecode() throws {
        let analysis: UsageAnalysisResponse = try fixture("analysis")

        XCTAssertEqual(analysis.modelComposition.first?.label, "gpt-example")
        XCTAssertEqual(analysis.modelComposition.first?.percent, 75)
        XCTAssertEqual(analysis.aiProviderComposition.first?.label, "Example Provider")
        XCTAssertEqual(analysis.tokenUsage.first?.costUSD, 1.25)
    }

    func testFixtureRoundTrip() throws {
        let source: UsageAnalysisResponse = try fixture("analysis")
        let encoded = try JSONEncoder().encode(source)
        let decoded = try JSONDecoder().decode(UsageAnalysisResponse.self, from: encoded)

        XCTAssertEqual(decoded, source)
    }

    func testMissingNewFieldsRemainCompatible() throws {
        let minimum = Data(#"{"authenticated":false,"future_field":{"nested":true}}"#.utf8)
        let session = try JSONDecoder().decode(AuthSessionResponse.self, from: minimum)

        XCTAssertFalse(session.authenticated)
        XCTAssertNil(session.role)
    }

    func testFlexibleIntegerDoesNotTruncateFractionalValues() throws {
        let payload = Data(
            #"{"total_requests":"42.5","success_count":0,"failure_count":0,"total_tokens":0}"#.utf8
        )

        let totals = try JSONDecoder().decode(UsageTotals.self, from: payload)

        XCTAssertNil(totals.totalRequests)
    }

    func testFlexibleDoubleRejectsNonFiniteStringValues() throws {
        let payload = Data(
            #"{"model_composition":[{"percent":"nan","cost_usd":"inf"}]}"#.utf8
        )

        let analysis = try JSONDecoder().decode(UsageAnalysisResponse.self, from: payload)

        XCTAssertNil(analysis.modelComposition.first?.percent)
        XCTAssertNil(analysis.modelComposition.first?.costUSD)
    }

    func testAnalysisAcceptsStringEncodedDiagnosticMetrics() throws {
        let payload = Data(#"""
        {
          "token_usage":[{"cost_available":"true"}],
          "cost_breakdown":{"total_cost_usd":"1.25","cost_available":"1"},
          "model_efficiency":[{"requests":"4","total_tokens":"800","cost_usd":"1.25","cache_read_rate":"25"}],
          "latency_diagnostics":{"points":[{"ttft_ms":"1","latency_ms":"3"}],"density":[{"count":"1","intensity":"0.5"}],"total_points":"1","sampled":"false","p95_latency_ms":"1200"}
        }
        """#.utf8)

        let analysis = try JSONDecoder().decode(UsageAnalysisResponse.self, from: payload)

        XCTAssertEqual(analysis.tokenUsage.first?.costAvailable, true)
        XCTAssertEqual(analysis.costBreakdown?.totalCostUSD, 1.25)
        XCTAssertEqual(analysis.costBreakdown?.costAvailable, true)
        XCTAssertEqual(analysis.modelEfficiency.first?.totalTokens, 800)
        XCTAssertEqual(analysis.latencyDiagnostics?.points?.first?.ttftMS, 1)
        XCTAssertEqual(analysis.latencyDiagnostics?.sampled, false)
    }

    func testDecodesRequestEventsForTodayList() throws {
        let payload = Data(#"""
        {
          "events":[{
            "id":"42","timestamp":"2026-07-21T10:00:00Z","model":"gpt-5.4",
            "api_key":"sk-test***7890",
            "source":"codex-account.json","source_type":"auth-file",
            "endpoint":"POST /v1/messages",
            "failed":false,"ttft_ms":"250","latency_ms":"1250",
            "tokens":{"input_tokens":"100","output_tokens":20,"reasoning_tokens":5,
              "cache_read_tokens":10,"cache_creation_tokens":0,"total_tokens":"135"}
          }],
          "total_count":"1397","page":1,"page_size":20,"total_pages":70
        }
        """#.utf8)

        let response = try JSONDecoder().decode(UsageEventsResponse.self, from: payload)

        XCTAssertEqual(response.totalCount, 1_397)
        XCTAssertEqual(response.events.first?.model, "gpt-5.4")
        XCTAssertEqual(response.events.first?.apiKey, "sk-test***7890")
        XCTAssertEqual(response.events.first?.sourceType, "auth-file")
        XCTAssertEqual(response.events.first?.endpoint, "POST /v1/messages")
        XCTAssertEqual(response.events.first?.ttftMS, 250)
        XCTAssertEqual(response.events.first?.latencyMS, 1_250)
        XCTAssertEqual(response.events.first?.tokens?.totalTokens, 135)
    }

    func testDecodesCredentialNamesAndFiveHourHealth() throws {
        let payload = Data(#"""
        {
          "identities":[{
            "id":"1","name":"raw","displayName":"Codex Primary","auth_type":1,
            "auth_type_name":"Auth file","identity":"auth-1","type":"codex",
            "provider":"codex","prefix":"","file_name":"codex-account.json",
            "disabled":false,"credential_health":{"window_seconds":"18000",
              "total_success":"9","total_failure":1,"success_rate":"90",
              "buckets":[{"start_time":"2026-07-21T09:50:00Z",
                "end_time":"2026-07-21T10:00:00Z","success":"9","failure":1,"rate":"90"}]}
          }],
          "total_count":1,"page":1,"page_size":10,"total_pages":1
        }
        """#.utf8)

        let response = try JSONDecoder().decode(UsageIdentitiesPageResponse.self, from: payload)

        XCTAssertEqual(response.identities.first?.fileName, "codex-account.json")
        XCTAssertEqual(response.identities.first?.displayName, "Codex Primary")
        XCTAssertEqual(response.identities.first?.credentialHealth?.windowSeconds, 18_000)
        XCTAssertEqual(response.identities.first?.credentialHealth?.buckets.first?.failure, 1)
    }

    func testDecodesReadOnlyQuotaCache() throws {
        let payload = Data(#"""
        {"items":[{"auth_index":"auth-1","file_name":"codex-account.json",
          "status":"completed","quota":{"id":"auth-1","quota":[{
            "key":"rate_limit.primary_window","label":"5h",
            "usedPercent":"20","remainingFraction":"0.8",
            "resetAt":"2026-07-21T15:00:00Z"}]}}]}
        """#.utf8)

        let response = try JSONDecoder().decode(UsageQuotaCacheResponse.self, from: payload)

        XCTAssertEqual(response.items.first?.authIndex, "auth-1")
        XCTAssertEqual(response.items.first?.quota?.quota.first?.label, "5h")
        XCTAssertEqual(response.items.first?.quota?.quota.first?.remainingFraction, 0.8)
    }

    func testDecodesQuotaRefreshBatchAndCompletedTask() throws {
        let batchJSON = #"""
        {
          "tasks":[{"authIndex":"auth-1"}],
          "rejected":[{"authIndex":"auth-2","error":"unsupported"}]
        }
        """#
        let taskJSON = #"""
        {
          "authIndex":"auth-1","status":"completed",
          "quota":{"id":"auth-1","quota":[{"key":"5h","remainingFraction":0.7}]}
        }
        """#
        let decoder = JSONDecoder()
        let batch = try decoder.decode(
            UsageQuotaRefreshBatchResponse.self,
            from: Data(batchJSON.utf8)
        )
        let task = try decoder.decode(
            UsageQuotaRefreshTaskResponse.self,
            from: Data(taskJSON.utf8)
        )

        XCTAssertEqual(batch.tasks.first?.authIndex, "auth-1")
        XCTAssertEqual(batch.rejected.first?.error, "unsupported")
        XCTAssertEqual(task.status, "completed")
        XCTAssertEqual(task.quota?.quota.first?.remainingFraction, 0.7)
    }

    private func fixture<T: Decodable>(_ name: String) throws -> T {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json"))
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}
