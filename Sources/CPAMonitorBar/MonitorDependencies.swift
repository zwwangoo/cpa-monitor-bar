import Foundation
import CPAClient
import CPAModels

protocol BaseURLStoring: AnyObject {
    func loadBaseURL() -> String?
    func saveBaseURL(_ value: String)
}

final class UserDefaultsBaseURLStore: BaseURLStoring {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "cpaBaseURL") {
        self.defaults = defaults
        self.key = key
    }

    func loadBaseURL() -> String? {
        defaults.string(forKey: key)
    }

    func saveBaseURL(_ value: String) {
        defaults.set(value, forKey: key)
    }
}

protocol InsecureHTTPConsentStoring: AnyObject {
    func contains(_ normalizedURL: String) -> Bool
    func record(_ normalizedURL: String)
}

final class UserDefaultsInsecureHTTPConsentStore: InsecureHTTPConsentStoring {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "approvedInsecureHTTPKeeperURLs"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func contains(_ normalizedURL: String) -> Bool {
        Set(defaults.stringArray(forKey: key) ?? []).contains(normalizedURL)
    }

    func record(_ normalizedURL: String) {
        var values = Set(defaults.stringArray(forKey: key) ?? [])
        values.insert(normalizedURL)
        defaults.set(values.sorted(), forKey: key)
    }
}

protocol CPAServiceClient: Sendable {
    func health() async throws -> HealthResponse
    func session() async throws -> AuthSessionResponse
    func status() async throws -> KeeperStatusResponse
    func version() async throws -> KeeperVersionResponse
    func overview(range: UsageTimeRange) async throws -> UsageOverviewResponse
    func analysis(range: UsageTimeRange) async throws -> UsageAnalysisResponse
    func events(
        range: UsageTimeRange,
        page: Int,
        pageSize: Int
    ) async throws -> UsageEventsResponse
    func authFiles() async throws -> UsageIdentitiesPageResponse
    func providers() async throws -> UsageIdentitiesPageResponse
    func quotaCache(authIndexes: [String]) async throws -> UsageQuotaCacheResponse
    func refreshQuota(authIndexes: [String]) async throws -> UsageQuotaRefreshBatchResponse
    func quotaRefreshStatus(authIndex: String) async throws -> UsageQuotaRefreshTaskResponse
    func login(password: String) async throws
    func logout() async throws
}

extension CPAClient: CPAServiceClient {}

typealias CPAServiceClientFactory = @MainActor (CPAServiceRoot) -> any CPAServiceClient
typealias CredentialStoreFactory = @MainActor (CPAServiceRoot) -> any CredentialStore

struct SectionState<Value: Sendable>: Sendable {
    var value: Value?
    var isLoading = false
    var errorMessage: String?
    var updatedAt: Date?

    var isStale: Bool { value != nil && errorMessage != nil }
}

enum SectionResult<Value: Sendable>: Sendable {
    case success(Value)
    case failure(CPAClientError)
}

enum CredentialInputError: LocalizedError {
    case missingPassword

    var errorDescription: String? { "请输入管理员密码" }
}

func capture<Value: Sendable>(
    _ operation: @escaping @Sendable () async throws -> Value
) async -> SectionResult<Value> {
    do { return .success(try await operation()) }
    catch let error as CPAClientError { return .failure(error) }
    catch { return .failure(.network(error.localizedDescription)) }
}

func displayMessage(_ error: Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
}

func resolvePassword(
    _ provided: String,
    from store: any CredentialStore
) async throws -> String {
    if !provided.isEmpty { return provided }
    guard let stored = try await store.loadPassword(), !stored.isEmpty else {
        throw CredentialInputError.missingPassword
    }
    return stored
}

func credentialAccount(for root: CPAServiceRoot) -> String {
    "administrator-password:\(root.url.absoluteString)"
}
