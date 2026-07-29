import Foundation

public struct UsageTotals: Decodable, Sendable {
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

public struct UsageSummary: Decodable, Sendable {
    public let totalCost: Double?

    enum CodingKeys: String, CodingKey {
        case totalCost = "total_cost"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        totalCost = try values.flexibleDoubleIfPresent(forKey: .totalCost)
    }
}

public struct ServiceHealth: Decodable, Sendable {
    public let successRate: Double?

    enum CodingKeys: String, CodingKey {
        case successRate = "success_rate"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        successRate = try values.flexibleDoubleIfPresent(forKey: .successRate)
    }
}

public struct UsageOverviewResponse: Decodable, Sendable {
    public let usage: UsageTotals?
    public let summary: UsageSummary?
    public let serviceHealth: ServiceHealth?

    enum CodingKeys: String, CodingKey {
        case usage, summary
        case serviceHealth = "service_health"
    }

    public var successRate: Double? {
        if let successRate = serviceHealth?.successRate { return successRate }
        guard let usage,
              let successCount = usage.successCount,
              let totalRequests = usage.totalRequests,
              totalRequests > 0 else { return nil }
        let percent = Double(successCount) / Double(totalRequests) * 100
        return min(max(percent, 0), 100)
    }
}
