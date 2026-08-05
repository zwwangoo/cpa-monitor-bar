import Foundation
import XCTest
@testable import CPAMonitorBar

final class ProviderUsageServiceRootTests: XCTestCase {
    func testPreservesReverseProxyPathAndBuildsUsageURL() throws {
        let root = try ProviderUsageServiceRoot("https://usage.example/sub2api/")
        let date = try XCTUnwrap(
            ISO8601DateFormatter().date(from: "2026-08-05T08:00:00+08:00")
        )

        let url = try root.usageURL(
            date: date,
            timeZoneIdentifier: "Asia/Shanghai"
        )

        XCTAssertEqual(root.url.absoluteString, "https://usage.example/sub2api")
        XCTAssertEqual(url.path, "/sub2api/v1/usage")
        let query = Dictionary(uniqueKeysWithValues:
            (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [])
                .map { ($0.name, $0.value) }
        )
        XCTAssertEqual(query["start_date"] ?? nil, "2026-08-05")
        XCTAssertEqual(query["end_date"] ?? nil, "2026-08-05")
        XCTAssertEqual(query["days"] ?? nil, "1")
        XCTAssertEqual(query["timezone"] ?? nil, "Asia/Shanghai")
    }

    func testRejectsCredentialsQueryFragmentTraversalAndUnsupportedScheme() {
        let invalid = [
            "ftp://usage.example",
            "https://user:secret@usage.example",
            "https://usage.example?token=secret",
            "https://usage.example#fragment",
            "https://usage.example/%2e%2e/admin",
        ]

        for value in invalid {
            XCTAssertThrowsError(try ProviderUsageServiceRoot(value), value)
        }
    }

    func testNormalizesSchemeHostAndTrailingSlashes() throws {
        let root = try ProviderUsageServiceRoot(" HTTPS://USAGE.EXAMPLE:443/path/// ")

        XCTAssertEqual(root.url.absoluteString, "https://usage.example:443/path")
    }
}
