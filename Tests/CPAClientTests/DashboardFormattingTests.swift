import Foundation
import XCTest
import CPAModels
@testable import CPAMonitorBar

final class DashboardFormattingTests: XCTestCase {
    func testQuotaRemainingPercentPrefersRemainingFraction() throws {
        let row = try decodeQuota(
            #"{"key":"primary","remainingFraction":"0.72","usedPercent":"90"}"#
        )

        XCTAssertEqual(quotaRemainingPercent(row), 72)
    }

    func testQuotaRemainingPercentFallsBackToUsedPercent() throws {
        let row = try decodeQuota(#"{"key":"primary","usedPercent":"20"}"#)

        XCTAssertEqual(quotaRemainingPercent(row), 80)
    }

    func testQuotaRemainingPercentFallsBackToAbsoluteLimit() throws {
        let row = try decodeQuota(#"{"key":"primary","remaining":"25","limit":"100"}"#)

        XCTAssertEqual(quotaRemainingPercent(row), 25)
    }

    func testQuotaRemainingPercentIsClamped() throws {
        let row = try decodeQuota(#"{"key":"primary","usedPercent":"120"}"#)

        XCTAssertEqual(quotaRemainingPercent(row), 0)
    }

    func testVisibleAuthFilesExcludeOnlyDisabledCredentials() throws {
        let payload = Data(#"""
        {"identities":[
          {"id":"1","identity":"active","disabled":false},
          {"id":"2","identity":"disabled","disabled":true},
          {"id":"3","identity":"unknown-state"}
        ]}
        """#.utf8)
        let response = try JSONDecoder().decode(UsageIdentitiesPageResponse.self, from: payload)

        XCTAssertEqual(
            visibleAuthFiles(response.identities).compactMap(\.identity),
            ["active", "unknown-state"]
        )
    }

    func testAuthAccountNamePrefersDisplayNameWithoutShowingFileName() throws {
        let payload = Data(#"{"id":"1","displayName":"account@example.com","name":"fallback","file_name":"codex-account@example.com-plus.json"}"#.utf8)
        let identity = try JSONDecoder().decode(UsageIdentity.self, from: payload)

        XCTAssertEqual(authAccountName(identity), "account@example.com")
    }

    func testAuthAccountNameFallsBackToNameThenUnknownAccount() throws {
        let named = try JSONDecoder().decode(
            UsageIdentity.self,
            from: Data(#"{"id":"1","name":"Primary account","file_name":"secret.json"}"#.utf8)
        )
        let unnamed = try JSONDecoder().decode(
            UsageIdentity.self,
            from: Data(#"{"id":"2","file_name":"secret.json"}"#.utf8)
        )

        XCTAssertEqual(authAccountName(named), "Primary account")
        XCTAssertEqual(authAccountName(unnamed), "未知账号")
    }

    func testTokenShareDimensionsMapAnalysisCompositionGroups() throws {
        let payload = Data(#"""
        {
          "model_composition":[{"label":"model-a","percent":40}],
          "api_key_composition":[{"label":"key-a","percent":30}],
          "auth_files_composition":[{
            "label":"auth-a","percent":20,"cost_usd":66.938526
          }],
          "ai_provider_composition":[{"label":"provider-a","percent":10}]
        }
        """#.utf8)
        let response = try JSONDecoder().decode(UsageAnalysisResponse.self, from: payload)

        XCTAssertEqual(tokenShareItems(for: .models, in: response).first?.label, "model-a")
        XCTAssertEqual(tokenShareItems(for: .apiKeys, in: response).first?.label, "key-a")
        XCTAssertEqual(tokenShareItems(for: .authFiles, in: response).first?.costUSD, 66.938526)
        XCTAssertEqual(tokenShareItems(for: .aiProviders, in: response).first?.label, "provider-a")
    }

    func testTokenShareKeepsEveryItemInSelectedDimension() throws {
        let payload = Data(#"{"model_composition":[{"key":"a"},{"key":"b"},{"key":"c"}]}"#.utf8)
        let response = try JSONDecoder().decode(UsageAnalysisResponse.self, from: payload)

        XCTAssertEqual(tokenShareItems(for: .models, in: response).count, 3)
    }

    func testTokenSharePercentClampsBackendValue() throws {
        let payload = Data(#"{"model_composition":[{"percent":"120"}]}"#.utf8)
        let response = try JSONDecoder().decode(UsageAnalysisResponse.self, from: payload)
        let item = try XCTUnwrap(response.modelComposition.first)

        XCTAssertEqual(tokenSharePercent(item), 100)
    }

    func testAuthFileCategoriesMatchKeeperOrderAndFilterLoadedFiles() throws {
        let payload = Data(#"""
        {"identities":[
          {"id":"1","file_name":"codex.json","type":"codex","disabled":false},
          {"id":"2","file_name":"claude.json","type":"claude","disabled":false},
          {"id":"3","file_name":"gemini.json","type":"gemini-cli","disabled":false},
          {"id":"4","file_name":"xai.json","type":"xai","disabled":true}
        ]}
        """#.utf8)
        let response = try JSONDecoder().decode(UsageIdentitiesPageResponse.self, from: payload)
        let identities = visibleAuthFiles(response.identities)

        XCTAssertEqual(
            visibleAuthFileCategories(identities),
            [.all, .claude, .codex, .geminiCLI]
        )
        XCTAssertEqual(
            filterAuthFiles(identities, matching: .codex).compactMap(\.fileName),
            ["codex.json"]
        )
    }

    func testCompactLatencyUsesMillisecondsAndSeconds() {
        XCTAssertEqual(compactLatency(nil), "—")
        XCTAssertEqual(compactLatency(125), "125ms")
        XCTAssertEqual(compactLatency(1_250), "1.2s")
    }

    func testEventLatencyCombinesTTFTAndTotalLatency() {
        XCTAssertEqual(eventLatencyText(ttftMS: 602, latencyMS: 5_800), "602ms/5.8s")
        XCTAssertEqual(eventLatencyText(ttftMS: nil, latencyMS: nil), "—/—")
    }

    func testAPIKeyDisplayKeepsMaskedAndShortValues() {
        XCTAssertEqual(displayAPIKey("sk-test***7890"), "sk-test***7890")
        XCTAssertEqual(displayAPIKey("default"), "default")
        XCTAssertEqual(displayAPIKey(nil), "—")
    }

    func testAPIKeyDisplayMasksUnexpectedLongRawValue() {
        XCTAssertEqual(
            displayAPIKey("sk-live-1234567890abcdef"),
            "sk-l••••cdef"
        )
    }

    func testEventCountSummaryOnlyShowsTotalCount() {
        XCTAssertEqual(eventCountSummary(totalCount: 2_351), "共 2,351 条")
    }

    func testRequestTypeComesFromEndpointMethod() throws {
        let post = try decodeEvent(#"{"endpoint":"POST /v1/messages"}"#)
        let get = try decodeEvent(#"{"endpoint":"get /v1/realtime"}"#)
        let missing = try decodeEvent("{}")

        XCTAssertEqual(requestType(for: post), "SSE")
        XCTAssertEqual(requestType(for: get), "WS")
        XCTAssertEqual(requestType(for: missing), "—")
    }

    private func decodeQuota(_ json: String) throws -> UsageQuotaRow {
        try JSONDecoder().decode(UsageQuotaRow.self, from: Data(json.utf8))
    }

    private func decodeEvent(_ json: String) throws -> UsageEvent {
        try JSONDecoder().decode(UsageEvent.self, from: Data(json.utf8))
    }
}
