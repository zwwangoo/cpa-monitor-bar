import AppKit
import XCTest
@testable import CPAMonitorBar

@MainActor
final class PinnedPopoverAnchorTests: XCTestCase {
    func testAnchorIsInvisibleFixedAndAvailableAcrossSpaces() {
        let anchor = PinnedPopoverAnchor(
            frame: NSRect(x: 100, y: 200, width: 28, height: 24)
        )

        XCTAssertTrue(anchor.window.ignoresMouseEvents)
        XCTAssertFalse(anchor.window.isOpaque)
        XCTAssertFalse(anchor.window.hasShadow)
        XCTAssertTrue(anchor.window.isExcludedFromWindowsMenu)
        XCTAssertTrue(anchor.window.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(anchor.window.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertTrue(anchor.window.collectionBehavior.contains(.stationary))

        anchor.close()
    }

    func testDragMovesAnchorFromGestureStartAndAllowsAnotherDisplay() {
        let anchor = PinnedPopoverAnchor(
            frame: NSRect(x: 100, y: 200, width: 28, height: 24)
        )

        anchor.drag(translation: CGSize(width: 40, height: 25), ended: false)
        XCTAssertEqual(anchor.window.frame.origin, NSPoint(x: 140, y: 175))

        anchor.drag(translation: CGSize(width: 60, height: 30), ended: true)
        XCTAssertEqual(anchor.window.frame.origin, NSPoint(x: 160, y: 170))

        anchor.drag(translation: CGSize(width: -10, height: -5), ended: true)
        XCTAssertEqual(anchor.window.frame.origin, NSPoint(x: 150, y: 175))

        anchor.close()
    }
}
