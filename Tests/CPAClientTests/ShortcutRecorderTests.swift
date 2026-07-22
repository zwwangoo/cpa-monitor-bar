import AppKit
import XCTest
@testable import CPAMonitorBar

final class ShortcutRecorderTests: XCTestCase {
    func testShortcutRequiresCommandOptionOrControl() {
        XCTAssertFalse(isValidGlobalShortcutModifiers([]))
        XCTAssertFalse(isValidGlobalShortcutModifiers([.shift]))
        XCTAssertTrue(isValidGlobalShortcutModifiers([.command]))
        XCTAssertTrue(isValidGlobalShortcutModifiers([.option, .shift]))
        XCTAssertTrue(isValidGlobalShortcutModifiers([.control]))
    }

    func testShortcutDisplayUsesMacModifierOrderAndKeyLabel() {
        let shortcut = GlobalShortcut(
            keyCode: 8,
            modifiers: [.control, .option, .command, .shift],
            keyLabel: "C"
        )

        XCTAssertEqual(shortcutDisplayText(shortcut), "⌃⌥⇧⌘C")
        XCTAssertEqual(shortcutDisplayText(nil), "未设置")
    }

    func testEventModifiersKeepOnlySupportedFlags() {
        let flags: NSEvent.ModifierFlags = [
            .command,
            .option,
            .control,
            .shift,
            .capsLock,
        ]

        XCTAssertEqual(
            globalShortcutModifiers(from: flags),
            [.command, .option, .control, .shift]
        )
    }

    func testShortcutKeyLabelHandlesSpaceAndLetters() {
        XCTAssertEqual(shortcutKeyLabel(keyCode: 49, characters: " "), "Space")
        XCTAssertEqual(shortcutKeyLabel(keyCode: 8, characters: "c"), "C")
        XCTAssertNil(shortcutKeyLabel(keyCode: 8, characters: nil))
    }
}
