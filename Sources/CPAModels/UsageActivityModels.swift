import Foundation

public struct UsageActivityBlock: Codable, Equatable, Sendable {
    public let startTime: String?
    public let endTime: String?
    public let success: Int?
    public let failure: Int?
    public let rate: Double?

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time"
        case endTime = "end_time"
        case success, failure, rate
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        startTime = try values.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try values.decodeIfPresent(String.self, forKey: .endTime)
        success = try values.flexibleIntIfPresent(forKey: .success)
        failure = try values.flexibleIntIfPresent(forKey: .failure)
        rate = try values.flexibleDoubleIfPresent(forKey: .rate)
    }
}

public struct UsageActivityResponse: Codable, Equatable, Sendable {
    public let window: String?
    public let grain: String?
    public let timezone: String?
    public let rows: Int?
    public let columns: Int?
    public let bucketSeconds: Int?
    public let windowStart: String?
    public let windowEnd: String?
    public let totalSuccess: Int?
    public let totalFailure: Int?
    public let successRate: Double?
    public let blocks: [UsageActivityBlock]

    enum CodingKeys: String, CodingKey {
        case window, grain, timezone, rows, columns, blocks
        case bucketSeconds = "bucket_seconds"
        case windowStart = "window_start"
        case windowEnd = "window_end"
        case totalSuccess = "total_success"
        case totalFailure = "total_failure"
        case successRate = "success_rate"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        window = try values.decodeIfPresent(String.self, forKey: .window)
        grain = try values.decodeIfPresent(String.self, forKey: .grain)
        timezone = try values.decodeIfPresent(String.self, forKey: .timezone)
        rows = try values.flexibleIntIfPresent(forKey: .rows)
        columns = try values.flexibleIntIfPresent(forKey: .columns)
        bucketSeconds = try values.flexibleIntIfPresent(forKey: .bucketSeconds)
        windowStart = try values.decodeIfPresent(String.self, forKey: .windowStart)
        windowEnd = try values.decodeIfPresent(String.self, forKey: .windowEnd)
        totalSuccess = try values.flexibleIntIfPresent(forKey: .totalSuccess)
        totalFailure = try values.flexibleIntIfPresent(forKey: .totalFailure)
        successRate = try values.flexibleDoubleIfPresent(forKey: .successRate)
        blocks = try values.decodeIfPresent([UsageActivityBlock].self, forKey: .blocks) ?? []
    }
}
