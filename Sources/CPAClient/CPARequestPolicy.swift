import Foundation

public struct CPARequestPolicy: Sendable {
    public init() {}

    public func validate(method: HTTPMethod, path: String) throws {
        guard CPAEndpoint.allCases.contains(where: {
            $0.method == method && $0.path == path
        }) else {
            throw CPAClientError.requestRejected
        }
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
        case let .decoding(message): "响应格式无法解析：\(message)"
        }
    }
}
