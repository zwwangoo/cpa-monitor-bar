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
        presentation.pin()
        XCTAssertTrue(presentation.isPinned)

        presentation.unpin()
        XCTAssertFalse(presentation.isPinned)
        XCTAssertEqual(presentation.selectedTab, .events)
    }

    func testPinnedWindowFloatsAndMovesAsOnePanel() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        configurePinnedMonitorWindow(window)

        XCTAssertEqual(window.identifier?.rawValue, MonitorWindowPresentation.pinnedWindowID)
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.level, .floating)
        XCTAssertTrue(window.isMovableByWindowBackground)
        XCTAssertTrue(window.collectionBehavior.contains(.moveToActiveSpace))
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(window.standardWindowButton(.closeButton)?.isHidden == true)
        XCTAssertTrue(window.standardWindowButton(.miniaturizeButton)?.isHidden == true)
        XCTAssertTrue(window.standardWindowButton(.zoomButton)?.isHidden == true)
    }
}
