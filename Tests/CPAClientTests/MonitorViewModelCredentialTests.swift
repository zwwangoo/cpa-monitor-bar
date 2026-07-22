import XCTest
@testable import CPAMonitorBar

@MainActor
final class MonitorViewModelCredentialTests: XCTestCase {
    func testStartAutomaticallyLogsInWithSavedPassword() async {
        let client = CountingClient(authenticated: false)
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client],
            savedPassword: "saved-secret"
        )
        let model = dependencies.makeModel()

        await model.start()
        let loginPasswords = await client.loginPasswords

        XCTAssertTrue(model.isAuthenticated)
        XCTAssertEqual(loginPasswords, ["saved-secret"])
        XCTAssertEqual(dependencies.credentialFactory.store.loadCount, 1)
    }

    func testEmptyPasswordLoadsSavedPasswordWithoutReplacingIt() async {
        let client = CountingClient(authenticated: false)
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client],
            savedPassword: "saved-secret"
        )
        let model = dependencies.makeModel()

        await model.login(password: "")

        XCTAssertTrue(model.isAuthenticated)
        XCTAssertEqual(dependencies.credentialFactory.store.loadCount, 1)
        XCTAssertEqual(
            dependencies.credentialFactory.store.savedPassword,
            "saved-secret"
        )
        let loginPasswords = await client.loginPasswords
        XCTAssertEqual(loginPasswords, ["saved-secret"])
    }

    func testSavedPasswordLookupDoesNotBlockMainActor() async throws {
        let probe = CredentialLookupResponsivenessProbe()
        let client = CountingClient(authenticated: false)
        let clientFactory = ClientFactoryRecorder(clients: [client])
        let model = MonitorViewModel(
            baseURLStore: MemoryBaseURLStore(baseURL: "https://keeper.example/cpa"),
            preferencesStore: MemoryMonitorPreferencesStore(preferences: MonitorPreferences()),
            insecureHTTPConsentStore: MemoryInsecureHTTPConsentStore(),
            launchAtLoginController: RecordingLaunchAtLoginController(isEnabled: false),
            credentialStoreFactory: { _ in SlowCredentialStore(probe: probe) },
            clientFactory: clientFactory.makeClient,
            pollingInterval: .seconds(60)
        )

        await model.start()
        await Task.yield()

        let delay = try XCTUnwrap(probe.heartbeatDelay)
        XCTAssertLessThan(delay, 0.1)
    }
}

private final class CredentialLookupResponsivenessProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var lookupStartedAt: Date?
    private var heartbeatAt: Date?

    var heartbeatDelay: TimeInterval? {
        lock.withLock {
            guard let lookupStartedAt, let heartbeatAt else { return nil }
            return heartbeatAt.timeIntervalSince(lookupStartedAt)
        }
    }

    func beginSlowLookup() {
        lock.withLock { lookupStartedAt = .now }
        DispatchQueue.main.async { [weak self] in
            self?.lock.withLock { self?.heartbeatAt = .now }
        }
        _ = DispatchSemaphore(value: 0).wait(timeout: .now() + 0.25)
    }
}

private final class SlowCredentialStore: CredentialStore, @unchecked Sendable {
    private let probe: CredentialLookupResponsivenessProbe

    init(probe: CredentialLookupResponsivenessProbe) { self.probe = probe }

    func savePassword(_ password: String) async throws {}

    func loadPassword() async throws -> String? {
        probe.beginSlowLookup()
        return nil
    }

    func deletePassword() async throws {}
}
