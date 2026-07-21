import Foundation

public struct UsageEventTokens: Codable, Equatable, Sendable {
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let reasoningTokens: Int?
    public let cacheReadTokens: Int?
    public let cacheCreationTokens: Int?
    public let totalTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens", outputTokens = "output_tokens"
        case reasoningTokens = "reasoning_tokens", cacheReadTokens = "cache_read_tokens"
        case cacheCreationTokens = "cache_creation_tokens", totalTokens = "total_tokens"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        inputTokens = try v.flexibleIntIfPresent(forKey: .inputTokens)
        outputTokens = try v.flexibleIntIfPresent(forKey: .outputTokens)
        reasoningTokens = try v.flexibleIntIfPresent(forKey: .reasoningTokens)
        cacheReadTokens = try v.flexibleIntIfPresent(forKey: .cacheReadTokens)
        cacheCreationTokens = try v.flexibleIntIfPresent(forKey: .cacheCreationTokens)
        totalTokens = try v.flexibleIntIfPresent(forKey: .totalTokens)
    }
}

public struct UsageEvent: Codable, Equatable, Identifiable, Sendable {
    public let id: String?
    public let timestamp: String?
    public let model: String?
    public let modelAlias: String?
    public let apiKey: String?
    public let source: String?
    public let sourceType: String?
    public let endpoint: String?
    public let failed: Bool?
    public let latencyMS: Int?
    public let ttftMS: Int?
    public let speedTPS: Double?
    public let tokens: UsageEventTokens?

    enum CodingKeys: String, CodingKey {
        case id, timestamp, model, source, endpoint, failed, tokens
        case apiKey = "api_key"
        case modelAlias = "model_alias", sourceType = "source_type"
        case latencyMS = "latency_ms", ttftMS = "ttft_ms", speedTPS = "speed_tps"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        id = try v.decodeIfPresent(String.self, forKey: .id)
        timestamp = try v.decodeIfPresent(String.self, forKey: .timestamp)
        model = try v.decodeIfPresent(String.self, forKey: .model)
        modelAlias = try v.decodeIfPresent(String.self, forKey: .modelAlias)
        apiKey = try v.decodeIfPresent(String.self, forKey: .apiKey)
        source = try v.decodeIfPresent(String.self, forKey: .source)
        sourceType = try v.decodeIfPresent(String.self, forKey: .sourceType)
        endpoint = try v.decodeIfPresent(String.self, forKey: .endpoint)
        failed = try v.flexibleBoolIfPresent(forKey: .failed)
        latencyMS = try v.flexibleIntIfPresent(forKey: .latencyMS)
        ttftMS = try v.flexibleIntIfPresent(forKey: .ttftMS)
        speedTPS = try v.flexibleDoubleIfPresent(forKey: .speedTPS)
        tokens = try v.decodeIfPresent(UsageEventTokens.self, forKey: .tokens)
    }
}

public struct UsageEventsResponse: Codable, Equatable, Sendable {
    public let events: [UsageEvent]
    public let totalCount: Int?
    public let page: Int?
    public let pageSize: Int?
    public let totalPages: Int?

    enum CodingKeys: String, CodingKey {
        case events, page
        case totalCount = "total_count", pageSize = "page_size", totalPages = "total_pages"
    }

    public init(
        events: [UsageEvent],
        totalCount: Int?,
        page: Int?,
        pageSize: Int?,
        totalPages: Int?
    ) {
        self.events = events
        self.totalCount = totalCount
        self.page = page
        self.pageSize = pageSize
        self.totalPages = totalPages
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        events = try v.decodeIfPresent([UsageEvent].self, forKey: .events) ?? []
        totalCount = try v.flexibleIntIfPresent(forKey: .totalCount)
        page = try v.flexibleIntIfPresent(forKey: .page)
        pageSize = try v.flexibleIntIfPresent(forKey: .pageSize)
        totalPages = try v.flexibleIntIfPresent(forKey: .totalPages)
    }
}
