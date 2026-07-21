import Foundation
import CPAClient
import CPAModels
@testable import CPAMonitorBar

@MainActor
final class Dependencies {
    let baseURLStore: MemoryBaseURLStore
    let preferencesStore: MemoryMonitorPreferencesStore
    let launchAtLoginController: RecordingLaunchAtLoginController
    let credentialFactory: CredentialFactoryRecorder
    let clientFactory: ClientFactoryRecorder

    init(
        savedURL: String?,
        clients: [CountingClient] = [],
        preferences: MonitorPreferences = MonitorPreferences(),
        launchAtLogin: Bool = false,
        savedPassword: String? = nil
    ) {
        baseURLStore = MemoryBaseURLStore(baseURL: savedURL)
        preferencesStore = MemoryMonitorPreferencesStore(preferences: preferences)
        launchAtLoginController = RecordingLaunchAtLoginController(isEnabled: launchAtLogin)
        credentialFactory = CredentialFactoryRecorder(savedPassword: savedPassword)
        clientFactory = ClientFactoryRecorder(clients: clients)
    }

    func makeModel(pollingInterval: Duration = .seconds(60)) -> MonitorViewModel {
        MonitorViewModel(
            baseURLStore: baseURLStore,
            preferencesStore: preferencesStore,
            launchAtLoginController: launchAtLoginController,
            credentialStoreFactory: credentialFactory.makeStore,
            clientFactory: clientFactory.makeClient,
            pollingInterval: pollingInterval
        )
    }
}

final class MemoryMonitorPreferencesStore: MonitorPreferencesStoring {
    private(set) var preferences: MonitorPreferences

    init(preferences: MonitorPreferences) { self.preferences = preferences }
    func load() -> MonitorPreferences { preferences }
    func save(_ preferences: MonitorPreferences) { self.preferences = preferences }
}

@MainActor
final class RecordingLaunchAtLoginController: LaunchAtLoginControlling {
    private(set) var isEnabled: Bool
    private(set) var requestedValues: [Bool] = []

    init(isEnabled: Bool) { self.isEnabled = isEnabled }

    func setEnabled(_ enabled: Bool) throws {
        requestedValues.append(enabled)
        isEnabled = enabled
    }
}

final class MemoryBaseURLStore: BaseURLStoring {
    var baseURL: String?

    init(baseURL: String?) { self.baseURL = baseURL }
    func loadBaseURL() -> String? { baseURL }
    func saveBaseURL(_ value: String) { baseURL = value }
}

@MainActor
final class ClientFactoryRecorder {
    private var clients: [CountingClient]
    private(set) var callCount = 0

    init(clients: [CountingClient]) { self.clients = clients }

    func makeClient(_ root: CPAServiceRoot) -> any CPAServiceClient {
        callCount += 1
        guard !clients.isEmpty else { fatalError("Missing client for \(root.url)") }
        return clients.removeFirst()
    }
}

@MainActor
final class CredentialFactoryRecorder {
    let store: RecordingCredentialStore
    private(set) var callCount = 0

    init(savedPassword: String?) {
        store = RecordingCredentialStore(savedPassword: savedPassword)
    }

    func makeStore(_ root: CPAServiceRoot) -> any CredentialStore {
        _ = root
        callCount += 1
        return store
    }
}

final class RecordingCredentialStore: CredentialStore, @unchecked Sendable {
    private(set) var loadCount = 0
    private(set) var savedPassword: String?

    init(savedPassword: String?) {
        self.savedPassword = savedPassword
    }

    func savePassword(_ password: String) throws { savedPassword = password }
    func loadPassword() throws -> String? {
        loadCount += 1
        return savedPassword
    }
}

actor CountingClient: CPAServiceClient {
    enum Call: Equatable {
        case health, session, status, version, overview, realtime, analysis
        case events, authFiles, providers, quotaCache([String])
        case login, logout
    }

    private(set) var calls: [Call] = []
    private(set) var overviewRanges: [UsageTimeRange] = []
    private(set) var analysisRanges: [UsageTimeRange] = []
    private(set) var eventRanges: [UsageTimeRange] = []
    private(set) var eventPageRequests: [Int] = []
    private(set) var loginPasswords: [String] = []
    private var authenticated: Bool
    private var remainingHealthErrors: [CPAClientError]
    private let healthStatus: String
    private let keeperRunning: Bool
    private let loginError: CPAClientError?
    private let eventResponseBodies: [Int: String]

    init(
        authenticated: Bool = false,
        healthError: CPAClientError? = nil,
        healthStatus: String = "ok",
        keeperRunning: Bool = true,
        loginError: CPAClientError? = nil,
        eventResponseBodies: [Int: String] = [:]
    ) {
        self.authenticated = authenticated
        remainingHealthErrors = healthError.map { [$0] } ?? []
        self.healthStatus = healthStatus
        self.keeperRunning = keeperRunning
        self.loginError = loginError
        self.eventResponseBodies = eventResponseBodies
    }

    func health() async throws -> HealthResponse {
        calls.append(.health)
        if !remainingHealthErrors.isEmpty { throw remainingHealthErrors.removeFirst() }
        return try decode(#"{"status":"\#(healthStatus)"}"#)
    }

    func session() async throws -> AuthSessionResponse {
        calls.append(.session)
        return try decode(#"{"authenticated":\#(authenticated)}"#)
    }

    func status() async throws -> KeeperStatusResponse {
        calls.append(.status)
        return try decode(#"{"running":\#(keeperRunning)}"#)
    }

    func version() async throws -> KeeperVersionResponse {
        calls.append(.version)
        return try decode(#"{"version":"v1.13.5"}"#)
    }

    func overview(range: UsageTimeRange) async throws -> UsageOverviewResponse {
        calls.append(.overview)
        overviewRanges.append(range)
        return try decode("{}")
    }

    func realtime() async throws -> RealtimeOverviewResponse {
        calls.append(.realtime)
        return try decode("{}")
    }

    func analysis(range: UsageTimeRange) async throws -> UsageAnalysisResponse {
        calls.append(.analysis)
        analysisRanges.append(range)
        return try decode("{}")
    }

    func events(
        range: UsageTimeRange,
        page: Int,
        pageSize: Int
    ) async throws -> UsageEventsResponse {
        calls.append(.events)
        eventRanges.append(range)
        eventPageRequests.append(page)
        _ = pageSize
        return try decode(
            eventResponseBodies[page] ?? #"{"events":[],"total_count":0,"page":1,"total_pages":1}"#
        )
    }

    func authFiles() async throws -> UsageIdentitiesPageResponse {
        calls.append(.authFiles)
        return try decode(#"{"identities":[{"id":"1","identity":"auth-1"}]}"#)
    }

    func providers() async throws -> UsageIdentitiesPageResponse {
        calls.append(.providers)
        return try decode(#"{"identities":[]}"#)
    }

    func quotaCache(authIndexes: [String]) async throws -> UsageQuotaCacheResponse {
        calls.append(.quotaCache(authIndexes))
        return try decode(#"{"items":[]}"#)
    }

    func login(password: String) async throws {
        calls.append(.login)
        loginPasswords.append(password)
        if let loginError { throw loginError }
        authenticated = true
    }

    func logout() async throws {
        calls.append(.logout)
        authenticated = false
    }

    func lastUsageRanges() -> [UsageTimeRange?] {
        [overviewRanges.last, analysisRanges.last, eventRanges.last]
    }

    private func decode<Value: Decodable>(_ json: String) throws -> Value {
        try JSONDecoder().decode(Value.self, from: Data(json.utf8))
    }
}

func eventually(_ condition: @escaping () async -> Bool) async -> Bool {
    for _ in 0..<100 {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return false
}
