import Foundation

public struct TokenVelocityPoint: Codable, Equatable, Sendable {
    public let bucket: String?
    public let tokensPerMinute: Double?
    public let tokens: Int?
    public let cost: Double?

    enum CodingKeys: String, CodingKey {
        case bucket, tokens, cost
        case tokensPerMinute = "tokens_per_minute"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        bucket = try v.decodeIfPresent(String.self, forKey: .bucket)
        tokensPerMinute = try v.flexibleDoubleIfPresent(forKey: .tokensPerMinute)
        tokens = try v.flexibleIntIfPresent(forKey: .tokens)
        cost = try v.flexibleDoubleIfPresent(forKey: .cost)
    }
}

public struct ResponseLevelPoint: Codable, Equatable, Sendable {
    public let bucket: String?
    public let ttftP50MS: Double?
    public let ttftP95MS: Double?
    public let latencyP50MS: Double?
    public let latencyP95MS: Double?

    enum CodingKeys: String, CodingKey {
        case bucket
        case ttftP50MS = "ttft_p50_ms", ttftP95MS = "ttft_p95_ms"
        case latencyP50MS = "latency_p50_ms", latencyP95MS = "latency_p95_ms"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        bucket = try v.decodeIfPresent(String.self, forKey: .bucket)
        ttftP50MS = try v.flexibleDoubleIfPresent(forKey: .ttftP50MS)
        ttftP95MS = try v.flexibleDoubleIfPresent(forKey: .ttftP95MS)
        latencyP50MS = try v.flexibleDoubleIfPresent(forKey: .latencyP50MS)
        latencyP95MS = try v.flexibleDoubleIfPresent(forKey: .latencyP95MS)
    }
}

public struct RequestLevelPoint: Codable, Equatable, Sendable {
    public let bucket: String?
    public let requestsPerMinute: Double?
    public let requests: Int?

    enum CodingKeys: String, CodingKey {
        case bucket, requests
        case requestsPerMinute = "requests_per_minute"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        bucket = try v.decodeIfPresent(String.self, forKey: .bucket)
        requestsPerMinute = try v.flexibleDoubleIfPresent(forKey: .requestsPerMinute)
        requests = try v.flexibleIntIfPresent(forKey: .requests)
    }
}

public struct CacheLevelPoint: Codable, Equatable, Sendable {
    public let bucket: String?
    public let cacheReadRate: Double?
    public let cacheReadTokens: Int?
    public let cacheCreationTokens: Int?
    public let inputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case bucket, inputTokens = "input_tokens"
        case cacheReadRate = "cache_read_rate", cacheReadTokens = "cache_read_tokens"
        case cacheCreationTokens = "cache_creation_tokens"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        bucket = try v.decodeIfPresent(String.self, forKey: .bucket)
        cacheReadRate = try v.flexibleDoubleIfPresent(forKey: .cacheReadRate)
        cacheReadTokens = try v.flexibleIntIfPresent(forKey: .cacheReadTokens)
        cacheCreationTokens = try v.flexibleIntIfPresent(forKey: .cacheCreationTokens)
        inputTokens = try v.flexibleIntIfPresent(forKey: .inputTokens)
    }
}

public struct CurrentUsageItem: Codable, Equatable, Sendable {
    public let key: String?
    public let label: String?
    public let tokens: Int?
    public let requests: Int?
    public let cost: Double?
    public let share: Double?

    enum CodingKeys: String, CodingKey {
        case key, label, tokens, requests, cost, share
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        key = try v.decodeIfPresent(String.self, forKey: .key)
        label = try v.decodeIfPresent(String.self, forKey: .label)
        tokens = try v.flexibleIntIfPresent(forKey: .tokens)
        requests = try v.flexibleIntIfPresent(forKey: .requests)
        cost = try v.flexibleDoubleIfPresent(forKey: .cost)
        share = try v.flexibleDoubleIfPresent(forKey: .share)
    }
}

public struct RealtimeCurrentUsage: Codable, Equatable, Sendable {
    public let models: [CurrentUsageItem]
    public let apiKeys: [CurrentUsageItem]
    public let authFiles: [CurrentUsageItem]
    public let aiProviders: [CurrentUsageItem]

    enum CodingKeys: String, CodingKey {
        case models, apiKeys = "api_keys", authFiles = "auth_files"
        case aiProviders = "ai_providers"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        models = try v.decodeIfPresent([CurrentUsageItem].self, forKey: .models) ?? []
        apiKeys = try v.decodeIfPresent([CurrentUsageItem].self, forKey: .apiKeys) ?? []
        authFiles = try v.decodeIfPresent([CurrentUsageItem].self, forKey: .authFiles) ?? []
        aiProviders = try v.decodeIfPresent([CurrentUsageItem].self, forKey: .aiProviders) ?? []
    }
}

public struct ResponseAveragePoint: Codable, Equatable, Sendable {
    public let bucket: String?
    public let avgMS: Double?

    enum CodingKeys: String, CodingKey {
        case bucket, avgMS = "avg_ms"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        bucket = try v.decodeIfPresent(String.self, forKey: .bucket)
        avgMS = try v.flexibleDoubleIfPresent(forKey: .avgMS)
    }
}

public struct ResponseParticle: Codable, Equatable, Sendable {
    public let bucket: String?
    public let timestamp: String?
    public let ms: Int?
    public let count: Int?

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        bucket = try v.decodeIfPresent(String.self, forKey: .bucket)
        timestamp = try v.decodeIfPresent(String.self, forKey: .timestamp)
        ms = try v.flexibleIntIfPresent(forKey: .ms)
        count = try v.flexibleIntIfPresent(forKey: .count)
    }
}

public struct DistributionData: Codable, Equatable, Sendable {
    public let averageLine: [ResponseAveragePoint]
    public let particles: [ResponseParticle]
    public let totalParticles: Int?
    public let sampled: Bool?
    public let maxParticles: Int?

    enum CodingKeys: String, CodingKey {
        case particles, sampled
        case averageLine = "average_line", totalParticles = "total_particles"
        case maxParticles = "max_particles"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        averageLine = try v.decodeIfPresent([ResponseAveragePoint].self, forKey: .averageLine) ?? []
        particles = try v.decodeIfPresent([ResponseParticle].self, forKey: .particles) ?? []
        totalParticles = try v.flexibleIntIfPresent(forKey: .totalParticles)
        sampled = try v.flexibleBoolIfPresent(forKey: .sampled)
        maxParticles = try v.flexibleIntIfPresent(forKey: .maxParticles)
    }
}

public struct ResponseDistribution: Codable, Equatable, Sendable {
    public let ttft: DistributionData?
    public let latency: DistributionData?
}

public struct RealtimeOverviewResponse: Codable, Equatable, Sendable {
    public let window: String?
    public let timezone: String?
    public let bucketSeconds: Int?
    public let windowStart: String?
    public let windowEnd: String?
    public let tokenVelocity: [TokenVelocityPoint]
    public let responseLevel: [ResponseLevelPoint]
    public let responseDistribution: ResponseDistribution?
    public let currentUsage: RealtimeCurrentUsage?
    public let requestLevel: [RequestLevelPoint]
    public let cacheLevel: [CacheLevelPoint]

    enum CodingKeys: String, CodingKey {
        case window, timezone
        case bucketSeconds = "bucket_seconds", windowStart = "window_start"
        case windowEnd = "window_end", tokenVelocity = "token_velocity"
        case responseLevel = "response_level", responseDistribution = "response_distribution"
        case currentUsage = "current_usage", requestLevel = "request_level"
        case cacheLevel = "cache_level"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        window = try v.decodeIfPresent(String.self, forKey: .window)
        timezone = try v.decodeIfPresent(String.self, forKey: .timezone)
        bucketSeconds = try v.flexibleIntIfPresent(forKey: .bucketSeconds)
        windowStart = try v.decodeIfPresent(String.self, forKey: .windowStart)
        windowEnd = try v.decodeIfPresent(String.self, forKey: .windowEnd)
        tokenVelocity = try v.decodeIfPresent([TokenVelocityPoint].self, forKey: .tokenVelocity) ?? []
        responseLevel = try v.decodeIfPresent([ResponseLevelPoint].self, forKey: .responseLevel) ?? []
        responseDistribution = try v.decodeIfPresent(ResponseDistribution.self, forKey: .responseDistribution)
        currentUsage = try v.decodeIfPresent(RealtimeCurrentUsage.self, forKey: .currentUsage)
        requestLevel = try v.decodeIfPresent([RequestLevelPoint].self, forKey: .requestLevel) ?? []
        cacheLevel = try v.decodeIfPresent([CacheLevelPoint].self, forKey: .cacheLevel) ?? []
    }
}
