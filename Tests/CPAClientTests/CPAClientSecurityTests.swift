import Foundation
import XCTest
@testable import CPAClient

final class CPAClientSecurityTests: XCTestCase {
    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    func testSessionDisablesAutomaticCookieHandling() {
        let session = SessionCookieStore().makeSession()

        XCTAssertFalse(session.configuration.httpShouldSetCookies)
    }

    func testRedirectPolicyRejectsEveryRedirect() throws {
        let source = URLRequest(url: try XCTUnwrap(URL(string: "https://example.test/cpa/healthz")))
        let target = URLRequest(url: try XCTUnwrap(URL(string: "https://example.test/cpa/healthz")))

        XCTAssertFalse(CPARedirectPolicy.shouldFollow(from: source, to: target))
    }

    func testResponseLargerThanLimitIsRejected() async throws {
        StubURLProtocol.handler = { request in
            let response = Self.response(for: request, body: "{}")
            return (
                response.0,
                Data(repeating: UInt8(ascii: "x"), count: CPAClient.maximumResponseBytes + 1)
            )
        }

        await assertClientError(
            .responseTooLarge(limitBytes: CPAClient.maximumResponseBytes)
        ) {
            _ = try await self.makeClient().health()
        }
    }

    func testListResponseLargerThanItemLimitIsRejected() async throws {
        let identities = Array(
            repeating: "{}",
            count: CPAClient.maximumListItems + 1
        ).joined(separator: ",")
        StubURLProtocol.handler = { request in
            Self.response(for: request, body: #"{"identities":[\#(identities)]}"#)
        }

        await assertClientError(.tooManyItems(limit: CPAClient.maximumListItems)) {
            _ = try await self.makeClient().authFiles()
        }
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
