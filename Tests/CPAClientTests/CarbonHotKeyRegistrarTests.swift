import Carbon.HIToolbox
import XCTest
@testable import CPAMonitorBar

final class CarbonHotKeyRegistrarTests: XCTestCase {
    func testCarbonModifiersMapEverySupportedFlag() {
        let flags: GlobalShortcutModifiers = [.command, .option, .control, .shift]

        XCTAssertEqual(
            carbonModifiers(flags),
            UInt32(cmdKey | optionKey | controlKey | shiftKey)
        )
    }

    func testCarbonModifiersLeaveMissingFlagsUnset() {
        XCTAssertEqual(carbonModifiers([.command]), UInt32(cmdKey))
        XCTAssertEqual(carbonModifiers([]), 0)
    }
}
