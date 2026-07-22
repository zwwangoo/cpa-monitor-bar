import Foundation
import CPAModels

public final class CPAClient: @unchecked Sendable {
    private let root: CPAServiceRoot
    private let session: URLSession
    private let cookieStore: SessionCookieStore
    private let policy: CPARequestPolicy

    public convenience init(baseURL: String) throws {
        let cookieStore = SessionCookieStore()
        self.init(
            root: try CPAServiceRoot(baseURL),
            session: cookieStore.makeSession(),
            cookieStore: cookieStore
        )
    }

    public init(
        root: CPAServiceRoot,
        session: URLSession,
        cookieStore: SessionCookieStore,
        policy: CPARequestPolicy = CPARequestPolicy()
    ) {
        self.root = root
        self.session = session
        self.cookieStore = cookieStore
        self.policy = policy
    }

    public func health() async throws -> HealthResponse {
        try await fetch(.health)
    }

    public func session() async throws -> AuthSessionResponse {
        try await fetch(.session)
    }

    public func status() async throws -> KeeperStatusResponse {
        try await fetch(.status)
    }

    public func version() async throws -> KeeperVersionResponse {
        try await fetch(.version)
    }

    public func overview(range: UsageTimeRange = .today) async throws -> UsageOverviewResponse {
        try await fetch(.overview, usageRange: range)
    }

    public func realtime() async throws -> RealtimeOverviewResponse {
        try await fetch(.realtime)
    }

    public func analysis(range: UsageTimeRange = .today) async throws -> UsageAnalysisResponse {
        try await fetch(.analysis, usageRange: range)
    }

    public func events(
        range: UsageTimeRange = .today,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> UsageEventsResponse {
        try await fetch(
            .usageEvents,
            usageRange: range,
            page: page,
            pageSize: pageSize
        )
    }

    public func authFiles() async throws -> UsageIdentitiesPageResponse {
        try await fetch(.authFiles)
    }

    public func providers() async throws -> UsageIdentitiesPageResponse {
        try await fetch(.providers)
    }

    public func quotaCache(authIndexes: [String]) async throws -> UsageQuotaCacheResponse {
        struct QuotaCacheBody: Encodable {
            let authIndexes: [String]
            enum CodingKeys: String, CodingKey { case authIndexes = "auth_indexes" }
        }
        var request = try makeRequest(.quotaCache)
        request.httpBody = try JSONEncoder().encode(QuotaCacheBody(authIndexes: authIndexes))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("fetch", forHTTPHeaderField: "X-CPA-Usage-Keeper-Request")
        let data = try await perform(request)
        do {
            return try JSONDecoder().decode(UsageQuotaCacheResponse.self, from: data)
        } catch {
            throw CPAClientError.decoding(Self.decodingMessage(error))
        }
    }

    public func refreshQuota(authIndexes: [String]) async throws -> UsageQuotaRefreshBatchResponse {
        struct QuotaRefreshBody: Encodable {
            let authIndexes: [String]
            enum CodingKeys: String, CodingKey { case authIndexes = "auth_indexes" }
        }
        var request = try makeRequest(.quotaRefresh)
        request.httpBody = try JSONEncoder().encode(QuotaRefreshBody(authIndexes: authIndexes))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("fetch", forHTTPHeaderField: "X-CPA-Usage-Keeper-Request")
        return try decode(UsageQuotaRefreshBatchResponse.self, from: await perform(request))
    }

    public func quotaRefreshStatus(authIndex: String) async throws -> UsageQuotaRefreshTaskResponse {
        let url = try root.quotaRefreshStatusURL(authIndex: authIndex)
        let request = try makeRequest(method: .get, url: url)
        return try decode(UsageQuotaRefreshTaskResponse.self, from: await perform(request))
    }

    public func login(password: String) async throws {
        struct LoginBody: Encodable { let password: String }
        var request = try makeRequest(.login)
        request.httpBody = try JSONEncoder().encode(LoginBody(password: password))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("fetch", forHTTPHeaderField: "X-CPA-Usage-Keeper-Request")
        _ = try await perform(request, captureResponseCookies: true)
    }

    public func logout() async throws {
        defer { cookieStore.clear() }
        var request = try makeRequest(.logout)
        request.setValue("fetch", forHTTPHeaderField: "X-CPA-Usage-Keeper-Request")
        _ = try await perform(request)
    }

    private func fetch<T: Decodable>(
        _ endpoint: CPAEndpoint,
        usageRange: UsageTimeRange = .today,
        page: Int = 1,
        pageSize: Int = 20
    ) async throws -> T {
        let data = try await perform(makeRequest(
            endpoint,
            usageRange: usageRange,
            page: page,
            pageSize: pageSize
        ))
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CPAClientError.decoding(Self.decodingMessage(error))
        }
    }

    private static func decodingMessage(_ error: Error) -> String {
        switch error {
        case let DecodingError.typeMismatch(type, context):
            return "字段 \(fieldPath(context.codingPath)) 应为 \(type)：\(context.debugDescription)"
        case let DecodingError.valueNotFound(type, context):
            return "字段 \(fieldPath(context.codingPath)) 缺少 \(type)：\(context.debugDescription)"
        case let DecodingError.keyNotFound(key, context):
            return "缺少字段 \(fieldPath(context.codingPath + [key]))：\(context.debugDescription)"
        case let DecodingError.dataCorrupted(context):
            return "字段 \(fieldPath(context.codingPath)) 数据损坏：\(context.debugDescription)"
        default:
            return error.localizedDescription
        }
    }

    private static func fieldPath(_ codingPath: [any CodingKey]) -> String {
        guard !codingPath.isEmpty else { return "<root>" }
        return codingPath.reduce(into: "") { result, key in
            if let index = key.intValue {
                result += "[\(index)]"
            } else {
                if !result.isEmpty { result += "." }
                result += key.stringValue
            }
        }
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw CPAClientError.decoding(Self.decodingMessage(error)) }
    }

    private func makeRequest(
        _ endpoint: CPAEndpoint,
        usageRange: UsageTimeRange = .today,
        page: Int = 1,
        pageSize: Int = 20
    ) throws -> URLRequest {
        try policy.validate(method: endpoint.method, path: endpoint.path)
        var request = URLRequest(url: try root.url(
            for: endpoint,
            usageRange: usageRange,
            page: page,
            pageSize: pageSize
        ))
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        cookieStore.addCookies(to: &request)
        return request
    }

    private func makeRequest(method: HTTPMethod, url: URL) throws -> URLRequest {
        guard let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedPath else {
            throw CPAClientError.invalidBaseURL
        }
        try policy.validate(method: method, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        cookieStore.addCookies(to: &request)
        return request
    }

    private func perform(
        _ request: URLRequest,
        captureResponseCookies: Bool = false
    ) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as CPAClientError {
            throw error
        } catch {
            throw CPAClientError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw CPAClientError.invalidResponse
        }
        switch http.statusCode {
        case 200..<300:
            if captureResponseCookies {
                cookieStore.storeCookies(from: http)
            }
            return data
        case 401, 403: throw CPAClientError.authenticationRequired
        case 429: throw CPAClientError.rateLimited
        case 500...599: throw CPAClientError.serverUnavailable(statusCode: http.statusCode)
        default: throw CPAClientError.invalidResponse
        }
    }
}
