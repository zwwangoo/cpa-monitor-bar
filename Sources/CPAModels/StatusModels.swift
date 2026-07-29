import Foundation

public struct KeeperVersionResponse: Decodable, Sendable {
    public let version: String

    enum CodingKeys: CodingKey {
        case version
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decodeIfPresent(String.self, forKey: .version) ?? ""
    }
}

public struct KeeperStatusResponse: Decodable, Sendable {
    public let running: Bool

    enum CodingKeys: CodingKey {
        case running
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        running = try values.decodeIfPresent(Bool.self, forKey: .running) ?? false
    }
}
