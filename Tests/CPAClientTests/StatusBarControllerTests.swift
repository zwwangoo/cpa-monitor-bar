import AppKit
import XCTest
@testable import CPAMonitorBar

@MainActor
final class StatusBarControllerTests: XCTestCase {
    func testShortcutToggleUsesTheSamePersistentPanel() {
        let controller = StatusBarController(
            model: Dependencies(savedURL: nil).makeModel(),
            presentation: MonitorWindowPresentation()
        )
        let panel = controller.panel

        controller.togglePanel()
        XCTAssertTrue(panel.isVisible)

        controller.togglePanel()
        XCTAssertFalse(panel.isVisible)
        XCTAssertTrue(controller.panel === panel)
    }

    func testPointerAnchorPositionsUnpinnedPanelNearCurrentPointer() throws {
        let controller = StatusBarController(
            model: Dependencies(savedURL: nil).makeModel(),
            presentation: MonitorWindowPresentation()
        )
        let pointer = NSEvent.mouseLocation
        let screen = try XCTUnwrap(
            NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main
        )

        controller.togglePanel(anchor: .pointer)

        let expectedOrigin = PanelPointerPlacement.origin(
            panelSize: controller.panel.frame.size,
            pointer: pointer,
            visibleFrame: screen.visibleFrame
        )
        XCTAssertEqual(controller.panel.frame.origin.x, expectedOrigin.x, accuracy: 1)
        XCTAssertEqual(controller.panel.frame.origin.y, expectedOrigin.y, accuracy: 1)
    }

    func testPointerAnchorKeepsPinnedPanelAtItsCurrentPosition() {
        let presentation = MonitorWindowPresentation()
        let controller = StatusBarController(
            model: Dependencies(savedURL: nil).makeModel(),
            presentation: presentation
        )
        controller.togglePin()
        let pinnedOrigin = NSPoint(x: 120, y: 140)
        controller.panel.setFrameOrigin(pinnedOrigin)

        controller.togglePanel(anchor: .pointer)

        XCTAssertEqual(controller.panel.frame.origin, pinnedOrigin)
    }

    func testPanelCanShowWithoutActivatingMenuBarApplication() {
        let controller = StatusBarController(
            model: Dependencies(savedURL: nil).makeModel(),
            presentation: MonitorWindowPresentation()
        )

        XCTAssertTrue(controller.panel.styleMask.contains(.nonactivatingPanel))
        XCTAssertFalse(controller.panel.hidesOnDeactivate)
    }

    func testPinningChangesBehaviorOnTheSamePanelInstance() {
        let presentation = MonitorWindowPresentation()
        let controller = StatusBarController(
            model: Dependencies(savedURL: nil).makeModel(),
            presentation: presentation
        )
        let originalPanel = controller.panel

        XCTAssertFalse(presentation.isPinned)
        XCTAssertEqual(originalPanel.level, .statusBar)
        XCTAssertFalse(originalPanel.hidesOnDeactivate)
        XCTAssertTrue(originalPanel.collectionBehavior.contains(.moveToActiveSpace))
        XCTAssertFalse(originalPanel.collectionBehavior.contains(.canJoinAllSpaces))

        controller.togglePin()

        XCTAssertTrue(controller.panel === originalPanel)
        XCTAssertTrue(presentation.isPinned)
        XCTAssertEqual(originalPanel.level, .floating)
        XCTAssertFalse(originalPanel.hidesOnDeactivate)
        XCTAssertTrue(originalPanel.collectionBehavior.contains(.canJoinAllSpaces))
        XCTAssertTrue(originalPanel.collectionBehavior.contains(.fullScreenAuxiliary))
        XCTAssertFalse(originalPanel.collectionBehavior.contains(.moveToActiveSpace))

        controller.togglePin()

        XCTAssertTrue(controller.panel === originalPanel)
        XCTAssertFalse(presentation.isPinned)
        XCTAssertEqual(originalPanel.level, .statusBar)
        XCTAssertFalse(originalPanel.hidesOnDeactivate)
        XCTAssertTrue(originalPanel.collectionBehavior.contains(.moveToActiveSpace))
        XCTAssertFalse(originalPanel.collectionBehavior.contains(.canJoinAllSpaces))
    }

    func testPanelIsArrowlessAndKeepsActivePopoverMaterial() throws {
        let controller = StatusBarController(
            model: Dependencies(savedURL: nil).makeModel(),
            presentation: MonitorWindowPresentation()
        )
        let panel = controller.panel

        XCTAssertEqual(panel.styleMask, .nonactivatingPanel)
        XCTAssertFalse(panel.isOpaque)
        XCTAssertEqual(panel.backgroundColor, .clear)
        XCTAssertTrue(panel.hasShadow)
        XCTAssertTrue(panel.canBecomeKey)
        XCTAssertFalse(panel.canBecomeMain)
        XCTAssertEqual(panel.animationBehavior, .none)
        XCTAssertEqual(panel.frame.width, 420, accuracy: 1)
        XCTAssertGreaterThan(panel.frame.height, 100)

        let background = try XCTUnwrap(panel.contentView as? NSVisualEffectView)
        XCTAssertEqual(background.material, .popover)
        XCTAssertEqual(background.state, .active)
        XCTAssertEqual(background.blendingMode, .behindWindow)
    }

    func testUnpinnedPanelDefersResignCloseUntilCurrentEventCompletes() async {
        let controller = StatusBarController(
            model: Dependencies(savedURL: nil).makeModel(),
            presentation: MonitorWindowPresentation()
        )
        controller.panel.orderFront(nil)

        controller.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))

        XCTAssertTrue(controller.panel.isVisible)
        await Task.yield()
        XCTAssertFalse(controller.panel.isVisible)
    }

    func testPinnedPanelRemainsVisibleAfterResigningKey() async {
        let controller = StatusBarController(
            model: Dependencies(savedURL: nil).makeModel(),
            presentation: MonitorWindowPresentation()
        )
        controller.togglePin()
        controller.panel.orderFront(nil)

        controller.windowDidResignKey(Notification(name: NSWindow.didResignKeyNotification))

        await Task.yield()
        XCTAssertTrue(controller.panel.isVisible)
    }

    func testStatusItemActionShowsUnpinnedPanelFromInactiveApplication() async {
        let controller = StatusBarController(
            model: Dependencies(savedURL: nil).makeModel(),
            presentation: MonitorWindowPresentation()
        )
        NSApp.deactivate()
        XCTAssertFalse(controller.panel.isVisible)

        controller.perform(NSSelectorFromString("togglePanel"))

        XCTAssertTrue(controller.panel.isVisible)
        XCTAssertNotEqual(controller.panel.frame.origin, .zero)
        await Task.yield()
        XCTAssertTrue(controller.panel.isVisible)
        let placementDescription = "panel=\(controller.panel.frame), mouse=\(NSEvent.mouseLocation), screens=\(NSScreen.screens.map(\.visibleFrame))"
        let visibleScreen = try? XCTUnwrap(NSScreen.screens.first {
            $0.visibleFrame.intersects(controller.panel.frame)
        })
        XCTAssertNotNil(visibleScreen, placementDescription)
        if let visibleScreen {
            XCTAssertGreaterThan(
                controller.panel.frame.midY,
                visibleScreen.visibleFrame.midY,
                placementDescription
            )
        }
    }
}
