import Foundation

public struct CompositionItem: Decodable, Sendable {
    public let key: String?
    public let label: String?
    public let totalTokens: Int?
    public let requests: Int?
    public let percent: Double?
    public let costUSD: Double?

    enum CodingKeys: String, CodingKey {
        case key, label, requests, percent
        case totalTokens = "total_tokens"
        case costUSD = "cost_usd"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        key = try values.decodeIfPresent(String.self, forKey: .key)
        label = try values.decodeIfPresent(String.self, forKey: .label)
        totalTokens = try values.flexibleIntIfPresent(forKey: .totalTokens)
        requests = try values.flexibleIntIfPresent(forKey: .requests)
        percent = try values.flexibleDoubleIfPresent(forKey: .percent)
        costUSD = try values.flexibleDoubleIfPresent(forKey: .costUSD)
    }
}

public struct UsageAnalysisResponse: Decodable, Sendable {
    public let apiKeyComposition: [CompositionItem]
    public let modelComposition: [CompositionItem]
    public let authFilesComposition: [CompositionItem]
    public let aiProviderComposition: [CompositionItem]

    enum CodingKeys: String, CodingKey {
        case apiKeyComposition = "api_key_composition"
        case modelComposition = "model_composition"
        case authFilesComposition = "auth_files_composition"
        case aiProviderComposition = "ai_provider_composition"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        apiKeyComposition = try values.decodeIfPresent(
            [CompositionItem].self,
            forKey: .apiKeyComposition
        ) ?? []
        modelComposition = try values.decodeIfPresent(
            [CompositionItem].self,
            forKey: .modelComposition
        ) ?? []
        authFilesComposition = try values.decodeIfPresent(
            [CompositionItem].self,
            forKey: .authFilesComposition
        ) ?? []
        aiProviderComposition = try values.decodeIfPresent(
            [CompositionItem].self,
            forKey: .aiProviderComposition
        ) ?? []
    }
}
