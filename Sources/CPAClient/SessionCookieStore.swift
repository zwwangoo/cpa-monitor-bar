import Foundation

public final class SessionCookieStore: @unchecked Sendable {
    private let storage: HTTPCookieStorage

    public init(
        storage: HTTPCookieStorage = URLSessionConfiguration.ephemeral.httpCookieStorage!
    ) {
        self.storage = storage
        clear()
    }

    public var cookies: [HTTPCookie] {
        storage.cookies ?? []
    }

    public func makeSession(protocolClasses: [AnyClass]? = nil) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = storage
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        if let protocolClasses {
            configuration.protocolClasses = protocolClasses
        }
        return URLSession(configuration: configuration)
    }

    public func clear() {
        for cookie in storage.cookies ?? [] {
            storage.deleteCookie(cookie)
        }
    }

    func addCookies(to request: inout URLRequest) {
        guard request.value(forHTTPHeaderField: "Cookie") == nil,
              let url = request.url else { return }
        let matchingCookies = storage.cookies(for: url) ?? []
        guard !matchingCookies.isEmpty else { return }

        for (name, value) in HTTPCookie.requestHeaderFields(with: matchingCookies) {
            request.setValue(value, forHTTPHeaderField: name)
        }
    }

    func storeCookies(from response: HTTPURLResponse) {
        guard let url = response.url else { return }
        let headerFields = response.allHeaderFields.reduce(into: [String: String]()) {
            fields, header in
            guard let name = header.key as? String else { return }
            fields[name] = String(describing: header.value)
        }

        for cookie in HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url) {
            storage.setCookie(cookie)
        }
    }
}
