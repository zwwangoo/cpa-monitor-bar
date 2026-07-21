import XCTest
@testable import CPAMonitorBar

@MainActor
final class ApplicationBehaviorTests: XCTestCase {
    func testQuitPerformsLogoutBeforeTermination() async {
        var steps: [String] = []

        await performApplicationQuit(
            logout: { steps.append("logout") },
            terminate: { steps.append("terminate") }
        )

        XCTAssertEqual(steps, ["logout", "terminate"])
    }

    func testApplicationVersionIncludesBuildNumber() {
        XCTAssertEqual(
            applicationVersionText(shortVersion: "0.1.0", buildVersion: "7"),
            "0.1.0 (7)"
        )
    }

    func testApplicationVersionHasDevelopmentFallback() {
        XCTAssertEqual(
            applicationVersionText(shortVersion: nil, buildVersion: nil),
            "开发构建"
        )
    }
}
