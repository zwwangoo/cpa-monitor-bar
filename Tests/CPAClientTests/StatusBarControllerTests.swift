import AppKit
import XCTest
@testable import CPAMonitorBar

@MainActor
final class StatusBarControllerTests: XCTestCase {
    func testPinningChangesBehaviorOnTheSamePopoverInstance() {
        let presentation = MonitorWindowPresentation()
        let controller = StatusBarController(
            model: Dependencies(savedURL: nil).makeModel(),
            presentation: presentation
        )
        let originalPopover = controller.popover

        XCTAssertEqual(originalPopover.behavior, .transient)

        controller.togglePin()

        XCTAssertTrue(controller.popover === originalPopover)
        XCTAssertTrue(presentation.isPinned)
        XCTAssertEqual(originalPopover.behavior, .applicationDefined)

        controller.togglePin()

        XCTAssertTrue(controller.popover === originalPopover)
        XCTAssertFalse(presentation.isPinned)
        XCTAssertEqual(originalPopover.behavior, .transient)
    }

    func testPinnedPopoverWindowJoinsAllSpacesAndUnpinnedWindowReturnsToActiveSpace() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 700),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.collectionBehavior = [.managed, .moveToActiveSpace]
        window.isMovable = false

        configureMonitorPopoverWindow(window, isPinned: true)

        XCTAssertTrue(window.collectionBehavior.contains(.managed))
        XCTAssertTrue(window.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(window.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertFalse(window.collectionBehavior.contains(.moveToActiveSpace))
        XCTAssertFalse(window.isMovable)

        configureMonitorPopoverWindow(window, isPinned: false)

        XCTAssertTrue(window.collectionBehavior.contains(.managed))
        XCTAssertFalse(window.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertFalse(window.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(window.collectionBehavior.contains(.moveToActiveSpace))
        XCTAssertFalse(window.isMovable)
    }
}
