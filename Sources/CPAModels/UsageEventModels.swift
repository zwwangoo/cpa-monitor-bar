import Foundation

public struct UsageEvent: Decodable, Sendable {
    public let id: String?
    public let timestamp: String?
    public let model: String?
    public let modelAlias: String?
    public let apiKey: String?
    public let source: String?
    public let endpoint: String?
    public let failed: Bool?
    public let latencyMS: Int?
    public let ttftMS: Int?

    enum CodingKeys: String, CodingKey {
        case id, timestamp, model, source, endpoint, failed
        case apiKey = "api_key"
        case modelAlias = "model_alias"
        case latencyMS = "latency_ms"
        case ttftMS = "ttft_ms"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id)
        timestamp = try values.decodeIfPresent(String.self, forKey: .timestamp)
        model = try values.decodeIfPresent(String.self, forKey: .model)
        modelAlias = try values.decodeIfPresent(String.self, forKey: .modelAlias)
        apiKey = try values.decodeIfPresent(String.self, forKey: .apiKey)
        source = try values.decodeIfPresent(String.self, forKey: .source)
        endpoint = try values.decodeIfPresent(String.self, forKey: .endpoint)
        failed = try values.flexibleBoolIfPresent(forKey: .failed)
        latencyMS = try values.flexibleIntIfPresent(forKey: .latencyMS)
        ttftMS = try values.flexibleIntIfPresent(forKey: .ttftMS)
    }
}

public struct UsageEventsResponse: Decodable, Sendable {
    public let events: [UsageEvent]
    public let totalCount: Int?
    public let page: Int?
    public let pageSize: Int?
    public let totalPages: Int?

    enum CodingKeys: String, CodingKey {
        case events, page
        case totalCount = "total_count"
        case pageSize = "page_size"
        case totalPages = "total_pages"
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
        let values = try decoder.container(keyedBy: CodingKeys.self)
        events = try values.decodeIfPresent([UsageEvent].self, forKey: .events) ?? []
        totalCount = try values.flexibleIntIfPresent(forKey: .totalCount)
        page = try values.flexibleIntIfPresent(forKey: .page)
        pageSize = try values.flexibleIntIfPresent(forKey: .pageSize)
        totalPages = try values.flexibleIntIfPresent(forKey: .totalPages)
    }
}
