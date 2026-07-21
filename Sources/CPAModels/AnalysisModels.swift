import Foundation

public struct TokenUsageAnalysis: Codable, Equatable, Sendable {
    public let bucket: String?
    public let inputTokens: Int?
    public let cacheReadTokens: Int?
    public let cacheCreationTokens: Int?
    public let reasoningTokens: Int?
    public let outputTokens: Int?
    public let totalTokens: Int?
    public let requests: Int?
    public let costUSD: Double?
    public let costAvailable: Bool?

    enum CodingKeys: String, CodingKey {
        case bucket, inputTokens = "input_tokens", cacheReadTokens = "cache_read_tokens"
        case cacheCreationTokens = "cache_creation_tokens", reasoningTokens = "reasoning_tokens"
        case outputTokens = "output_tokens", totalTokens = "total_tokens"
        case requests, costUSD = "cost_usd", costAvailable = "cost_available"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        bucket = try v.decodeIfPresent(String.self, forKey: .bucket)
        inputTokens = try v.flexibleIntIfPresent(forKey: .inputTokens)
        cacheReadTokens = try v.flexibleIntIfPresent(forKey: .cacheReadTokens)
        cacheCreationTokens = try v.flexibleIntIfPresent(forKey: .cacheCreationTokens)
        reasoningTokens = try v.flexibleIntIfPresent(forKey: .reasoningTokens)
        outputTokens = try v.flexibleIntIfPresent(forKey: .outputTokens)
        totalTokens = try v.flexibleIntIfPresent(forKey: .totalTokens)
        requests = try v.flexibleIntIfPresent(forKey: .requests)
        costUSD = try v.flexibleDoubleIfPresent(forKey: .costUSD)
        costAvailable = try v.flexibleBoolIfPresent(forKey: .costAvailable)
    }
}

public struct CompositionItem: Codable, Equatable, Sendable, Identifiable {
    public let key: String?
    public let label: String?
    public let totalTokens: Int?
    public let requests: Int?
    public let percent: Double?
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let cacheReadTokens: Int?
    public let cacheCreationTokens: Int?
    public let reasoningTokens: Int?
    public let costUSD: Double?

    public var id: String { key ?? label ?? "unknown" }

    enum CodingKeys: String, CodingKey {
        case key, label, requests, percent
        case totalTokens = "total_tokens", inputTokens = "input_tokens"
        case outputTokens = "output_tokens", cacheReadTokens = "cache_read_tokens"
        case cacheCreationTokens = "cache_creation_tokens", reasoningTokens = "reasoning_tokens"
        case costUSD = "cost_usd"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        key = try v.decodeIfPresent(String.self, forKey: .key)
        label = try v.decodeIfPresent(String.self, forKey: .label)
        totalTokens = v.contains(.totalTokens) ? try v.flexibleIntIfPresent(forKey: .totalTokens) : nil
        requests = v.contains(.requests) ? try v.flexibleIntIfPresent(forKey: .requests) : nil
        percent = v.contains(.percent) ? try v.flexibleDoubleIfPresent(forKey: .percent) : nil
        inputTokens = v.contains(.inputTokens) ? try v.flexibleIntIfPresent(forKey: .inputTokens) : nil
        outputTokens = v.contains(.outputTokens) ? try v.flexibleIntIfPresent(forKey: .outputTokens) : nil
        cacheReadTokens = v.contains(.cacheReadTokens) ? try v.flexibleIntIfPresent(forKey: .cacheReadTokens) : nil
        cacheCreationTokens = v.contains(.cacheCreationTokens) ? try v.flexibleIntIfPresent(forKey: .cacheCreationTokens) : nil
        reasoningTokens = v.contains(.reasoningTokens) ? try v.flexibleIntIfPresent(forKey: .reasoningTokens) : nil
        costUSD = v.contains(.costUSD) ? try v.flexibleDoubleIfPresent(forKey: .costUSD) : nil
    }
}

public struct UsageHeatmap: Codable, Equatable, Sendable {
    public let apiKeys: [String]?
    public let apiKeyLabels: [String: String]?
    public let models: [String]?
    public let cells: [UsageHeatmapCell]?

    enum CodingKeys: String, CodingKey {
        case apiKeys = "api_keys", apiKeyLabels = "api_key_labels", models, cells
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        apiKeys = try v.decodeIfPresent([String].self, forKey: .apiKeys)
        apiKeyLabels = try v.decodeIfPresent([String: String].self, forKey: .apiKeyLabels)
        models = try v.decodeIfPresent([String].self, forKey: .models)
        cells = try v.decodeIfPresent([UsageHeatmapCell].self, forKey: .cells)
    }
}

public struct UsageHeatmapCell: Codable, Equatable, Sendable {
    public let apiKey: String?
    public let model: String?
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let cacheReadTokens: Int?
    public let cacheCreationTokens: Int?
    public let reasoningTokens: Int?
    public let totalTokens: Int?
    public let requests: Int?
    public let costUSD: Double?
    public let costAvailable: Bool?
    public let intensity: Double?

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key", model, requests, intensity
        case inputTokens = "input_tokens", outputTokens = "output_tokens"
        case cacheReadTokens = "cache_read_tokens", cacheCreationTokens = "cache_creation_tokens"
        case reasoningTokens = "reasoning_tokens", totalTokens = "total_tokens"
        case costUSD = "cost_usd", costAvailable = "cost_available"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        apiKey = try v.decodeIfPresent(String.self, forKey: .apiKey)
        model = try v.decodeIfPresent(String.self, forKey: .model)
        inputTokens = try v.flexibleIntIfPresent(forKey: .inputTokens)
        outputTokens = try v.flexibleIntIfPresent(forKey: .outputTokens)
        cacheReadTokens = try v.flexibleIntIfPresent(forKey: .cacheReadTokens)
        cacheCreationTokens = try v.flexibleIntIfPresent(forKey: .cacheCreationTokens)
        reasoningTokens = try v.flexibleIntIfPresent(forKey: .reasoningTokens)
        totalTokens = try v.flexibleIntIfPresent(forKey: .totalTokens)
        requests = try v.flexibleIntIfPresent(forKey: .requests)
        costUSD = try v.flexibleDoubleIfPresent(forKey: .costUSD)
        costAvailable = try v.flexibleBoolIfPresent(forKey: .costAvailable)
        intensity = try v.flexibleDoubleIfPresent(forKey: .intensity)
    }
}

public struct CostBreakdown: Codable, Equatable, Sendable {
    public let uncachedInputCostUSD: Double?
    public let cacheReadCostUSD: Double?
    public let cacheWriteCostUSD: Double?
    public let outputCostUSD: Double?
    public let totalCostUSD: Double?
    public let costAvailable: Bool?

    enum CodingKeys: String, CodingKey {
        case uncachedInputCostUSD = "uncached_input_cost_usd"
        case cacheReadCostUSD = "cache_read_cost_usd", cacheWriteCostUSD = "cache_write_cost_usd"
        case outputCostUSD = "output_cost_usd", totalCostUSD = "total_cost_usd"
        case costAvailable = "cost_available"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        uncachedInputCostUSD = try v.flexibleDoubleIfPresent(forKey: .uncachedInputCostUSD)
        cacheReadCostUSD = try v.flexibleDoubleIfPresent(forKey: .cacheReadCostUSD)
        cacheWriteCostUSD = try v.flexibleDoubleIfPresent(forKey: .cacheWriteCostUSD)
        outputCostUSD = try v.flexibleDoubleIfPresent(forKey: .outputCostUSD)
        totalCostUSD = try v.flexibleDoubleIfPresent(forKey: .totalCostUSD)
        costAvailable = try v.flexibleBoolIfPresent(forKey: .costAvailable)
    }
}

public struct ModelEfficiency: Codable, Equatable, Sendable {
    public let model: String?
    public let requests: Int?
    public let inputTokens: Int?
    public let outputTokens: Int?
    public let cacheReadTokens: Int?
    public let cacheCreationTokens: Int?
    public let reasoningTokens: Int?
    public let totalTokens: Int?
    public let costUSD: Double?
    public let costAvailable: Bool?
    public let costPerRequestUSD: Double?
    public let outputTokensPerRequest: Double?
    public let cacheReadRate: Double?

    enum CodingKeys: String, CodingKey {
        case model, requests, totalTokens = "total_tokens", costUSD = "cost_usd"
        case inputTokens = "input_tokens", outputTokens = "output_tokens"
        case cacheReadTokens = "cache_read_tokens", cacheCreationTokens = "cache_creation_tokens"
        case reasoningTokens = "reasoning_tokens", costAvailable = "cost_available"
        case costPerRequestUSD = "cost_per_request_usd"
        case outputTokensPerRequest = "output_tokens_per_request"
        case cacheReadRate = "cache_read_rate"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        model = try v.decodeIfPresent(String.self, forKey: .model)
        requests = try v.flexibleIntIfPresent(forKey: .requests)
        inputTokens = try v.flexibleIntIfPresent(forKey: .inputTokens)
        outputTokens = try v.flexibleIntIfPresent(forKey: .outputTokens)
        cacheReadTokens = try v.flexibleIntIfPresent(forKey: .cacheReadTokens)
        cacheCreationTokens = try v.flexibleIntIfPresent(forKey: .cacheCreationTokens)
        reasoningTokens = try v.flexibleIntIfPresent(forKey: .reasoningTokens)
        totalTokens = try v.flexibleIntIfPresent(forKey: .totalTokens)
        costUSD = try v.flexibleDoubleIfPresent(forKey: .costUSD)
        costAvailable = try v.flexibleBoolIfPresent(forKey: .costAvailable)
        costPerRequestUSD = try v.flexibleDoubleIfPresent(forKey: .costPerRequestUSD)
        outputTokensPerRequest = try v.flexibleDoubleIfPresent(forKey: .outputTokensPerRequest)
        cacheReadRate = try v.flexibleDoubleIfPresent(forKey: .cacheReadRate)
    }
}

public struct UsageAnalysisResponse: Codable, Equatable, Sendable {
    public let granularity: String?
    public let timezone: String?
    public let rangeStart: String?
    public let rangeEnd: String?
    public let tokenUsage: [TokenUsageAnalysis]
    public let apiKeyComposition: [CompositionItem]
    public let modelComposition: [CompositionItem]
    public let authFilesComposition: [CompositionItem]
    public let aiProviderComposition: [CompositionItem]
    public let heatmap: UsageHeatmap?
    public let costBreakdown: CostBreakdown?
    public let modelEfficiency: [ModelEfficiency]
    public let latencyDiagnostics: LatencyDiagnostics?

    enum CodingKeys: String, CodingKey {
        case granularity, timezone, heatmap
        case rangeStart = "range_start", rangeEnd = "range_end"
        case tokenUsage = "token_usage", apiKeyComposition = "api_key_composition"
        case modelComposition = "model_composition", authFilesComposition = "auth_files_composition"
        case aiProviderComposition = "ai_provider_composition", costBreakdown = "cost_breakdown"
        case modelEfficiency = "model_efficiency", latencyDiagnostics = "latency_diagnostics"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        granularity = try v.decodeIfPresent(String.self, forKey: .granularity)
        timezone = try v.decodeIfPresent(String.self, forKey: .timezone)
        rangeStart = try v.decodeIfPresent(String.self, forKey: .rangeStart)
        rangeEnd = try v.decodeIfPresent(String.self, forKey: .rangeEnd)
        tokenUsage = try v.decodeIfPresent([TokenUsageAnalysis].self, forKey: .tokenUsage) ?? []
        apiKeyComposition = try v.decodeIfPresent([CompositionItem].self, forKey: .apiKeyComposition) ?? []
        modelComposition = try v.decodeIfPresent([CompositionItem].self, forKey: .modelComposition) ?? []
        authFilesComposition = try v.decodeIfPresent([CompositionItem].self, forKey: .authFilesComposition) ?? []
        aiProviderComposition = try v.decodeIfPresent([CompositionItem].self, forKey: .aiProviderComposition) ?? []
        heatmap = try v.decodeIfPresent(UsageHeatmap.self, forKey: .heatmap)
        costBreakdown = try v.decodeIfPresent(CostBreakdown.self, forKey: .costBreakdown)
        modelEfficiency = try v.decodeIfPresent([ModelEfficiency].self, forKey: .modelEfficiency) ?? []
        latencyDiagnostics = try v.decodeIfPresent(LatencyDiagnostics.self, forKey: .latencyDiagnostics)
    }
}
