import Foundation

struct ProviderUsageServiceRoot: Equatable, Sendable {
    let url: URL

    init(_ rawValue: String) throws {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let rawScheme = components.scheme,
              let rawHost = components.host,
              !rawHost.isEmpty,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            throw ProviderUsageError.invalidBaseURL
        }

        let scheme = rawScheme.lowercased()
        guard scheme == "https" || scheme == "http" else {
            throw ProviderUsageError.invalidBaseURL
        }
        guard !Self.containsTraversal(components.percentEncodedPath) else {
            throw ProviderUsageError.invalidBaseURL
        }

        components.scheme = scheme
        components.host = rawHost.lowercased()
        components.percentEncodedPath = Self.normalizedPath(components.percentEncodedPath)
        components.percentEncodedQuery = nil
        guard let normalized = components.url else {
            throw ProviderUsageError.invalidBaseURL
        }
        url = normalized
    }

    func usageURL(
        date: Date = Date(),
        timeZoneIdentifier: String = TimeZone.current.identifier
    ) throws -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ProviderUsageError.invalidBaseURL
        }
        let basePath = Self.normalizedPath(components.percentEncodedPath)
        components.percentEncodedPath = basePath + "/v1/usage"

        let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .gmt
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let day = formatter.string(from: date)
        components.queryItems = [
            URLQueryItem(name: "start_date", value: day),
            URLQueryItem(name: "end_date", value: day),
            URLQueryItem(name: "days", value: "1"),
            URLQueryItem(name: "timezone", value: timeZoneIdentifier),
        ]
        guard let result = components.url else {
            throw ProviderUsageError.invalidBaseURL
        }
        return result
    }

    private static func normalizedPath(_ path: String) -> String {
        guard path != "/" else { return "" }
        var result = path
        while result.hasSuffix("/") { result.removeLast() }
        return result
    }

    private static func containsTraversal(_ path: String) -> Bool {
        var decoded = path.lowercased()
        for _ in 0..<3 {
            guard let next = decoded.removingPercentEncoding?.lowercased(), next != decoded else {
                break
            }
            decoded = next
        }
        return decoded.split(separator: "/", omittingEmptySubsequences: false)
            .contains { $0 == "." || $0 == ".." }
            || decoded.contains("%2e")
    }
}
