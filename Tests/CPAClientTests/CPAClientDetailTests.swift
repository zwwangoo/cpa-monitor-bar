import Foundation
import XCTest
@testable import CPAClient

final class CPAClientDetailTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testDetailGETMethodsUseTodayEventsAndCredentialQueries() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertNil(request.value(forHTTPHeaderField: "X-CPA-Usage-Keeper-Request"))
            let path = try XCTUnwrap(request.url?.path)
            let query = try XCTUnwrap(request.url?.query)
            switch path {
            case "/cpa/api/v1/usage/events":
                XCTAssertEqual(query, "range=today&page=1&page_size=20")
                return Self.response(for: request, body: #"{"events":[]}"#)
            case "/cpa/api/v1/usage/identities/page":
                XCTAssertTrue([
                    "auth_type=1&page=1&page_size=10",
                    "auth_type=2&page=1&page_size=10",
                ].contains(query))
                return Self.response(for: request, body: #"{"identities":[]}"#)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        let client = try makeClient()

        _ = try await client.events()
        _ = try await client.authFiles()
        _ = try await client.providers()
    }

    func testQuotaCacheUsesOnlyExactReadOnlyPostContract() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/cpa/api/v1/quota/cache")
            XCTAssertNil(request.url?.query)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "X-CPA-Usage-Keeper-Request"),
                "fetch"
            )
            var inspectedRequest = request
            let body = try Self.bodyData(from: &inspectedRequest)
            let object = try JSONSerialization.jsonObject(with: body) as? [String: [String]]
            XCTAssertEqual(object, ["auth_indexes": ["auth-1", "auth-2"]])
            return Self.response(for: request, body: #"{"items":[]}"#)
        }

        _ = try await makeClient().quotaCache(authIndexes: ["auth-1", "auth-2"])
    }

    func testQuotaRefreshUsesBatchPostAndSingleStatusGetContracts() async throws {
        StubURLProtocol.handler = { request in
            let path = try XCTUnwrap(request.url?.path)
            if request.httpMethod == "POST" {
                XCTAssertEqual(
                    request.value(forHTTPHeaderField: "X-CPA-Usage-Keeper-Request"),
                    "fetch"
                )
                XCTAssertEqual(path, "/cpa/api/v1/quota/refresh")
                var inspectedRequest = request
                let body = try Self.bodyData(from: &inspectedRequest)
                let object = try JSONSerialization.jsonObject(with: body) as? [String: [String]]
                XCTAssertEqual(object, ["auth_indexes": ["auth-1"]])
                return Self.response(
                    for: request,
                    body: #"{"tasks":[{"authIndex":"auth-1"}],"rejected":[]}"#
                )
            }
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertNil(request.value(forHTTPHeaderField: "X-CPA-Usage-Keeper-Request"))
            XCTAssertEqual(path, "/cpa/api/v1/quota/refresh/auth-1")
            return Self.response(
                for: request,
                body: #"{"authIndex":"auth-1","status":"completed","quota":{"quota":[]}}"#
            )
        }
        let client = try makeClient()

        let batch = try await client.refreshQuota(authIndexes: ["auth-1"])
        let task = try await client.quotaRefreshStatus(authIndex: "auth-1")

        XCTAssertEqual(batch.tasks.first?.authIndex, "auth-1")
        XCTAssertEqual(task.status, "completed")
    }

    func testUsageMethodsForwardSelectedRange() async throws {
        StubURLProtocol.handler = { request in
            let query = try XCTUnwrap(request.url?.query)
            switch request.url?.path {
            case "/cpa/api/v1/usage/overview":
                XCTAssertEqual(query, "range=8h")
                return Self.response(for: request, body: "{}")
            case "/cpa/api/v1/usage/analysis":
                XCTAssertEqual(query, "range=yesterday")
                return Self.response(for: request, body: "{}")
            case "/cpa/api/v1/usage/events":
                XCTAssertEqual(query, "range=yesterday&page=1&page_size=20")
                return Self.response(for: request, body: #"{"events":[]}"#)
            default:
                throw URLError(.unsupportedURL)
            }
        }
        let client = try makeClient()

        _ = try await client.overview(range: .last8Hours)
        _ = try await client.analysis(range: .yesterday)
        _ = try await client.events(range: .yesterday)
    }

    func testEventsForwardsRequestedPage() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(
                request.url?.query,
                "range=today&page=3&page_size=20"
            )
            return Self.response(for: request, body: #"{"events":[],"page":3}"#)
        }

        let response = try await makeClient().events(range: .today, page: 3, pageSize: 20)

        XCTAssertEqual(response.page, 3)
    }

    private func makeClient() throws -> CPAClient {
        let cookieStore = SessionCookieStore()
        let session = cookieStore.makeSession(protocolClasses: [StubURLProtocol.self])
        return CPAClient(
            root: try CPAServiceRoot("https://example.test/cpa"),
            session: session,
            cookieStore: cookieStore
        )
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
        return body
    }

    private static func response(
        for request: URLRequest,
        body: String
    ) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: [:]
        )!
        return (response, Data(body.utf8))
    }
}
