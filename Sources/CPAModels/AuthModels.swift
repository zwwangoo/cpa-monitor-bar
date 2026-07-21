import Foundation

public struct HealthResponse: Codable, Equatable, Sendable {
    public let status: String?
}

public struct SessionAPIKey: Codable, Equatable, Sendable {
    public let displayKey: String?
    public let alias: String?

    enum CodingKeys: String, CodingKey {
        case displayKey = "display_key"
        case alias
    }
}

public struct AuthSessionResponse: Codable, Equatable, Sendable {
    public let authenticated: Bool
    public let role: String?
    public let apiKey: SessionAPIKey?

    enum CodingKeys: String, CodingKey {
        case authenticated, role
        case apiKey = "api_key"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        authenticated = try values.decodeIfPresent(Bool.self, forKey: .authenticated) ?? false
        role = try values.decodeIfPresent(String.self, forKey: .role)
        apiKey = try values.decodeIfPresent(SessionAPIKey.self, forKey: .apiKey)
    }
}

public struct LoginResponse: Codable, Equatable, Sendable {
    public let sessionToken: String?

    enum CodingKeys: String, CodingKey {
        case sessionToken = "session_token"
    }
}
