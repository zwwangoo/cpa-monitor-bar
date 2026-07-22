import Foundation

public struct CPARequestPolicy: Sendable {
    private static let quotaRefreshStatusPrefix = "/cpa/api/v1/quota/refresh/"

    public init() {}

    public func validate(method: HTTPMethod, path: String) throws {
        if CPAEndpoint.allCases.contains(where: {
            $0.method == method && $0.path == path
        }) {
            return
        }
        guard method == .get, Self.isSafeQuotaRefreshStatusPath(path) else {
            throw CPAClientError.requestRejected
        }
    }

    private static func isSafeQuotaRefreshStatusPath(_ path: String) -> Bool {
        guard path.hasPrefix(quotaRefreshStatusPrefix) else { return false }
        let encoded = String(path.dropFirst(quotaRefreshStatusPrefix.count))
        guard !encoded.isEmpty, !encoded.contains("/") else { return false }
        guard let decoded = repeatedlyDecode(encoded) else { return false }
        return !decoded.isEmpty
            && decoded != "."
            && decoded != ".."
            && !decoded.contains("/")
            && !decoded.contains("\\")
    }

    private static func repeatedlyDecode(_ value: String) -> String? {
        var decoded = value
        while decoded.contains("%") {
            guard let next = decoded.removingPercentEncoding else { return nil }
            if next == decoded { break }
            decoded = next
        }
        return decoded
    }
}

public enum CPAClientError: Error, Equatable, LocalizedError, Sendable {
    case invalidBaseURL
    case requestRejected
    case authenticationRequired
    case rateLimited
    case serverUnavailable(statusCode: Int)
    case network(String)
    case invalidResponse
    case responseTooLarge(limitBytes: Int)
    case tooManyItems(limit: Int)
    case decoding(String)

    public var errorDescription: String? {
        switch self {
        case .invalidBaseURL: "Base URL 无效或不安全"
        case .requestRejected: "请求不在 CPA Monitor Bar 白名单中"
        case .authenticationRequired: "需要重新登录"
        case .rateLimited: "请求过于频繁，请稍后重试"
        case let .serverUnavailable(code): "服务暂不可用（HTTP \(code)）"
        case let .network(message): "网络错误：\(message)"
        case .invalidResponse: "服务返回了无效响应"
        case let .responseTooLarge(limit): "服务响应超过安全上限（\(limit) 字节）"
        case let .tooManyItems(limit): "服务返回的列表超过安全上限（\(limit) 项）"
        case let .decoding(message): "响应格式无法解析：\(message)"
        }
    }
}
