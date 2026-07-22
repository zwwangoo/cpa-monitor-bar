import AppKit
import XCTest
@testable import CPAMonitorBar

final class PanelPointerPlacementTests: XCTestCase {
    private let screen = NSRect(x: 0, y: 0, width: 1_440, height: 900)
    private let panelSize = NSSize(width: 420, height: 600)

    func testPlacesPanelBelowPointerUsingTopCenterAnchor() {
        let origin = PanelPointerPlacement.origin(
            panelSize: panelSize,
            pointer: NSPoint(x: 720, y: 800),
            visibleFrame: screen
        )

        XCTAssertEqual(origin.x, 510)
        XCTAssertEqual(origin.y, 188)
    }

    func testPlacesPanelAbovePointerWhenThereIsNotEnoughSpaceBelow() {
        let origin = PanelPointerPlacement.origin(
            panelSize: panelSize,
            pointer: NSPoint(x: 720, y: 280),
            visibleFrame: screen
        )

        XCTAssertEqual(origin.x, 510)
        XCTAssertEqual(origin.y, 292)
    }

    func testClampsPanelWithinHorizontalVisibleBounds() {
        let leftOrigin = PanelPointerPlacement.origin(
            panelSize: panelSize,
            pointer: NSPoint(x: 10, y: 800),
            visibleFrame: screen
        )
        let rightOrigin = PanelPointerPlacement.origin(
            panelSize: panelSize,
            pointer: NSPoint(x: 1_430, y: 800),
            visibleFrame: screen
        )

        XCTAssertEqual(leftOrigin.x, 8)
        XCTAssertEqual(rightOrigin.x, 1_012)
    }

    func testClampsOversizedPanelWithinVerticalVisibleBounds() {
        let origin = PanelPointerPlacement.origin(
            panelSize: NSSize(width: 420, height: 1_000),
            pointer: NSPoint(x: 720, y: 450),
            visibleFrame: screen
        )

        XCTAssertEqual(origin.y, 8)
    }
}
