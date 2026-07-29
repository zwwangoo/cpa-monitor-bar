import Foundation
import XCTest
@testable import CPAClient
@testable import CPAModels

final class CPAClientTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testTypedGETMethodsUseExactWhitelistedURLs() async throws {
        let responses: [String: String] = [
            "/cpa/healthz": #"{"status":"ok"}"#,
            "/cpa/api/v1/auth/session": #"{"authenticated":true,"role":"admin"}"#,
            "/cpa/api/v1/status": #"{"running":true,"sync_running":false}"#,
            "/cpa/api/v1/version": #"{"version":"v1.13.5"}"#,
            "/cpa/api/v1/usage/overview": try fixtureBody("overview"),
            "/cpa/api/v1/usage/analysis": try fixtureBody("analysis"),
            "/cpa/api/v1/usage/activity": try fixtureBody("activity"),
        ]
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            let path = try XCTUnwrap(request.url?.path)
            let components = try XCTUnwrap(
                URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)
            )
            if path == "/cpa/api/v1/usage/overview"
                || path == "/cpa/api/v1/usage/analysis" {
                XCTAssertEqual(components.percentEncodedQuery, "range=today")
            } else if path == "/cpa/api/v1/usage/activity" {
                XCTAssertEqual(components.percentEncodedQuery, "window=day")
            } else {
                XCTAssertNil(components.percentEncodedQuery)
            }
            XCTAssertNil(request.value(forHTTPHeaderField: "X-CPA-Usage-Keeper-Request"))
            return Self.response(for: request, body: try XCTUnwrap(responses[path]))
        }
        let client = try makeClient()

        _ = try await client.health()
        _ = try await client.session()
        _ = try await client.status()
        _ = try await client.version()
        _ = try await client.overview()
        _ = try await client.analysis()
        _ = try await client.activity()
    }

    func testLoginBodyIsOnlyPasswordAndAccepts204() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/cpa/api/v1/auth/login")
            XCTAssertNil(request.url?.query)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "X-CPA-Usage-Keeper-Request"),
                "fetch"
            )
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            var inspectedRequest = request
            let body = try Self.bodyData(from: &inspectedRequest)
            let object = try JSONSerialization.jsonObject(with: body)
            XCTAssertEqual(object as? [String: String], ["password": "fixture-password"])
            return Self.response(for: request, status: 204, body: "")
        }

        try await makeClient().login(password: "fixture-password")
    }

    func testLoginAcceptsJSONWithoutExposingOrPersistingToken() async throws {
        StubURLProtocol.handler = { request in
            Self.response(for: request, body: #"{"session_token":"fixture-response-token"}"#)
        }

        try await makeClient().login(password: "fixture-password")
    }

    func testLoginCookieIsSentOnSubsequentSessionRequestAndLogoutClearsIt() async throws {
        let cookieStore = SessionCookieStore()
        let client = try makeClient(cookieStore: cookieStore)
        StubURLProtocol.handler = { request in
            switch request.url?.path {
            case "/cpa/api/v1/auth/login":
                return Self.response(
                    for: request,
                    status: 204,
                    headers: ["Set-Cookie": "cpa_usage_keeper_session=fixture-cookie; Path=/cpa; HttpOnly"],
                    body: ""
                )
            case "/cpa/api/v1/auth/session":
                XCTAssertTrue(
                    request.value(forHTTPHeaderField: "Cookie")?
                        .contains("cpa_usage_keeper_session=fixture-cookie") == true
                )
                return Self.response(for: request, body: #"{"authenticated":true}"#)
            case "/cpa/api/v1/auth/logout":
                XCTAssertEqual(request.httpMethod, "POST")
                XCTAssertNil(request.url?.query)
                XCTAssertEqual(
                    request.value(forHTTPHeaderField: "X-CPA-Usage-Keeper-Request"),
                    "fetch"
                )
                XCTAssertTrue(
                    request.value(forHTTPHeaderField: "Cookie")?
                        .contains("cpa_usage_keeper_session=fixture-cookie") == true
                )
                XCTAssertNil(request.httpBody)
                return Self.response(for: request, status: 204, body: "")
            default:
                throw URLError(.unsupportedURL)
            }
        }

        try await client.login(password: "fixture-password")
        XCTAssertEqual(cookieStore.cookies.count, 1)
        XCTAssertEqual(cookieStore.cookies.first?.path, "/cpa")
        let session = try await client.session()
        XCTAssertTrue(session.authenticated)
        try await client.logout()
        XCTAssertTrue(cookieStore.cookies.isEmpty)
    }

    func testLogoutClearsLocalCookieWhenRequestFails() async throws {
        let cookieStore = SessionCookieStore()
        let client = try makeClient(cookieStore: cookieStore)
        StubURLProtocol.handler = { request in
            if request.url?.path == "/cpa/api/v1/auth/login" {
                return Self.response(
                    for: request,
                    status: 204,
                    headers: ["Set-Cookie": "cpa_usage_keeper_session=fixture-cookie; Path=/cpa"],
                    body: ""
                )
            }
            throw URLError(.notConnectedToInternet)
        }

        try await client.login(password: "fixture-password")
        XCTAssertEqual(cookieStore.cookies.count, 1)

        do {
            try await client.logout()
            XCTFail("Expected logout to fail")
        } catch {
            XCTAssertTrue(cookieStore.cookies.isEmpty)
        }
    }

    func testMapsAuthenticationStatuses() async throws {
        for status in [401, 403] {
            StubURLProtocol.handler = { request in
                Self.response(for: request, status: status, body: "{}")
            }
            await assertClientError(.authenticationRequired) {
                _ = try await self.makeClient().status()
            }
        }
    }

    func testMapsRateLimitAndServerErrors() async throws {
        StubURLProtocol.handler = { request in
            Self.response(for: request, status: 429, body: "{}")
        }
        await assertClientError(.rateLimited) { _ = try await self.makeClient().overview() }

        StubURLProtocol.handler = { request in
            Self.response(for: request, status: 503, body: "{}")
        }
        await assertClientError(.serverUnavailable(statusCode: 503)) {
            _ = try await self.makeClient().analysis()
        }
    }

    func testMapsNetworkAndDecodingErrors() async throws {
        StubURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        do {
            _ = try await makeClient().health()
            XCTFail("Expected network error")
        } catch let CPAClientError.network(message) {
            XCTAssertFalse(message.isEmpty)
        }

        StubURLProtocol.handler = { request in
            Self.response(for: request, body: #"{"running":"not-a-bool"}"#)
        }
        do {
            _ = try await makeClient().status()
            XCTFail("Expected decoding error")
        } catch let CPAClientError.decoding(message) {
            XCTAssertTrue(message.contains("running"), message)
            XCTAssertTrue(message.contains("Bool"), message)
        }
    }

    private func makeClient(cookieStore: SessionCookieStore = SessionCookieStore()) throws -> CPAClient {
        let session = cookieStore.makeSession(protocolClasses: [StubURLProtocol.self])
        return CPAClient(root: try CPAServiceRoot("https://example.test/cpa"), session: session, cookieStore: cookieStore)
    }

    private func assertClientError(
        _ expected: CPAClientError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expected)")
        } catch let error as CPAClientError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func fixtureBody(_ name: String) throws -> String {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func bodyData(from request: inout URLRequest) throws -> Data {
        if let body = request.httpBody { return body }
        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open()
        defer { stream.close() }

        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 { throw stream.streamError ?? URLError(.cannotDecodeContentData) }
            if count == 0 { break }
            body.append(contentsOf: buffer[..<count])
        }
        request.httpBodyStream = InputStream(data: body)
        return body
    }

    private static func response(
        for request: URLRequest,
        status: Int = 200,
        headers: [String: String] = [:],
        body: String
    ) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        return (response, Data(body.utf8))
    }
}

final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !data.isEmpty { client?.urlProtocol(self, didLoad: data) }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
