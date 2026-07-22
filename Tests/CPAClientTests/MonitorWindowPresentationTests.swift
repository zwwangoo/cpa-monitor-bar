import AppKit
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

    func testPinStateConfiguresNativePopoverDismissBehavior() {
        let presentation = MonitorWindowPresentation()
        let popover = NSPopover()

        configureMonitorPopover(popover, isPinned: presentation.isPinned)
        XCTAssertEqual(popover.behavior, .transient)

        presentation.togglePin()
        configureMonitorPopover(popover, isPinned: presentation.isPinned)
        XCTAssertEqual(popover.behavior, .applicationDefined)

        presentation.togglePin()
        configureMonitorPopover(popover, isPinned: presentation.isPinned)
        XCTAssertEqual(popover.behavior, .transient)
    }
}
