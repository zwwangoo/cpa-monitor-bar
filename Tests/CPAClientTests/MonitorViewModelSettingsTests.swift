import XCTest
import CPAClient
@testable import CPAMonitorBar

@MainActor
final class MonitorViewModelSettingsTests: XCTestCase {
    func testUserDefaultsPersistsInsecureHTTPConsentByURL() throws {
        let suiteName = "MonitorViewModelSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = UserDefaultsInsecureHTTPConsentStore(defaults: defaults)
        let second = UserDefaultsInsecureHTTPConsentStore(defaults: defaults)

        first.record("http://keeper.example:8080/cpa")

        XCTAssertTrue(second.contains("http://keeper.example:8080/cpa"))
        XCTAssertFalse(second.contains("http://other.example/cpa"))
    }

    func testSavedRemoteHTTPWaitsForConsentWithoutLosingAddress() {
        let dependencies = Dependencies(
            savedURL: "http://keeper.example:8080/cpa/",
            clients: [CountingClient()]
        )

        let model = dependencies.makeModel()

        XCTAssertEqual(model.baseURL, "http://keeper.example:8080/cpa")
        XCTAssertEqual(model.configurationState, .unconfigured)
        XCTAssertEqual(dependencies.clientFactory.callCount, 0)
    }

    func testRemoteHTTPRequiresExplicitConsentBeforeCreatingClient() async {
        let dependencies = Dependencies(
            savedURL: nil,
            clients: [CountingClient(authenticated: false)]
        )
        let model = dependencies.makeModel()

        do {
            try await model.applySettings(
                baseURL: "http://keeper.example:8080/cpa",
                password: "admin-secret"
            )
            XCTFail("Expected insecure HTTP consent error")
        } catch {
            XCTAssertEqual(dependencies.clientFactory.callCount, 0)
            XCTAssertNil(dependencies.baseURLStore.baseURL)
            XCTAssertTrue(error.localizedDescription.contains("HTTP"))
        }
    }

    func testRemoteHTTPConsentIsStoredByNormalizedURL() async throws {
        let client = CountingClient(authenticated: false)
        let dependencies = Dependencies(savedURL: nil, clients: [client])
        let model = dependencies.makeModel()

        try await model.applySettings(
            baseURL: "http://keeper.example:8080/cpa/",
            password: "admin-secret",
            consentToInsecureHTTP: true
        )

        XCTAssertTrue(
            dependencies.insecureHTTPConsentStore.contains(
                "http://keeper.example:8080/cpa"
            )
        )
    }

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

    func testSuccessfulKeeperSwitchDeletesOldPassword() async throws {
        let oldClient = CountingClient(authenticated: true)
        let newClient = CountingClient(authenticated: false)
        let dependencies = Dependencies(
            savedURL: "https://old.example/cpa",
            clients: [oldClient, newClient],
            savedPassword: "old-secret"
        )
        let model = dependencies.makeModel()
        await model.start()
        let oldStore = dependencies.credentialFactory.store

        try await model.applySettings(
            baseURL: "https://new.example/cpa",
            password: "new-secret"
        )

        XCTAssertEqual(oldStore.deleteCount, 1)
        XCTAssertNil(oldStore.savedPassword)
        XCTAssertEqual(dependencies.credentialFactory.latestStore.savedPassword, "new-secret")
        let oldCalls = await oldClient.calls
        XCTAssertTrue(oldCalls.contains(.logout))
    }

    func testFailedKeeperSwitchKeepsOldPassword() async {
        let oldClient = CountingClient(authenticated: true)
        let newClient = CountingClient(
            authenticated: false,
            loginError: .authenticationRequired
        )
        let dependencies = Dependencies(
            savedURL: "https://old.example/cpa",
            clients: [oldClient, newClient],
            savedPassword: "old-secret"
        )
        let model = dependencies.makeModel()
        await model.start()
        let oldStore = dependencies.credentialFactory.store

        do {
            try await model.applySettings(
                baseURL: "https://new.example/cpa",
                password: "wrong-secret"
            )
            XCTFail("Expected settings application to fail")
        } catch {
            XCTAssertEqual(oldStore.deleteCount, 0)
            XCTAssertEqual(oldStore.savedPassword, "old-secret")
        }
    }
}
