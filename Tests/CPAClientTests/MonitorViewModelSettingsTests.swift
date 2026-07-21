import XCTest
import CPAClient
@testable import CPAMonitorBar

@MainActor
final class MonitorViewModelSettingsTests: XCTestCase {
    func testApplySettingsUpdatesURLLogsInAndSavesPassword() async throws {
        let client = CountingClient(authenticated: false)
        let dependencies = Dependencies(savedURL: nil, clients: [client])
        let model = dependencies.makeModel()

        try await model.applySettings(
            baseURL: "https://keeper.example/cpa",
            password: "admin-secret"
        )

        XCTAssertEqual(model.baseURL, "https://keeper.example/cpa")
        XCTAssertTrue(model.isAuthenticated)
        XCTAssertEqual(dependencies.credentialFactory.store.savedPassword, "admin-secret")
        let calls = await client.calls
        XCTAssertTrue(calls.contains(.login))
        XCTAssertTrue(calls.contains(.events))
    }

    func testLoadsAndAppliesMonitoringPreferences() async throws {
        let client = CountingClient(authenticated: false)
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client],
            preferences: MonitorPreferences(
                usageRange: .last8Hours,
                refreshFrequency: .twoMinutes
            )
        )
        let model = dependencies.makeModel()

        XCTAssertEqual(model.usageRange, .last8Hours)
        XCTAssertEqual(model.refreshFrequency, .twoMinutes)
        XCTAssertFalse(model.launchAtLoginEnabled)

        try await model.applySettings(
            baseURL: "https://keeper.example/cpa",
            password: "admin-secret",
            usageRange: .yesterday,
            refreshFrequency: .fiveMinutes,
            launchAtLogin: true
        )

        XCTAssertEqual(model.usageRange, .yesterday)
        XCTAssertEqual(model.refreshFrequency, .fiveMinutes)
        XCTAssertTrue(model.launchAtLoginEnabled)
        XCTAssertEqual(
            dependencies.preferencesStore.preferences,
            MonitorPreferences(usageRange: .yesterday, refreshFrequency: .fiveMinutes)
        )
        XCTAssertEqual(dependencies.launchAtLoginController.requestedValues, [true])
        let ranges = await client.lastUsageRanges()
        XCTAssertEqual(ranges.compactMap { $0 }, [.yesterday, .yesterday, .yesterday])
    }

    func testApplySettingsKeepsLoginErrorWhenAuthenticationFails() async {
        let client = CountingClient(
            authenticated: false,
            loginError: .authenticationRequired
        )
        let dependencies = Dependencies(savedURL: nil, clients: [client])
        let model = dependencies.makeModel()

        do {
            try await model.applySettings(
                baseURL: "https://keeper.example/cpa",
                password: "wrong-secret"
            )
            XCTFail("Expected settings application to fail")
        } catch {
            XCTAssertFalse(model.isAuthenticated)
            XCTAssertNotNil(model.loginError)
            XCTAssertNil(dependencies.credentialFactory.store.savedPassword)
        }
    }

    func testCredentialAccountIncludesNormalizedKeeperURL() throws {
        let first = try CPAServiceRoot("https://first.example/cpa/")
        let second = try CPAServiceRoot("https://second.example")

        XCTAssertEqual(
            credentialAccount(for: first),
            "administrator-password:https://first.example/cpa"
        )
        XCTAssertNotEqual(credentialAccount(for: first), credentialAccount(for: second))
    }
}
