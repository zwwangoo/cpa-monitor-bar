import Combine
import Foundation
import CPAClient
import CPAModels
enum ConfigurationState: Equatable, Sendable {
    case unconfigured
    case configured
}
@MainActor
final class MonitorViewModel: ObservableObject {
    static let eventsPageSize = 20

    @Published var baseURL: String
    @Published var configurationState: ConfigurationState
    @Published var isAuthenticated = false
    @Published private(set) var isRefreshing = false
    @Published var loginError: String?
    @Published private(set) var usageRange: UsageTimeRange
    @Published private(set) var refreshFrequency: RefreshFrequency
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var health = SectionState<HealthResponse>()
    @Published private(set) var keeperStatus = SectionState<KeeperStatusResponse>()
    @Published private(set) var keeperVersion = SectionState<KeeperVersionResponse>()
    @Published private(set) var overview = SectionState<UsageOverviewResponse>()
    @Published private(set) var analysis = SectionState<UsageAnalysisResponse>()
    @Published var events = SectionState<UsageEventsResponse>()
    @Published var isLoadingMoreEvents = false
    @Published var eventsLoadMoreError: String?
    @Published private(set) var authFiles = SectionState<UsageIdentitiesPageResponse>()
    @Published private(set) var providers = SectionState<UsageIdentitiesPageResponse>()
    @Published var quotaCache = SectionState<UsageQuotaCacheResponse>()
    @Published var isRefreshingQuota = false
    @Published var quotaRefreshError: String?

    var client: (any CPAServiceClient)?
    var credentialStore: (any CredentialStore)?
    let baseURLStore: any BaseURLStoring
    private let preferencesStore: any MonitorPreferencesStoring
    let insecureHTTPConsentStore: any InsecureHTTPConsentStoring
    private let launchAtLoginController: any LaunchAtLoginControlling
    let credentialStoreFactory: CredentialStoreFactory
    let clientFactory: CPAServiceClientFactory
    let pollingIntervalOverride: Duration?
    let quotaRefreshPollingInterval: Duration
    var pollingTask: Task<Void, Never>?
    var quotaRefreshTask: Task<Void, Never>?
    var connectionGeneration = 0
    var started = false
    var eventsPageGeneration = 0
    init(
        baseURLStore: any BaseURLStoring = UserDefaultsBaseURLStore(),
        preferencesStore: any MonitorPreferencesStoring = UserDefaultsMonitorPreferencesStore(),
        insecureHTTPConsentStore: any InsecureHTTPConsentStoring =
            UserDefaultsInsecureHTTPConsentStore(),
        launchAtLoginController: (any LaunchAtLoginControlling)? = nil,
        credentialStoreFactory: @escaping CredentialStoreFactory = { root in
            KeychainCredentialStore(account: credentialAccount(for: root))
        },
        clientFactory: @escaping CPAServiceClientFactory = { root in
            try! CPAClient(baseURL: root.url.absoluteString)
        },
        pollingInterval: Duration? = nil,
        quotaRefreshPollingInterval: Duration = .seconds(5)
    ) {
        let preferences = preferencesStore.load()
        let launchController = launchAtLoginController ?? LaunchAtLoginController()
        self.baseURLStore = baseURLStore
        self.preferencesStore = preferencesStore
        self.insecureHTTPConsentStore = insecureHTTPConsentStore
        self.launchAtLoginController = launchController
        self.credentialStoreFactory = credentialStoreFactory
        self.clientFactory = clientFactory
        pollingIntervalOverride = pollingInterval
        self.quotaRefreshPollingInterval = quotaRefreshPollingInterval
        usageRange = preferences.usageRange
        refreshFrequency = preferences.refreshFrequency
        launchAtLoginEnabled = launchController.isEnabled
        if let saved = baseURLStore.loadBaseURL(), let root = try? CPAServiceRoot(saved) {
            baseURL = root.url.absoluteString
            if root.requiresInsecureHTTPConsent
                && !insecureHTTPConsentStore.contains(root.url.absoluteString) {
                configurationState = .unconfigured
            } else {
                configurationState = .configured
                client = clientFactory(root)
                credentialStore = credentialStoreFactory(root)
            }
        } else {
            baseURL = ""
            configurationState = .unconfigured
        }
    }

    deinit {
        pollingTask?.cancel()
        quotaRefreshTask?.cancel()
    }
    func start() async {
        guard !started, client != nil else { return }
        started = true
        startPolling()
        await refresh()
        guard health.value != nil, health.errorMessage == nil, !isAuthenticated else { return }
        await loginWithSavedPassword()
    }

    func refresh() async {
        guard let activeClient = client, !isRefreshing else { return }
        let generation = connectionGeneration
        isRefreshing = true
        health.isLoading = true
        let healthResult = await capture { try await activeClient.health() }
        guard isCurrent(generation) else { return }
        guard applyHealth(healthResult) else {
            isAuthenticated = false
            isRefreshing = false
            return
        }

        let sessionResult = await capture { try await activeClient.session() }
        guard isCurrent(generation) else { return }
        switch sessionResult {
        case let .success(session):
            isAuthenticated = session.authenticated
            loginError = nil
        case let .failure(error):
            isAuthenticated = false
            loginError = error.localizedDescription
        }
        guard isAuthenticated else {
            isRefreshing = false
            return
        }
        await refreshDashboard(using: activeClient, generation: generation)
    }

    private func refreshDashboard(
        using activeClient: any CPAServiceClient,
        generation: Int
    ) async {
        keeperStatus.isLoading = true
        keeperVersion.isLoading = true
        overview.isLoading = true
        analysis.isLoading = true
        events.isLoading = true
        authFiles.isLoading = true
        providers.isLoading = true
        quotaCache.isLoading = true
        eventsPageGeneration += 1
        isLoadingMoreEvents = false
        eventsLoadMoreError = nil
        async let status = capture { try await activeClient.status() }
        async let version = capture { try await activeClient.version() }
        let range = usageRange
        async let overview = capture { try await activeClient.overview(range: range) }
        async let analysis = capture { try await activeClient.analysis(range: range) }
        async let events = capture {
            try await activeClient.events(
                range: range,
                page: 1,
                pageSize: Self.eventsPageSize
            )
        }
        async let authFiles = capture { try await activeClient.authFiles() }
        async let providers = capture { try await activeClient.providers() }
        let results = await (status, version, overview, analysis, events, authFiles, providers)
        guard isCurrent(generation) else { return }
        apply(results.0, to: &keeperStatus)
        apply(results.1, to: &keeperVersion)
        apply(results.2, to: &self.overview)
        apply(results.3, to: &self.analysis)
        apply(results.4, to: &self.events)
        apply(results.5, to: &self.authFiles)
        apply(results.6, to: &self.providers)
        await refreshQuotaCache(using: activeClient, authFiles: results.5, generation: generation)
        isRefreshing = false
    }

    private func refreshQuotaCache(
        using activeClient: any CPAServiceClient,
        authFiles result: SectionResult<UsageIdentitiesPageResponse>,
        generation: Int
    ) async {
        guard case let .success(response) = result else {
            quotaCache.isLoading = false
            quotaCache.errorMessage = "认证文件不可用，无法读取限额缓存"
            return
        }
        let indexes = response.identities.compactMap(\.identity)
        let result = await capture { try await activeClient.quotaCache(authIndexes: indexes) }
        guard isCurrent(generation) else { return }
        apply(result, to: &quotaCache)
    }

    func updateMonitoringPreferences(
        usageRange: UsageTimeRange,
        refreshFrequency: RefreshFrequency,
        launchAtLogin: Bool
    ) throws {
        try launchAtLoginController.setEnabled(launchAtLogin)
        let preferences = MonitorPreferences(
            usageRange: usageRange,
            refreshFrequency: refreshFrequency
        )
        preferencesStore.save(preferences)
        let frequencyChanged = self.refreshFrequency != refreshFrequency
        self.usageRange = usageRange
        self.refreshFrequency = refreshFrequency
        launchAtLoginEnabled = launchAtLoginController.isEnabled
        if frequencyChanged { startPolling() }
    }

    private func applyHealth(_ result: SectionResult<HealthResponse>) -> Bool {
        apply(result, to: &health)
        guard case let .success(response) = result else { return false }
        guard response.status?.lowercased() == "ok" else {
            health.value = nil
            health.errorMessage = "健康检查状态异常：\(response.status ?? "未知")"
            return false
        }
        return true
    }

    private func apply<Value>(
        _ result: SectionResult<Value>,
        to state: inout SectionState<Value>
    ) {
        state.isLoading = false
        switch result {
        case let .success(value):
            state.value = value
            state.errorMessage = nil
            state.updatedAt = .now
        case let .failure(error):
            state.errorMessage = error.localizedDescription
            if error == .authenticationRequired {
                isAuthenticated = false
                loginError = error.localizedDescription
            }
        }
    }

    func resetConnectionState() {
        quotaRefreshTask?.cancel()
        quotaRefreshTask = nil
        isAuthenticated = false
        isRefreshing = false
        isRefreshingQuota = false
        quotaRefreshError = nil
        loginError = nil
        health = SectionState()
        keeperStatus = SectionState()
        keeperVersion = SectionState()
        overview = SectionState()
        analysis = SectionState()
        events = SectionState()
        authFiles = SectionState()
        providers = SectionState()
        quotaCache = SectionState()
        eventsPageGeneration += 1
        isLoadingMoreEvents = false
        eventsLoadMoreError = nil
    }

    func beginConnectionStateChange() -> Int {
        connectionGeneration += 1
        quotaRefreshTask?.cancel()
        quotaRefreshTask = nil
        isRefreshing = false
        isRefreshingQuota = false
        quotaRefreshError = nil
        health.isLoading = false
        keeperStatus.isLoading = false
        keeperVersion.isLoading = false
        overview.isLoading = false
        analysis.isLoading = false
        events.isLoading = false
        authFiles.isLoading = false
        providers.isLoading = false
        quotaCache.isLoading = false
        eventsPageGeneration += 1
        isLoadingMoreEvents = false
        return connectionGeneration
    }
    func isCurrent(_ generation: Int) -> Bool {
        generation == connectionGeneration
    }
}
