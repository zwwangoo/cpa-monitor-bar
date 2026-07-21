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
    static let defaultBaseURL = "https://cpa.wangzhiwen.top/cpa"
    static let eventsPageSize = 20

    @Published private(set) var baseURL: String
    @Published private(set) var configurationState: ConfigurationState
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
    @Published private(set) var realtime = SectionState<RealtimeOverviewResponse>()
    @Published private(set) var analysis = SectionState<UsageAnalysisResponse>()
    @Published var events = SectionState<UsageEventsResponse>()
    @Published var isLoadingMoreEvents = false
    @Published var eventsLoadMoreError: String?
    @Published private(set) var authFiles = SectionState<UsageIdentitiesPageResponse>()
    @Published private(set) var providers = SectionState<UsageIdentitiesPageResponse>()
    @Published private(set) var quotaCache = SectionState<UsageQuotaCacheResponse>()

    var client: (any CPAServiceClient)?
    var credentialStore: (any CredentialStore)?
    private let baseURLStore: any BaseURLStoring
    private let preferencesStore: any MonitorPreferencesStoring
    private let launchAtLoginController: any LaunchAtLoginControlling
    private let credentialStoreFactory: CredentialStoreFactory
    private let clientFactory: CPAServiceClientFactory
    let pollingIntervalOverride: Duration?
    var pollingTask: Task<Void, Never>?
    private var connectionGeneration = 0
    private var started = false
    var eventsPageGeneration = 0
    init(
        baseURLStore: any BaseURLStoring = UserDefaultsBaseURLStore(),
        preferencesStore: any MonitorPreferencesStoring = UserDefaultsMonitorPreferencesStore(),
        launchAtLoginController: (any LaunchAtLoginControlling)? = nil,
        credentialStoreFactory: @escaping CredentialStoreFactory = { root in
            KeychainCredentialStore(account: credentialAccount(for: root))
        },
        clientFactory: @escaping CPAServiceClientFactory = { root in
            try! CPAClient(baseURL: root.url.absoluteString)
        },
        pollingInterval: Duration? = nil
    ) {
        let preferences = preferencesStore.load()
        let launchController = launchAtLoginController ?? LaunchAtLoginController()
        self.baseURLStore = baseURLStore
        self.preferencesStore = preferencesStore
        self.launchAtLoginController = launchController
        self.credentialStoreFactory = credentialStoreFactory
        self.clientFactory = clientFactory
        pollingIntervalOverride = pollingInterval
        usageRange = preferences.usageRange
        refreshFrequency = preferences.refreshFrequency
        launchAtLoginEnabled = launchController.isEnabled
        if let saved = baseURLStore.loadBaseURL(), let root = try? CPAServiceRoot(saved) {
            baseURL = root.url.absoluteString
            configurationState = .configured
            client = clientFactory(root)
            credentialStore = credentialStoreFactory(root)
        } else {
            baseURL = ""
            configurationState = .unconfigured
        }
    }

    deinit { pollingTask?.cancel() }
    func start() async {
        guard !started, client != nil else { return }
        started = true
        startPolling()
        await refresh()
        guard health.value != nil, health.errorMessage == nil, !isAuthenticated else { return }
        await loginWithSavedPassword()
    }

    func updateBaseURL(_ value: String) async throws {
        let root = try CPAServiceRoot(value)
        pollingTask?.cancel()
        connectionGeneration += 1
        resetConnectionState()
        client = clientFactory(root)
        credentialStore = credentialStoreFactory(root)
        baseURL = root.url.absoluteString
        configurationState = .configured
        baseURLStore.saveBaseURL(baseURL)
        started = true
        startPolling()
        await refresh()
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
        realtime.isLoading = true
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
        async let realtime = capture { try await activeClient.realtime() }
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
        let results = await (status, version, overview, realtime, analysis, events, authFiles, providers)
        guard isCurrent(generation) else { return }
        apply(results.0, to: &keeperStatus)
        apply(results.1, to: &keeperVersion)
        apply(results.2, to: &self.overview)
        apply(results.3, to: &self.realtime)
        apply(results.4, to: &self.analysis)
        apply(results.5, to: &self.events)
        apply(results.6, to: &self.authFiles)
        apply(results.7, to: &self.providers)
        await refreshQuotaCache(using: activeClient, authFiles: results.6, generation: generation)
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

    private func resetConnectionState() {
        isAuthenticated = false
        isRefreshing = false
        loginError = nil
        health = SectionState()
        keeperStatus = SectionState()
        keeperVersion = SectionState()
        overview = SectionState()
        realtime = SectionState()
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
        isRefreshing = false
        health.isLoading = false
        keeperStatus.isLoading = false
        keeperVersion.isLoading = false
        overview.isLoading = false
        realtime.isLoading = false
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
