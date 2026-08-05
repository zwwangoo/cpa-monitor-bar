import AppKit
import XCTest
@testable import CPAMonitorBar

@MainActor
final class SettingsWindowPresentationTests: XCTestCase {
    func testPresentationOpensThenBringsSettingsForwardImmediatelyAndDeferred() {
        let recorder = StepRecorder()
        let actions = SettingsPresentationActions(
            bringToFront: { recorder.append("front") },
            deferAction: { action in
                recorder.append("defer")
                action()
            }
        )

        presentSettings(
            openSettings: { recorder.append("open") },
            actions: actions
        )

        XCTAssertEqual(recorder.values, ["open", "front", "defer", "front"])
    }

    func testSettingsWindowCandidateExcludesPanelsAndHiddenWindows() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        let hiddenWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: .titled,
            backing: .buffered,
            defer: false
        )
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 100, height: 100),
            styleMask: .titled,
            backing: .buffered,
            defer: false
        )
        panel.orderFront(nil)
        settingsWindow.orderFront(nil)
        defer {
            panel.orderOut(nil)
            settingsWindow.orderOut(nil)
        }

        let candidate = settingsWindowCandidate(
            in: [panel, hiddenWindow, settingsWindow]
        )

        XCTAssertTrue(candidate === settingsWindow)
    }

    func testBringingSettingsForwardReleasesExistingTextFieldFocus() throws {
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 120),
            styleMask: .titled,
            backing: .buffered,
            defer: false
        )
        let textField = NSSecureTextField(
            frame: NSRect(x: 20, y: 20, width: 160, height: 24)
        )
        settingsWindow.contentView?.addSubview(textField)
        settingsWindow.orderFront(nil)
        defer { settingsWindow.orderOut(nil) }
        XCTAssertTrue(settingsWindow.makeFirstResponder(textField))
        XCTAssertTrue(settingsWindow.firstResponder is NSTextView)

        bringSettingsToFront()

        XCTAssertFalse(settingsWindow.firstResponder is NSTextView)
    }
}

@MainActor
private final class StepRecorder {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}
