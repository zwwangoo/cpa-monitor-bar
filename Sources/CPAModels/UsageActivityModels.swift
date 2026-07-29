import Foundation

public struct UsageActivityBlock: Decodable, Equatable, Sendable {
    public let startTime: String?
    public let endTime: String?
    public let success: Int?
    public let failure: Int?

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case success, failure
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        startTime = try values.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try values.decodeIfPresent(String.self, forKey: .endTime)
        success = try values.flexibleIntIfPresent(forKey: .success)
        failure = try values.flexibleIntIfPresent(forKey: .failure)
    }
}

public struct UsageActivityResponse: Decodable, Sendable {
    public let rows: Int?
    public let columns: Int?
    public let totalSuccess: Int?
    public let totalFailure: Int?
    public let successRate: Double?
    public let blocks: [UsageActivityBlock]

    enum CodingKeys: String, CodingKey {
        case rows, columns, blocks
        case totalSuccess = "total_success"
        case totalFailure = "total_failure"
        case successRate = "success_rate"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        rows = try values.flexibleIntIfPresent(forKey: .rows)
        columns = try values.flexibleIntIfPresent(forKey: .columns)
        totalSuccess = try values.flexibleIntIfPresent(forKey: .totalSuccess)
        totalFailure = try values.flexibleIntIfPresent(forKey: .totalFailure)
        successRate = try values.flexibleDoubleIfPresent(forKey: .successRate)
        blocks = try values.decodeIfPresent([UsageActivityBlock].self, forKey: .blocks) ?? []
    }
}
