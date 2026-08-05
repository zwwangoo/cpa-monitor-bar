import Foundation

final class ProviderUsageRedirectDelegate: NSObject, URLSessionTaskDelegate,
    @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        _ = session
        _ = task
        _ = response
        _ = request
        completionHandler(nil)
    }
}

enum ProviderUsageSessionFactory {
    static func makeSession(protocolClasses: [AnyClass]? = nil) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 10
        configuration.timeoutIntervalForResource = 10
        if let protocolClasses { configuration.protocolClasses = protocolClasses }
        return URLSession(configuration: configuration)
    }
}

final class Sub2APIUsageClient: ProviderUsageAdapter, @unchecked Sendable {
    static let maximumResponseBytes = 2 * 1_024 * 1_024

    private let root: ProviderUsageServiceRoot
    private let session: URLSession
    private let now: () -> Date
    private let timeZoneIdentifier: String
    private let redirectDelegate = ProviderUsageRedirectDelegate()

    init(
        root: ProviderUsageServiceRoot,
        session: URLSession = ProviderUsageSessionFactory.makeSession(),
        now: @escaping () -> Date = Date.init,
        timeZoneIdentifier: String = TimeZone.current.identifier
    ) {
        self.root = root
        self.session = session
        self.now = now
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    func fetchUsage(key: String) async throws -> ProviderUsageSnapshot {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw ProviderUsageError.missingKey }

        var request = URLRequest(
            url: try root.usageURL(
                date: now(),
                timeZoneIdentifier: timeZoneIdentifier
            )
        )
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await load(request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderUsageError.unsupportedResponse
        }
        try validateStatus(httpResponse.statusCode)

        do {
            let value = try JSONDecoder().decode(Sub2APIUsageResponse.self, from: data)
            return try makeSnapshot(value)
        } catch let error as ProviderUsageError {
            throw error
        } catch {
            throw ProviderUsageError.unsupportedResponse
        }
    }

    private func load(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            let (bytes, response) = try await session.bytes(
                for: request,
                delegate: redirectDelegate
            )
            if response.expectedContentLength > Self.maximumResponseBytes {
                bytes.task.cancel()
                throw ProviderUsageError.responseTooLarge(
                    limitBytes: Self.maximumResponseBytes
                )
            }
            var data = Data()
            let reserve = max(response.expectedContentLength, 0)
            data.reserveCapacity(min(Int(reserve), Self.maximumResponseBytes))
            for try await byte in bytes {
                guard data.count < Self.maximumResponseBytes else {
                    bytes.task.cancel()
                    throw ProviderUsageError.responseTooLarge(
                        limitBytes: Self.maximumResponseBytes
                    )
                }
                data.append(byte)
            }
            return (data, response)
        } catch let error as ProviderUsageError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            throw ProviderUsageError.network(error.localizedDescription)
        } catch {
            throw ProviderUsageError.network("网络请求失败")
        }
    }

    private func validateStatus(_ statusCode: Int) throws {
        switch statusCode {
        case 200..<300:
            return
        case 401, 403:
            throw ProviderUsageError.authenticationRequired
        case 404:
            throw ProviderUsageError.unsupportedEndpoint
        case 429:
            throw ProviderUsageError.rateLimited
        case 500..<600:
            throw ProviderUsageError.serviceUnavailable
        default:
            throw ProviderUsageError.unsupportedResponse
        }
    }

    private func makeSnapshot(
        _ value: Sub2APIUsageResponse
    ) throws -> ProviderUsageSnapshot {
        let currency = value.unit?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCurrency = currency?.isEmpty == false ? currency!.uppercased() : "USD"
        let fetchedAt = now()

        switch value.mode {
        case "quota_limited":
            let rawWindows = (value.rateLimits ?? []).map {
                Sub2APIUsageWindow(
                    id: $0.window,
                    used: $0.used,
                    limit: $0.limit,
                    resetsAt: $0.resetAt
                )
            }
            let windows = try rawWindows.compactMap(makeWindow)
            let quota = value.quota
            try validateOptionalAmount(quota?.used)
            try validateOptionalAmount(quota?.limit)
            try validateOptionalAmount(quota?.remaining)
            guard quota != nil || !windows.isEmpty else {
                throw ProviderUsageError.unsupportedResponse
            }
            return ProviderUsageSnapshot(
                mode: .keyQuota(
                    status: value.status,
                    used: quota?.used,
                    limit: quota?.limit,
                    remaining: quota?.remaining,
                    windows: windows
                ),
                currency: normalizedCurrency,
                expiresAt: parseDate(value.expiresAt),
                fetchedAt: fetchedAt
            )

        case "unrestricted":
            if let subscription = value.subscription {
                let windows = try subscription.windows.compactMap(makeWindow)
                let remaining: Double?
                if value.remaining == -1 {
                    remaining = nil
                } else {
                    try validateOptionalAmount(value.remaining)
                    remaining = value.remaining
                }
                return ProviderUsageSnapshot(
                    mode: .subscription(
                        plan: nonempty(value.planName) ?? "订阅",
                        remaining: remaining,
                        windows: windows
                    ),
                    currency: normalizedCurrency,
                    expiresAt: parseDate(subscription.expiresAt),
                    fetchedAt: fetchedAt
                )
            }
            guard let balance = value.balance else {
                throw ProviderUsageError.unsupportedResponse
            }
            try validateAmount(balance)
            return ProviderUsageSnapshot(
                mode: .wallet(balance: balance),
                currency: normalizedCurrency,
                expiresAt: nil,
                fetchedAt: fetchedAt
            )

        default:
            throw ProviderUsageError.unsupportedResponse
        }
    }

    private func makeWindow(
        _ value: Sub2APIUsageWindow
    ) throws -> ProviderUsageWindow? {
        try validateAmount(value.used)
        try validateAmount(value.limit)
        guard value.limit > 0 else { return nil }
        return ProviderUsageWindow(
            id: value.id,
            used: value.used,
            limit: value.limit,
            resetsAt: parseDate(value.resetsAt)
        )
    }

    private func validateOptionalAmount(_ value: Double?) throws {
        guard let value else { return }
        try validateAmount(value)
    }

    private func validateAmount(_ value: Double) throws {
        guard value.isFinite, value >= 0 else {
            throw ProviderUsageError.unsupportedResponse
        }
    }

    private func nonempty(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let result = formatter.date(from: value) { return result }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
