import Foundation
import CPAClient
import CPAModels
@testable import CPAMonitorBar

@MainActor
final class Dependencies {
    let baseURLStore: MemoryBaseURLStore
    let preferencesStore: MemoryMonitorPreferencesStore
    let insecureHTTPConsentStore: MemoryInsecureHTTPConsentStore
    let launchAtLoginController: RecordingLaunchAtLoginController
    let credentialFactory: CredentialFactoryRecorder
    let clientFactory: ClientFactoryRecorder
    let providerUsageConfigurationStore: RecordingProviderUsageConfigurationStore
    let providerUsageCredentialStore: MemoryProviderUsageCredentialStore
    let providerUsageMonitor: any ProviderUsageMonitoring

    init(
        savedURL: String?,
        clients: [CountingClient] = [],
        preferences: MonitorPreferences = MonitorPreferences(),
        launchAtLogin: Bool = false,
        savedPassword: String? = nil,
        providerUsageConfigurations: [ProviderUsageConfiguration] = [],
        providerUsageConfigurationFails: Bool = false,
        providerUsageKeys: [String: String] = [:],
        providerUsageCredentialUpdateFails: Bool = false,
        providerUsageMonitor: (any ProviderUsageMonitoring)? = nil
    ) {
        baseURLStore = MemoryBaseURLStore(baseURL: savedURL)
        preferencesStore = MemoryMonitorPreferencesStore(preferences: preferences)
        insecureHTTPConsentStore = MemoryInsecureHTTPConsentStore()
        launchAtLoginController = RecordingLaunchAtLoginController(isEnabled: launchAtLogin)
        credentialFactory = CredentialFactoryRecorder(savedPassword: savedPassword)
        clientFactory = ClientFactoryRecorder(clients: clients)
        providerUsageConfigurationStore = RecordingProviderUsageConfigurationStore(
            values: providerUsageConfigurations,
            shouldFail: providerUsageConfigurationFails
        )
        providerUsageCredentialStore = MemoryProviderUsageCredentialStore(
            keys: providerUsageKeys,
            shouldFailUpdate: providerUsageCredentialUpdateFails
        )
        self.providerUsageMonitor = providerUsageMonitor ?? RecordingProviderUsageMonitor()
    }

    func makeModel(
        pollingInterval: Duration = .seconds(60),
        quotaRefreshPollingInterval: Duration = .milliseconds(1)
    ) -> MonitorViewModel {
        MonitorViewModel(
            baseURLStore: baseURLStore,
            preferencesStore: preferencesStore,
            insecureHTTPConsentStore: insecureHTTPConsentStore,
            launchAtLoginController: launchAtLoginController,
            credentialStoreFactory: credentialFactory.makeStore,
            clientFactory: clientFactory.makeClient,
            providerUsageConfigurationStore: providerUsageConfigurationStore,
            providerUsageCredentialStore: providerUsageCredentialStore,
            providerUsageMonitor: providerUsageMonitor,
            pollingInterval: pollingInterval,
            quotaRefreshPollingInterval: quotaRefreshPollingInterval
        )
    }
}

final class RecordingProviderUsageConfigurationStore:
    ProviderUsageConfigurationStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var storedValues: [ProviderUsageConfiguration]
    private let shouldFail: Bool

    init(values: [ProviderUsageConfiguration], shouldFail: Bool = false) {
        storedValues = values
        self.shouldFail = shouldFail
    }

    func load(keeperRoot: String) throws -> [ProviderUsageConfiguration] {
        _ = keeperRoot
        if shouldFail {
            throw ProviderUsageConfigurationStorageError.corruptedData
        }
        return lock.withLock { storedValues }
    }

    func save(
        _ values: [ProviderUsageConfiguration],
        keeperRoot: String
    ) throws {
        _ = keeperRoot
        if shouldFail {
            throw ProviderUsageConfigurationStorageError.corruptedData
        }
        lock.withLock { storedValues = values }
    }
}

actor RecordingProviderUsageMonitor: ProviderUsageMonitoring {
    struct Request: Equatable {
        let keeperRoot: String
        let providerIDs: [String]
    }

    private(set) var requests: [Request] = []
    private(set) var validationKeys: [String] = []
    var responses: [[String: ProviderUsageRefreshResult]]
    private let validationResult: Result<
        ProviderUsageSnapshot,
        ProviderUsageError
    >

    init(
        responses: [[String: ProviderUsageRefreshResult]] = [],
        validationResult: Result<ProviderUsageSnapshot, ProviderUsageError> =
            .failure(.serviceUnavailable)
    ) {
        self.responses = responses
        self.validationResult = validationResult
    }

    func refresh(
        keeperRoot: String,
        providerIDs: [String]
    ) -> [String: ProviderUsageRefreshResult] {
        requests.append(Request(keeperRoot: keeperRoot, providerIDs: providerIDs))
        return responses.isEmpty ? [:] : responses.removeFirst()
    }

    func validate(
        configuration: ProviderUsageConfiguration,
        key: String
    ) async throws -> ProviderUsageSnapshot {
        _ = configuration
        validationKeys.append(key)
        return try validationResult.get()
    }
}

actor SuspendingProviderUsageMonitor: ProviderUsageMonitoring {
    private var continuation: CheckedContinuation<
        [String: ProviderUsageRefreshResult], Never
    >?
    private let response: [String: ProviderUsageRefreshResult]
    private(set) var requestCount = 0
    private(set) var cancellationCount = 0

    init(response: [String: ProviderUsageRefreshResult]) {
        self.response = response
    }

    func refresh(
        keeperRoot: String,
        providerIDs: [String]
    ) async -> [String: ProviderUsageRefreshResult] {
        _ = keeperRoot
        _ = providerIDs
        requestCount += 1
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation = $0 }
        } onCancel: {
            Task { await self.cancelPendingRequest() }
        }
    }

    func validate(
        configuration: ProviderUsageConfiguration,
        key: String
    ) async throws -> ProviderUsageSnapshot {
        _ = configuration
        _ = key
        throw ProviderUsageError.serviceUnavailable
    }

    private func cancelPendingRequest() {
        cancellationCount += 1
        continuation?.resume(returning: response)
        continuation = nil
    }
}

final class MemoryInsecureHTTPConsentStore: InsecureHTTPConsentStoring {
    private var values = Set<String>()

    func contains(_ normalizedURL: String) -> Bool { values.contains(normalizedURL) }
    func record(_ normalizedURL: String) { values.insert(normalizedURL) }
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
    private(set) var stores: [RecordingCredentialStore]
    private(set) var callCount = 0

    var latestStore: RecordingCredentialStore { stores[stores.count - 1] }

    init(savedPassword: String?) {
        store = RecordingCredentialStore(savedPassword: savedPassword)
        stores = [store]
    }

    func makeStore(_ root: CPAServiceRoot) -> any CredentialStore {
        _ = root
        callCount += 1
        if callCount == 1 { return store }
        let next = RecordingCredentialStore(savedPassword: nil)
        stores.append(next)
        return next
    }
}

final class RecordingCredentialStore: CredentialStore, @unchecked Sendable {
    private(set) var loadCount = 0
    private(set) var deleteCount = 0
    private(set) var savedPassword: String?

    init(savedPassword: String?) {
        self.savedPassword = savedPassword
    }

    func savePassword(_ password: String) async throws { savedPassword = password }
    func loadPassword() async throws -> String? {
        loadCount += 1
        return savedPassword
    }
    func deletePassword() async throws {
        deleteCount += 1
        savedPassword = nil
    }
}

actor CountingClient: CPAServiceClient {
    enum Call: Equatable {
        case health, session, status, version, overview, analysis, activity
        case events, authFiles, providers, quotaCache([String])
        case refreshQuota([String]), quotaRefreshStatus(String)
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
    private let quotaRefreshBatchBody: String
    private let quotaRefreshError: CPAClientError?
    private var quotaRefreshTaskBodies: [String: [String]]
    private var quotaCacheResponseBodies: [String]
    private let providerResponseBody: String

    init(
        authenticated: Bool = false,
        healthError: CPAClientError? = nil,
        healthStatus: String = "ok",
        keeperRunning: Bool = true,
        loginError: CPAClientError? = nil,
        eventResponseBodies: [Int: String] = [:],
        quotaRefreshBatchBody: String = #"{"tasks":[],"rejected":[]}"#,
        quotaRefreshError: CPAClientError? = nil,
        quotaRefreshTaskBodies: [String: [String]] = [:],
        quotaCacheResponseBodies: [String] = [],
        providerResponseBody: String = #"{"identities":[]}"#
    ) {
        self.authenticated = authenticated
        remainingHealthErrors = healthError.map { [$0] } ?? []
        self.healthStatus = healthStatus
        self.keeperRunning = keeperRunning
        self.loginError = loginError
        self.eventResponseBodies = eventResponseBodies
        self.quotaRefreshBatchBody = quotaRefreshBatchBody
        self.quotaRefreshError = quotaRefreshError
        self.quotaRefreshTaskBodies = quotaRefreshTaskBodies
        self.quotaCacheResponseBodies = quotaCacheResponseBodies
        self.providerResponseBody = providerResponseBody
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

    func analysis(range: UsageTimeRange) async throws -> UsageAnalysisResponse {
        calls.append(.analysis)
        analysisRanges.append(range)
        return try decode("{}")
    }
    func activity() async throws -> UsageActivityResponse {
        calls.append(.activity)
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
        return try decode(providerResponseBody)
    }

    func quotaCache(authIndexes: [String]) async throws -> UsageQuotaCacheResponse {
        calls.append(.quotaCache(authIndexes))
        let body = quotaCacheResponseBodies.isEmpty
            ? #"{"items":[]}"#
            : quotaCacheResponseBodies.removeFirst()
        return try decode(body)
    }

    func refreshQuota(authIndexes: [String]) async throws -> UsageQuotaRefreshBatchResponse {
        calls.append(.refreshQuota(authIndexes))
        if let quotaRefreshError { throw quotaRefreshError }
        return try decode(quotaRefreshBatchBody)
    }

    func quotaRefreshStatus(authIndex: String) async throws -> UsageQuotaRefreshTaskResponse {
        calls.append(.quotaRefreshStatus(authIndex))
        var bodies = quotaRefreshTaskBodies[authIndex] ?? []
        let body = bodies.isEmpty ? #"{"status":"completed"}"# : bodies.removeFirst()
        quotaRefreshTaskBodies[authIndex] = bodies
        return try decode(body)
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
