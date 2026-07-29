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
        XCTAssertTrue(status.running)
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
        XCTAssertEqual(overview.summary?.totalCost, 1.25)
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
    }

    func testAnalysisIgnoresTypeChangesInUnusedSections() throws {
        let payload = Data(#"""
        {
          "api_key_composition":[{"key":"key-a","percent":"25"}],
          "model_composition":[{"label":"gpt-5.4","total_tokens":"800"}],
          "auth_files_composition":[{"label":"account-a","requests":"4"}],
          "ai_provider_composition":[{"label":"provider-a","cost_usd":"1.25"}],
          "token_usage":{"future":true},
          "heatmap":"future-shape",
          "cost_breakdown":[],
          "model_efficiency":{"future":true},
          "latency_diagnostics":"future-shape"
        }
        """#.utf8)

        let analysis = try JSONDecoder().decode(UsageAnalysisResponse.self, from: payload)

        XCTAssertEqual(analysis.apiKeyComposition.first?.key, "key-a")
        XCTAssertEqual(analysis.modelComposition.first?.totalTokens, 800)
        XCTAssertEqual(analysis.authFilesComposition.first?.requests, 4)
        XCTAssertEqual(analysis.aiProviderComposition.first?.costUSD, 1.25)
    }

    func testDecodesUsageActivityTimeline() throws {
        let activity: UsageActivityResponse = try fixture("activity")

        XCTAssertEqual(activity.rows, 7)
        XCTAssertEqual(activity.columns, 52)
        XCTAssertEqual(activity.totalSuccess, 42)
        XCTAssertEqual(activity.totalFailure, 2)
        XCTAssertEqual(activity.successRate, 95.4545)
        XCTAssertEqual(activity.blocks.count, 2)
        XCTAssertEqual(activity.blocks.first?.success, 9)
        XCTAssertEqual(activity.blocks.first?.failure, 1)
    }
    func testOverviewIgnoresTypeChangesInUnusedSections() throws {
        let payload = Data(#"""
        {
          "usage":{"total_requests":"42","success_count":"40","failure_count":"2","total_tokens":"12500"},
          "summary":{"request_count":"42","total_cost":"1.25","cost_available":true},
          "service_health":{"success_rate":"95.24","block_details":"future-shape"},
          "series":"future-shape"
        }
        """#.utf8)

        let overview = try JSONDecoder().decode(UsageOverviewResponse.self, from: payload)

        XCTAssertEqual(overview.usage?.totalRequests, 42)
        XCTAssertEqual(overview.usage?.totalTokens, 12_500)
        XCTAssertEqual(overview.summary?.totalCost, 1.25)
        XCTAssertEqual(overview.successRate, 95.24)
    }

    func testEventsIgnoreTypeChangesInUnusedFields() throws {
        let payload = Data(#"""
        {
          "events":[{
            "id":"42","timestamp":"2026-07-21T10:00:00Z","model":"gpt-5.4",
            "api_key":"sk-test***7890","source":"codex-account.json",
            "endpoint":"POST /v1/messages","failed":false,
            "ttft_ms":"250","latency_ms":"1250",
            "tokens":"future-shape","source_type":{"future":true},"speed_tps":[]
          }],
          "total_count":"1","page":1,"page_size":20,"total_pages":1
        }
        """#.utf8)

        let response = try JSONDecoder().decode(UsageEventsResponse.self, from: payload)

        XCTAssertEqual(response.events.first?.apiKey, "sk-test***7890")
        XCTAssertEqual(response.events.first?.endpoint, "POST /v1/messages")
        XCTAssertEqual(response.events.first?.ttftMS, 250)
        XCTAssertEqual(response.events.first?.latencyMS, 1_250)
    }

    func testActivityIgnoresTypeChangesInUnusedFields() throws {
        let payload = Data(#"""
        {
          "rows":"7","columns":"52","total_success":"9","total_failure":"1",
          "success_rate":"90",
          "blocks":[{
            "start_time":"2026-07-21T09:50:00Z","end_time":"2026-07-21T10:00:00Z",
            "success":"9","failure":"1","rate":{"future":true}
          }],
          "window":[],"grain":{"future":true},"timezone":42,
          "bucket_seconds":"future-shape","window_start":false,"window_end":[]
        }
        """#.utf8)

        let activity = try JSONDecoder().decode(UsageActivityResponse.self, from: payload)

        XCTAssertEqual(activity.rows, 7)
        XCTAssertEqual(activity.columns, 52)
        XCTAssertEqual(activity.totalSuccess, 9)
        XCTAssertEqual(activity.totalFailure, 1)
        XCTAssertEqual(activity.blocks.first?.success, 9)
        XCTAssertEqual(activity.blocks.first?.failure, 1)
    }
    func testMissingNewFieldsRemainCompatible() throws {
        let minimum = Data(#"{"authenticated":false,"future_field":{"nested":true}}"#.utf8)
        let session = try JSONDecoder().decode(AuthSessionResponse.self, from: minimum)

        XCTAssertFalse(session.authenticated)
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
        XCTAssertEqual(response.events.first?.endpoint, "POST /v1/messages")
        XCTAssertEqual(response.events.first?.ttftMS, 250)
        XCTAssertEqual(response.events.first?.latencyMS, 1_250)
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

        XCTAssertEqual(response.identities.first?.displayName, "Codex Primary")
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
    }

    private func fixture<T: Decodable>(_ name: String) throws -> T {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json"))
        return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
    }
}
