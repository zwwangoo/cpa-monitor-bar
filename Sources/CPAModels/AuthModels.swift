import Foundation

public struct HealthResponse: Decodable, Sendable {
    public let status: String?
}

public struct AuthSessionResponse: Decodable, Sendable {
    public let authenticated: Bool

    enum CodingKeys: CodingKey {
        case authenticated
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        authenticated = try values.decodeIfPresent(Bool.self, forKey: .authenticated) ?? false
    }
}
