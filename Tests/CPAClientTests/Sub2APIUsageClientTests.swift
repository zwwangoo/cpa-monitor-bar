import Foundation
import XCTest
@testable import CPAMonitorBar

final class Sub2APIUsageClientTests: XCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 1_785_920_400)

    override func tearDown() {
        ProviderUsageStubURLProtocol.handler = nil
        super.tearDown()
    }

    func testMapsWalletResponseAndBuildsSafeRequest() async throws {
        ProviderUsageStubURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/sub2api/v1/usage")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-provider-secret")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
            XCTAssertEqual(query?.first(where: { $0.name == "days" })?.value, "1")
            return Self.response(
                for: request,
                body: #"{"mode":"unrestricted","planName":"钱包余额","remaining":28.46,"unit":"USD","balance":28.46}"#
            )
        }

        let snapshot = try await makeClient().fetchUsage(key: "sk-provider-secret")

        XCTAssertEqual(snapshot.mode, .wallet(balance: 28.46))
        XCTAssertEqual(snapshot.currency, "USD")
        XCTAssertEqual(snapshot.fetchedAt, fixedNow)
        XCTAssertNil(snapshot.expiresAt)
    }

    func testMapsSubscriptionWindowsAndExpiry() async throws {
        ProviderUsageStubURLProtocol.handler = { request in
            Self.response(
                for: request,
                body: #"{"mode":"unrestricted","planName":"Pro Plan","remaining":"57.7","unit":"USD","subscription":{"daily_usage_usd":"3.2","daily_limit_usd":10,"weekly_usage_usd":18.4,"weekly_limit_usd":"50","monthly_usage_usd":42.3,"monthly_limit_usd":100,"expires_at":"2026-09-01T00:00:00Z"}}"#
            )
        }

        let snapshot = try await makeClient().fetchUsage(key: "key")

        guard case let .subscription(plan, remaining, windows) = snapshot.mode else {
            return XCTFail("Expected subscription mode")
        }
        XCTAssertEqual(plan, "Pro Plan")
        XCTAssertEqual(remaining, 57.7)
        XCTAssertEqual(windows.map(\.id), ["1d", "7d", "30d"])
        XCTAssertEqual(windows.map(\.used), [3.2, 18.4, 42.3])
        XCTAssertEqual(windows.map(\.limit), [10, 50, 100])
        XCTAssertNotNil(snapshot.expiresAt)
    }

    func testMapsUnlimitedSubscriptionNegativeSentinelAsNoRemainingAmount() async throws {
        ProviderUsageStubURLProtocol.handler = { request in
            Self.response(
                for: request,
                body: #"{"mode":"unrestricted","planName":"Unlimited","remaining":-1,"unit":"USD","subscription":{"daily_usage_usd":0,"daily_limit_usd":0,"weekly_usage_usd":0,"weekly_limit_usd":0,"monthly_usage_usd":0,"monthly_limit_usd":0,"expires_at":"2026-09-01T00:00:00Z"}}"#
            )
        }

        let snapshot = try await makeClient().fetchUsage(key: "key")

        guard case let .subscription(plan, remaining, windows) = snapshot.mode else {
            return XCTFail("Expected subscription mode")
        }
        XCTAssertEqual(plan, "Unlimited")
        XCTAssertNil(remaining)
        XCTAssertTrue(windows.isEmpty)
        XCTAssertNotNil(snapshot.expiresAt)
    }

    func testMapsKeyQuotaAndRateLimitReset() async throws {
        ProviderUsageStubURLProtocol.handler = { request in
            Self.response(
                for: request,
                body: #"{"mode":"quota_limited","status":"active","unit":"USD","quota":{"used":7.4,"limit":20,"remaining":12.6},"rate_limits":[{"window":"5h","used":2.4,"limit":10,"remaining":7.6,"reset_at":"2026-08-05T18:00:00Z"},{"window":"1d","used":8.2,"limit":30,"remaining":21.8},{"window":"7d","used":0,"limit":0}]}"#
            )
        }

        let snapshot = try await makeClient().fetchUsage(key: "key")

        guard case let .keyQuota(status, used, limit, remaining, windows) = snapshot.mode else {
            return XCTFail("Expected key quota mode")
        }
        XCTAssertEqual(status, "active")
        XCTAssertEqual(used, 7.4)
        XCTAssertEqual(limit, 20)
        XCTAssertEqual(remaining, 12.6)
        XCTAssertEqual(windows.map(\.id), ["5h", "1d"])
        XCTAssertNotNil(windows.first?.resetsAt)
    }

    func testMapsExpectedHTTPFailuresWithoutLeakingKey() async throws {
        let expectations: [(Int, ProviderUsageError)] = [
            (401, .authenticationRequired),
            (403, .authenticationRequired),
            (404, .unsupportedEndpoint),
            (429, .rateLimited),
            (503, .serviceUnavailable),
            (418, .unsupportedResponse),
        ]

        for (status, expected) in expectations {
            ProviderUsageStubURLProtocol.handler = { request in
                Self.response(for: request, statusCode: status, body: #"{"secret":"sk-provider-secret"}"#)
            }
            await assertError(expected) {
                _ = try await self.makeClient().fetchUsage(key: "sk-provider-secret")
            }
            XCTAssertFalse(expected.localizedDescription.contains("sk-provider-secret"))
        }
    }

    func testRejectsMalformedMissingModeNegativeAndNonFiniteValues() async throws {
        let invalidBodies = [
            "not-json",
            #"{"balance":1}"#,
            #"{"mode":"unrestricted","balance":-1}"#,
            #"{"mode":"unrestricted","balance":"NaN"}"#,
            #"{"mode":"quota_limited","quota":{"limit":-1,"used":0}}"#,
        ]

        for body in invalidBodies {
            ProviderUsageStubURLProtocol.handler = { request in
                Self.response(for: request, body: body)
            }
            await assertError(.unsupportedResponse) {
                _ = try await self.makeClient().fetchUsage(key: "key")
            }
        }
    }

    func testRejectsResponseLargerThanTwoMiB() async throws {
        ProviderUsageStubURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [:]
            )!
            return (response, Data(repeating: UInt8(ascii: "x"), count: Sub2APIUsageClient.maximumResponseBytes + 1))
        }

        await assertError(.responseTooLarge(limitBytes: Sub2APIUsageClient.maximumResponseBytes)) {
            _ = try await self.makeClient().fetchUsage(key: "key")
        }
    }

    func testSessionDisablesCookiesAndCache() {
        let session = ProviderUsageSessionFactory.makeSession()

        XCTAssertFalse(session.configuration.httpShouldSetCookies)
        XCTAssertEqual(session.configuration.httpCookieAcceptPolicy, .never)
        XCTAssertNil(session.configuration.urlCache)
        XCTAssertEqual(session.configuration.requestCachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(session.configuration.timeoutIntervalForRequest, 10)
        XCTAssertEqual(session.configuration.timeoutIntervalForResource, 10)
        session.invalidateAndCancel()
    }

    func testRedirectDelegateRejectsRedirect() throws {
        let source = URLRequest(url: try XCTUnwrap(URL(string: "https://usage.example/v1/usage")))
        let target = URLRequest(url: try XCTUnwrap(URL(string: "https://other.example/v1/usage")))
        let response = try XCTUnwrap(HTTPURLResponse(
            url: try XCTUnwrap(source.url),
            statusCode: 302,
            httpVersion: "HTTP/1.1",
            headerFields: ["Location": try XCTUnwrap(target.url).absoluteString]
        ))
        let session = URLSession(configuration: .ephemeral)
        let task = session.dataTask(with: source)
        var proposedRequest: URLRequest?
        var completionCalled = false

        ProviderUsageRedirectDelegate().urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: response,
            newRequest: target
        ) {
            completionCalled = true
            proposedRequest = $0
        }

        XCTAssertTrue(completionCalled)
        XCTAssertNil(proposedRequest)
        task.cancel()
        session.invalidateAndCancel()
    }

    private func makeClient() throws -> Sub2APIUsageClient {
        Sub2APIUsageClient(
            root: try ProviderUsageServiceRoot("https://usage.example/sub2api"),
            session: ProviderUsageSessionFactory.makeSession(
                protocolClasses: [ProviderUsageStubURLProtocol.self]
            ),
            now: { self.fixedNow },
            timeZoneIdentifier: "Asia/Shanghai"
        )
    }

    private func assertError(
        _ expected: ProviderUsageError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expected)")
        } catch let error as ProviderUsageError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private static func response(
        for request: URLRequest,
        statusCode: Int = 200,
        body: String
    ) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (response, Data(body.utf8))
    }
}

final class ProviderUsageStubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
