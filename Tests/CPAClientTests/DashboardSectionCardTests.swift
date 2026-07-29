import XCTest
@testable import CPAMonitorBar

final class DashboardSectionCardTests: XCTestCase {
    func testSectionKindsExposeStableTitlesAndAccessibilityIdentifiers() {
        let sections: [DashboardSectionKind] = [
            .overview,
            .requestHealth,
            .tokenShare,
        ]

        XCTAssertEqual(sections.map(\.title), ["使用概览", "请求健康", "Token 占比"])
        XCTAssertEqual(
            sections.map(\.accessibilityIdentifier),
            [
                "monitor.overview.summary",
                "monitor.overview.request-health",
                "monitor.overview.token-share",
            ]
        )
    }
}
