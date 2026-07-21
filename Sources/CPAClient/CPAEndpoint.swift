import Foundation

public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

public enum UsageTimeRange: String, CaseIterable, Identifiable, Sendable {
    case last8Hours = "8h"
    case today
    case yesterday

    public var id: String { rawValue }
}

public enum CPAEndpoint: CaseIterable, Sendable {
    case health
    case session
    case login
    case logout
    case status
    case version
    case overview
    case realtime
    case analysis
    case usageEvents
    case authFiles
    case providers
    case quotaCache

    public var method: HTTPMethod {
        switch self {
        case .login, .logout, .quotaCache: .post
        default: .get
        }
    }

    public var path: String {
        switch self {
        case .health: "/cpa/healthz"
        case .session: "/cpa/api/v1/auth/session"
        case .login: "/cpa/api/v1/auth/login"
        case .logout: "/cpa/api/v1/auth/logout"
        case .status: "/cpa/api/v1/status"
        case .version: "/cpa/api/v1/version"
        case .overview: "/cpa/api/v1/usage/overview"
        case .realtime: "/cpa/api/v1/usage/overview/realtime"
        case .analysis: "/cpa/api/v1/usage/analysis"
        case .usageEvents: "/cpa/api/v1/usage/events"
        case .authFiles, .providers: "/cpa/api/v1/usage/identities/page"
        case .quotaCache: "/cpa/api/v1/quota/cache"
        }
    }

    func queryItems(
        usageRange: UsageTimeRange = .today,
        page: Int = 1,
        pageSize: Int = 20
    ) -> [URLQueryItem] {
        switch self {
        case .overview, .analysis:
            [URLQueryItem(name: "range", value: usageRange.rawValue)]
        case .usageEvents:
            [
                URLQueryItem(name: "range", value: usageRange.rawValue),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "page_size", value: String(pageSize)),
            ]
        case .authFiles, .providers:
            [
                URLQueryItem(name: "auth_type", value: self == .authFiles ? "1" : "2"),
                URLQueryItem(name: "page", value: "1"),
                URLQueryItem(name: "page_size", value: "10"),
            ]
        default:
            []
        }
    }
}
