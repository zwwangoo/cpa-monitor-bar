import Foundation

final class RejectingRedirectDelegate: NSObject, URLSessionTaskDelegate,
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

struct CPAResponseLoader: Sendable {
    let session: URLSession
    let maximumResponseBytes: Int
    private let redirectDelegate = RejectingRedirectDelegate()

    func load(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let (bytes, response) = try await session.bytes(
            for: request,
            delegate: redirectDelegate
        )
        if response.expectedContentLength > maximumResponseBytes {
            bytes.task.cancel()
            throw CPAClientError.responseTooLarge(limitBytes: maximumResponseBytes)
        }

        var data = Data()
        let expectedLength = max(response.expectedContentLength, 0)
        data.reserveCapacity(min(Int(expectedLength), maximumResponseBytes))
        for try await byte in bytes {
            guard data.count < maximumResponseBytes else {
                bytes.task.cancel()
                throw CPAClientError.responseTooLarge(limitBytes: maximumResponseBytes)
            }
            data.append(byte)
        }
        return (data, response)
    }
}
