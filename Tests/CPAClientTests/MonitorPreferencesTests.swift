import Foundation
import XCTest
@testable import CPAMonitorBar

final class MonitorPreferencesTests: XCTestCase {
    func testUserDefaultsStoreUsesExpectedDefaults() {
        let defaults = makeDefaults()
        let store = UserDefaultsMonitorPreferencesStore(defaults: defaults)

        XCTAssertEqual(store.load().usageRange, .today)
        XCTAssertEqual(store.load().refreshFrequency, .oneMinute)
    }

    func testUserDefaultsStoreRoundTripsPreferences() {
        let defaults = makeDefaults()
        let store = UserDefaultsMonitorPreferencesStore(defaults: defaults)
        let expected = MonitorPreferences(
            usageRange: .yesterday,
            refreshFrequency: .fiveMinutes
        )

        store.save(expected)

        XCTAssertEqual(store.load(), expected)
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "MonitorPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
