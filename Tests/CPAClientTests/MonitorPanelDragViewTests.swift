import AppKit
import XCTest
@testable import CPAMonitorBar

@MainActor
final class MonitorPanelDragViewTests: XCTestCase {
    func testMouseDownForwardsEventToNativeWindowDrag() throws {
        let event = try XCTUnwrap(NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: NSPoint(x: 12, y: 8),
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
        var draggedWindow: NSWindow?
        var draggedEvent: NSEvent?
        let dragView = MonitorPanelDragView { window, event in
            draggedWindow = window
            draggedEvent = event
        }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 28, height: 28),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        panel.contentView = dragView

        dragView.mouseDown(with: event)

        XCTAssertTrue(draggedWindow === panel)
        XCTAssertTrue(draggedEvent === event)
    }
}
