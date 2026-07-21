import Foundation

public struct KeeperVersionResponse: Codable, Equatable, Sendable {
    public let version: String

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decodeIfPresent(String.self, forKey: .version) ?? ""
    }
}

public struct KeeperStatusResponse: Codable, Equatable, Sendable {
    public let running: Bool
    public let syncRunning: Bool
    public let timezone: String?
    public let cpaPublicURL: String?
    public let cpaRequestLogAccessEnabled: Bool?
    public let lastError: String?
    public let lastWarning: String?
    public let lastStatus: String?

    enum CodingKeys: String, CodingKey {
        case running
        case syncRunning = "sync_running"
        case timezone
        case cpaPublicURL = "cpa_public_url"
        case cpaRequestLogAccessEnabled = "cpa_request_log_access_enabled"
        case lastError = "last_error"
        case lastWarning = "last_warning"
        case lastStatus = "last_status"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        running = try values.decodeIfPresent(Bool.self, forKey: .running) ?? false
        syncRunning = try values.decodeIfPresent(Bool.self, forKey: .syncRunning) ?? false
        timezone = try values.decodeIfPresent(String.self, forKey: .timezone)
        cpaPublicURL = try values.decodeIfPresent(String.self, forKey: .cpaPublicURL)
        cpaRequestLogAccessEnabled = try values.decodeIfPresent(Bool.self, forKey: .cpaRequestLogAccessEnabled)
        lastError = try values.decodeIfPresent(String.self, forKey: .lastError)
        lastWarning = try values.decodeIfPresent(String.self, forKey: .lastWarning)
        lastStatus = try values.decodeIfPresent(String.self, forKey: .lastStatus)
    }
}
