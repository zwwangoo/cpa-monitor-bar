import Foundation

enum CPARedirectPolicy {
    static func shouldFollow(from source: URLRequest?, to target: URLRequest) -> Bool {
        _ = source
        _ = target
        return false
    }
}

private final class RejectingRedirectDelegate: NSObject, URLSessionTaskDelegate,
    @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        _ = session
        _ = response
        let allowed = CPARedirectPolicy.shouldFollow(from: task.originalRequest, to: request)
        completionHandler(allowed ? request : nil)
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
