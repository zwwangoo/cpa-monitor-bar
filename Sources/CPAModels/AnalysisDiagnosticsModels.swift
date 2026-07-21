import Foundation

public struct LatencyPoint: Codable, Equatable, Sendable {
    public let ttftMS: Int?
    public let latencyMS: Int?

    enum CodingKeys: String, CodingKey {
        case ttftMS = "ttft_ms", latencyMS = "latency_ms"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        ttftMS = try v.flexibleIntIfPresent(forKey: .ttftMS)
        latencyMS = try v.flexibleIntIfPresent(forKey: .latencyMS)
    }
}

public struct LatencyDensityCell: Codable, Equatable, Sendable {
    public let ttftMinMS: Int?
    public let ttftMaxMS: Int?
    public let latencyMinMS: Int?
    public let latencyMaxMS: Int?
    public let count: Int?
    public let intensity: Double?

    enum CodingKeys: String, CodingKey {
        case ttftMinMS = "ttft_min_ms", ttftMaxMS = "ttft_max_ms"
        case latencyMinMS = "latency_min_ms", latencyMaxMS = "latency_max_ms"
        case count, intensity
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        ttftMinMS = try v.flexibleIntIfPresent(forKey: .ttftMinMS)
        ttftMaxMS = try v.flexibleIntIfPresent(forKey: .ttftMaxMS)
        latencyMinMS = try v.flexibleIntIfPresent(forKey: .latencyMinMS)
        latencyMaxMS = try v.flexibleIntIfPresent(forKey: .latencyMaxMS)
        count = try v.flexibleIntIfPresent(forKey: .count)
        intensity = try v.flexibleDoubleIfPresent(forKey: .intensity)
    }
}

public struct LatencyDiagnostics: Codable, Equatable, Sendable {
    public let points: [LatencyPoint]?
    public let density: [LatencyDensityCell]?
    public let totalPoints: Int?
    public let sampled: Bool?
    public let p95TTFTMS: Double?
    public let p95LatencyMS: Double?
    public let maxTTFTMS: Double?
    public let maxLatencyMS: Double?

    enum CodingKeys: String, CodingKey {
        case points, density, sampled, totalPoints = "total_points"
        case p95TTFTMS = "p95_ttft_ms", p95LatencyMS = "p95_latency_ms"
        case maxTTFTMS = "max_ttft_ms", maxLatencyMS = "max_latency_ms"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        points = try v.decodeIfPresent([LatencyPoint].self, forKey: .points)
        density = try v.decodeIfPresent([LatencyDensityCell].self, forKey: .density)
        totalPoints = try v.flexibleIntIfPresent(forKey: .totalPoints)
        sampled = try v.flexibleBoolIfPresent(forKey: .sampled)
        p95TTFTMS = try v.flexibleDoubleIfPresent(forKey: .p95TTFTMS)
        p95LatencyMS = try v.flexibleDoubleIfPresent(forKey: .p95LatencyMS)
        maxTTFTMS = try v.flexibleDoubleIfPresent(forKey: .maxTTFTMS)
        maxLatencyMS = try v.flexibleDoubleIfPresent(forKey: .maxLatencyMS)
    }
}
