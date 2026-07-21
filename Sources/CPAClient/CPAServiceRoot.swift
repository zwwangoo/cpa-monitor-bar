import Foundation

public struct CPAServiceRoot: Equatable, Sendable {
    public let url: URL

    public init(_ rawValue: String) throws {
        guard var components = URLComponents(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(),
              !host.isEmpty,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            throw CPAClientError.invalidBaseURL
        }

        guard scheme == "https" || scheme == "http" else {
            throw CPAClientError.invalidBaseURL
        }

        let encodedPath = components.percentEncodedPath.lowercased()
        guard !Self.containsTraversal(encodedPath) else {
            throw CPAClientError.invalidBaseURL
        }

        let path = components.path
        if path.isEmpty || path == "/" {
            components.path = "/cpa"
        } else if path == "/cpa" || path == "/cpa/" {
            components.path = "/cpa"
        } else {
            throw CPAClientError.invalidBaseURL
        }
        components.percentEncodedQuery = nil

        guard let normalized = components.url else {
            throw CPAClientError.invalidBaseURL
        }
        url = normalized
    }

    public func url(
        for endpoint: CPAEndpoint,
        usageRange: UsageTimeRange = .today,
        page: Int = 1,
        pageSize: Int = 20
    ) throws -> URL {
        try CPARequestPolicy().validate(method: endpoint.method, path: endpoint.path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw CPAClientError.invalidBaseURL
        }
        components.path = endpoint.path
        let queryItems = endpoint.queryItems(
            usageRange: usageRange,
            page: page,
            pageSize: pageSize
        )
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let result = components.url else {
            throw CPAClientError.invalidBaseURL
        }
        return result
    }

    private static func containsTraversal(_ path: String) -> Bool {
        let repeatedlyDecoded = path.removingPercentEncoding?.lowercased() ?? path
        return repeatedlyDecoded.split(separator: "/", omittingEmptySubsequences: false)
            .contains { $0 == "." || $0 == ".." }
            || repeatedlyDecoded.contains("%2e")
    }
}
