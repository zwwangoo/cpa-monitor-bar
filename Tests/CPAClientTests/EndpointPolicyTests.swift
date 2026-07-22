import Foundation
import XCTest
@testable import CPAClient

final class EndpointPolicyTests: XCTestCase {
    func testNormalizesServiceRootAndBuildsHealthOutsideAPIPrefix() throws {
        let root = try CPAServiceRoot("https://example.com/cpa/")

        XCTAssertEqual(root.url.absoluteString, "https://example.com/cpa")
        XCTAssertEqual(
            try root.url(for: .health).absoluteString,
            "https://example.com/cpa/healthz"
        )
        XCTAssertEqual(
            try root.url(for: .status).absoluteString,
            "https://example.com/cpa/api/v1/status"
        )
        XCTAssertEqual(
            try root.url(for: .overview).absoluteString,
            "https://example.com/cpa/api/v1/usage/overview?range=today"
        )
        XCTAssertEqual(
            try root.url(for: .analysis).absoluteString,
            "https://example.com/cpa/api/v1/usage/analysis?range=today"
        )
        XCTAssertEqual(
            try root.url(for: .usageEvents).absoluteString,
            "https://example.com/cpa/api/v1/usage/events?range=today&page=1&page_size=20"
        )
        XCTAssertEqual(
            try root.url(for: .authFiles).absoluteString,
            "https://example.com/cpa/api/v1/usage/identities/page?auth_type=1&page=1&page_size=10"
        )
    }

    func testAddsCPAPathForBareHost() throws {
        let root = try CPAServiceRoot("https://example.com")
        XCTAssertEqual(root.url.absoluteString, "https://example.com/cpa")
    }

    func testAllowsHTTPForRemoteKeeper() throws {
        let root = try CPAServiceRoot("http://keeper.example:8080/cpa/")

        XCTAssertEqual(root.url.absoluteString, "http://keeper.example:8080/cpa")
        XCTAssertEqual(
            try root.url(for: .version).absoluteString,
            "http://keeper.example:8080/cpa/api/v1/version"
        )
    }

    func testBuildsSupportedUsageRangeQueries() throws {
        let root = try CPAServiceRoot("https://example.com/cpa")

        XCTAssertEqual(
            try root.url(for: .overview, usageRange: .last8Hours).query,
            "range=8h"
        )
        XCTAssertEqual(
            try root.url(for: .analysis, usageRange: .today).query,
            "range=today"
        )
        XCTAssertEqual(
            try root.url(for: .usageEvents, usageRange: .yesterday).query,
            "range=yesterday&page=1&page_size=20"
        )
        XCTAssertEqual(
            try root.url(
                for: .usageEvents,
                usageRange: .today,
                page: 3,
                pageSize: 20
            ).query,
            "range=today&page=3&page_size=20"
        )
    }

    func testRejectsUnsafeServiceRoots() {
        let rejected = [
            "ftp://example.com/cpa",
            "https://example.com/cpa/../admin",
            "https://example.com/%2e%2e/cpa",
            "https://example.com/cpa/extra",
            "https://user@example.com/cpa",
            "https://example.com/cpa?token=value",
        ]

        for value in rejected {
            XCTAssertThrowsError(try CPAServiceRoot(value), value)
        }
    }

    func testNormalizesLocalhostHTTP() throws {
        XCTAssertEqual(
            try CPAServiceRoot("http://localhost:8080/cpa").url.absoluteString,
            "http://localhost:8080/cpa"
        )
        XCTAssertEqual(
            try CPAServiceRoot("http://127.0.0.1:8080").url.absoluteString,
            "http://127.0.0.1:8080/cpa"
        )
    }

    func testEndpointMethodsAreFixed() {
        let gets: [CPAEndpoint] = [
            .health, .session, .status, .version, .overview, .realtime, .analysis,
            .usageEvents, .authFiles, .providers,
        ]
        for endpoint in gets {
            XCTAssertEqual(endpoint.method, .get)
        }
        XCTAssertEqual(CPAEndpoint.login.method, .post)
        XCTAssertEqual(CPAEndpoint.logout.method, .post)
        XCTAssertEqual(CPAEndpoint.quotaCache.method, .post)
        XCTAssertEqual(CPAEndpoint.quotaRefresh.method, .post)
    }

    func testPolicyRejectsQuotaAndManagementPaths() throws {
        let policy = CPARequestPolicy()
        let forbidden = [
            "/cpa/api/v1/quota/inspection",
            "/cpa/api/v1/quota/reset",
            "/cpa/api/v1/auth-files",
            "/cpa/api/v1/pricing/update",
            "/cpa/api/v1/admin/users",
        ]

        for path in forbidden {
            XCTAssertThrowsError(try policy.validate(method: .get, path: path), path)
            XCTAssertThrowsError(try policy.validate(method: .post, path: path), path)
        }
    }

    func testPolicyAllowsOnlyQuotaRefreshAndSingleTaskStatusPath() throws {
        let policy = CPARequestPolicy()
        let refreshPath = "/cpa/api/v1/quota/refresh"

        XCTAssertNoThrow(try policy.validate(method: .post, path: refreshPath))
        XCTAssertNoThrow(try policy.validate(method: .get, path: "\(refreshPath)/auth-1"))

        let rejected = [
            refreshPath,
            "\(refreshPath)/",
            "\(refreshPath)/auth-1/extra",
            "\(refreshPath)/.",
            "\(refreshPath)/..",
            "\(refreshPath)/%2e%2e",
            "\(refreshPath)/auth%2Fextra",
            "\(refreshPath)/%252525252e%252525252e",
            "\(refreshPath)/auth%252525252Fextra",
        ]
        for path in rejected {
            XCTAssertThrowsError(try policy.validate(method: .get, path: path), path)
        }
    }

    func testPolicyAllowsOnlySignedMethodPathPairs() throws {
        let policy = CPARequestPolicy()
        for endpoint in CPAEndpoint.allCases {
            XCTAssertNoThrow(
                try policy.validate(method: endpoint.method, path: endpoint.path)
            )
        }
        XCTAssertThrowsError(
            try policy.validate(method: .post, path: CPAEndpoint.status.path)
        )
        XCTAssertThrowsError(
            try policy.validate(method: .get, path: CPAEndpoint.login.path)
        )
    }
}
