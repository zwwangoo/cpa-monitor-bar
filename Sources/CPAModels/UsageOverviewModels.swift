import Foundation

public struct UsageTotals: Codable, Equatable, Sendable {
    public let totalRequests: Int?
    public let successCount: Int?
    public let failureCount: Int?
    public let totalTokens: Int?

    enum CodingKeys: String, CodingKey {
        case totalRequests = "total_requests"
        case successCount = "success_count"
        case failureCount = "failure_count"
        case totalTokens = "total_tokens"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        totalRequests = try values.flexibleIntIfPresent(forKey: .totalRequests)
        successCount = try values.flexibleIntIfPresent(forKey: .successCount)
        failureCount = try values.flexibleIntIfPresent(forKey: .failureCount)
        totalTokens = try values.flexibleIntIfPresent(forKey: .totalTokens)
    }
}

public struct UsageSummary: Codable, Equatable, Sendable {
    public let requestCount: Int?
    public let tokenCount: Int?
    public let windowMinutes: Int?
    public let rpm: Double?
    public let tpm: Double?
    public let totalCost: Double?
    public let costAvailable: Bool?
    public let inputTokens: Int?
    public let cacheReadTokens: Int?
    public let cacheCreationTokens: Int?
    public let reasoningTokens: Int?
    public let dailyAverageRequests: Double?
    public let dailyAverageTokens: Double?
    public let dailyAverageCost: Double?
    public let dailyAverageRangeDays: Int?

    enum CodingKeys: String, CodingKey {
        case requestCount = "request_count", tokenCount = "token_count"
        case windowMinutes = "window_minutes", rpm, tpm
        case totalCost = "total_cost", costAvailable = "cost_available"
        case inputTokens = "input_tokens", cacheReadTokens = "cache_read_tokens"
        case cacheCreationTokens = "cache_creation_tokens"
        case reasoningTokens = "reasoning_tokens"
        case dailyAverageRequests = "daily_average_requests"
        case dailyAverageTokens = "daily_average_tokens"
        case dailyAverageCost = "daily_average_cost"
        case dailyAverageRangeDays = "daily_average_range_days"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        requestCount = try v.flexibleIntIfPresent(forKey: .requestCount)
        tokenCount = try v.flexibleIntIfPresent(forKey: .tokenCount)
        windowMinutes = try v.flexibleIntIfPresent(forKey: .windowMinutes)
        rpm = try v.flexibleDoubleIfPresent(forKey: .rpm)
        tpm = try v.flexibleDoubleIfPresent(forKey: .tpm)
        totalCost = try v.flexibleDoubleIfPresent(forKey: .totalCost)
        costAvailable = try v.decodeIfPresent(Bool.self, forKey: .costAvailable)
        inputTokens = try v.flexibleIntIfPresent(forKey: .inputTokens)
        cacheReadTokens = try v.flexibleIntIfPresent(forKey: .cacheReadTokens)
        cacheCreationTokens = try v.flexibleIntIfPresent(forKey: .cacheCreationTokens)
        reasoningTokens = try v.flexibleIntIfPresent(forKey: .reasoningTokens)
        dailyAverageRequests = try v.flexibleDoubleIfPresent(forKey: .dailyAverageRequests)
        dailyAverageTokens = try v.flexibleDoubleIfPresent(forKey: .dailyAverageTokens)
        dailyAverageCost = try v.flexibleDoubleIfPresent(forKey: .dailyAverageCost)
        dailyAverageRangeDays = try v.flexibleIntIfPresent(forKey: .dailyAverageRangeDays)
    }
}

public struct UsageSeries: Codable, Equatable, Sendable {
    public let requests: [String: Double]?
    public let tokens: [String: Double]?
    public let rpm: [String: Double]?
    public let tpm: [String: Double]?
    public let cost: [String: Double]?
    public let cacheReadRate: [String: Double?]?

    enum CodingKeys: String, CodingKey {
        case requests, tokens, rpm, tpm, cost
        case cacheReadRate = "cache_read_rate"
    }
}

public struct ServiceHealthBlock: Codable, Equatable, Sendable {
    public let startTime: String?
    public let endTime: String?
    public let success: Int?
    public let failure: Int?
    public let rate: Double?

    enum CodingKeys: String, CodingKey {
        case startTime = "start_time", endTime = "end_time"
        case success, failure, rate
    }
}

public struct ServiceHealth: Codable, Equatable, Sendable {
    public let totalSuccess: Int?
    public let totalFailure: Int?
    public let successRate: Double?
    public let rows: Int?
    public let columns: Int?
    public let bucketSeconds: Int?
    public let windowStart: String?
    public let windowEnd: String?
    public let blockDetails: [ServiceHealthBlock]?

    enum CodingKeys: String, CodingKey {
        case totalSuccess = "total_success", totalFailure = "total_failure"
        case successRate = "success_rate", rows, columns
        case bucketSeconds = "bucket_seconds", windowStart = "window_start"
        case windowEnd = "window_end", blockDetails = "block_details"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        totalSuccess = try v.flexibleIntIfPresent(forKey: .totalSuccess)
        totalFailure = try v.flexibleIntIfPresent(forKey: .totalFailure)
        successRate = try v.flexibleDoubleIfPresent(forKey: .successRate)
        rows = try v.flexibleIntIfPresent(forKey: .rows)
        columns = try v.flexibleIntIfPresent(forKey: .columns)
        bucketSeconds = try v.flexibleIntIfPresent(forKey: .bucketSeconds)
        windowStart = try v.decodeIfPresent(String.self, forKey: .windowStart)
        windowEnd = try v.decodeIfPresent(String.self, forKey: .windowEnd)
        blockDetails = try v.decodeIfPresent([ServiceHealthBlock].self, forKey: .blockDetails)
    }
}

public struct UsageOverviewResponse: Codable, Equatable, Sendable {
    public let usage: UsageTotals?
    public let summary: UsageSummary?
    public let series: UsageSeries?
    public let serviceHealth: ServiceHealth?
    public let timezone: String?
    public let rangeStart: String?
    public let rangeEnd: String?

    enum CodingKeys: String, CodingKey {
        case usage, summary, series, timezone
        case serviceHealth = "service_health"
        case rangeStart = "range_start", rangeEnd = "range_end"
    }
}
