import Foundation

struct ProviderUsageScope: Hashable, Codable, Sendable {
    let keeperRoot: String
    let providerID: String
}

struct ProviderUsageConfiguration: Codable, Equatable, Sendable {
    let providerID: String
    var baseURL: String
    var isEnabled: Bool
}

struct ProviderUsageWindow: Equatable, Sendable, Identifiable {
    let id: String
    let used: Double
    let limit: Double
    let resetsAt: Date?
}

enum ProviderUsageMode: Equatable, Sendable {
    case wallet(balance: Double)
    case subscription(
        plan: String,
        remaining: Double?,
        windows: [ProviderUsageWindow]
    )
    case keyQuota(
        status: String?,
        used: Double?,
        limit: Double?,
        remaining: Double?,
        windows: [ProviderUsageWindow]
    )
}

struct ProviderUsageSnapshot: Equatable, Sendable {
    let mode: ProviderUsageMode
    let currency: String
    let expiresAt: Date?
    let fetchedAt: Date
}

struct ProviderUsageState: Equatable, Sendable {
    var snapshot: ProviderUsageSnapshot?
    var isLoading = false
    var errorMessage: String?
}

enum ProviderUsageError: Error, Equatable, LocalizedError, Sendable {
    case invalidBaseURL
    case providerListUnavailable
    case providerListChanged
    case keeperChanged
    case missingKey
    case authenticationRequired
    case unsupportedEndpoint
    case rateLimited
    case serviceUnavailable
    case responseTooLarge(limitBytes: Int)
    case unsupportedResponse
    case network(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            "供应商 API 地址无效"
        case .providerListUnavailable:
            "供应商列表尚未加载，未更改本地用量配置"
        case .providerListChanged:
            "供应商列表已变化，请重新打开设置后再应用"
        case .keeperChanged:
            "Keeper 连接已变化，请重新打开设置后再应用"
        case .missingKey:
            "尚未配置供应商监控 Key"
        case .authenticationRequired:
            "监控 Key 无效或无权查询用量"
        case .unsupportedEndpoint:
            "该地址未提供受支持的 Sub2API 用量接口"
        case .rateLimited:
            "供应商用量查询过于频繁"
        case .serviceUnavailable:
            "供应商用量服务暂不可用"
        case let .responseTooLarge(limitBytes):
            "供应商用量响应超过安全限制（\(limitBytes) 字节）"
        case .unsupportedResponse:
            "供应商返回了不受支持的用量数据"
        case let .network(message):
            "供应商连接失败：\(message)"
        }
    }
}

protocol ProviderUsageAdapter: Sendable {
    func fetchUsage(key: String) async throws -> ProviderUsageSnapshot
}
