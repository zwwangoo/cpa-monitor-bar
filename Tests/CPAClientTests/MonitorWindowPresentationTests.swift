import XCTest
@testable import CPAMonitorBar

@MainActor
final class MonitorWindowPresentationTests: XCTestCase {
    func testPinStateStartsUnpinnedAndOnlyChangesInMemory() {
        let presentation = MonitorWindowPresentation()

        XCTAssertFalse(presentation.isPinned)
        XCTAssertEqual(presentation.selectedTab, .overview)

        presentation.selectedTab = .events
        presentation.togglePin()
        XCTAssertTrue(presentation.isPinned)

        presentation.togglePin()
        XCTAssertFalse(presentation.isPinned)
        XCTAssertEqual(presentation.selectedTab, .events)
    }

}
