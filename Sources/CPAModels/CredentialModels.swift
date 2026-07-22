import Foundation

public struct UsageCredentialHealthBucket: Codable, Equatable, Identifiable, Sendable {
    public let startTime: String?
    public let endTime: String?
    public let success: Int?
    public let failure: Int?
    public let rate: Double?

    public var id: String {
        startTime ?? endTime ?? "\(success ?? 0)-\(failure ?? 0)"
    }

    enum CodingKeys: String, CodingKey {
        case success, failure, rate
        case startTime = "start_time", endTime = "end_time"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        startTime = try v.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try v.decodeIfPresent(String.self, forKey: .endTime)
        success = try v.flexibleIntIfPresent(forKey: .success)
        failure = try v.flexibleIntIfPresent(forKey: .failure)
        rate = try v.flexibleDoubleIfPresent(forKey: .rate)
    }
}

public struct UsageCredentialHealth: Codable, Equatable, Sendable {
    public let windowSeconds: Int?
    public let totalSuccess: Int?
    public let totalFailure: Int?
    public let successRate: Double?
    public let buckets: [UsageCredentialHealthBucket]

    enum CodingKeys: String, CodingKey {
        case buckets
        case windowSeconds = "window_seconds", totalSuccess = "total_success"
        case totalFailure = "total_failure", successRate = "success_rate"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        windowSeconds = try v.flexibleIntIfPresent(forKey: .windowSeconds)
        totalSuccess = try v.flexibleIntIfPresent(forKey: .totalSuccess)
        totalFailure = try v.flexibleIntIfPresent(forKey: .totalFailure)
        successRate = try v.flexibleDoubleIfPresent(forKey: .successRate)
        buckets = try v.decodeIfPresent([UsageCredentialHealthBucket].self, forKey: .buckets) ?? []
    }
}

public struct UsageIdentity: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let name: String?
    public let displayName: String?
    public let authType: Int?
    public let identity: String?
    public let type: String?
    public let provider: String?
    public let fileName: String?
    public let disabled: Bool?
    public let credentialHealth: UsageCredentialHealth?

    enum CodingKeys: String, CodingKey {
        case id, name, displayName, identity, type, provider, disabled
        case authType = "auth_type", fileName = "file_name"
        case credentialHealth = "credential_health"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        id = try v.decodeIfPresent(String.self, forKey: .id) ?? "unknown"
        name = try v.decodeIfPresent(String.self, forKey: .name)
        displayName = try v.decodeIfPresent(String.self, forKey: .displayName)
        authType = try v.flexibleIntIfPresent(forKey: .authType)
        identity = try v.decodeIfPresent(String.self, forKey: .identity)
        type = try v.decodeIfPresent(String.self, forKey: .type)
        provider = try v.decodeIfPresent(String.self, forKey: .provider)
        fileName = try v.decodeIfPresent(String.self, forKey: .fileName)
        disabled = try v.flexibleBoolIfPresent(forKey: .disabled)
        credentialHealth = try v.decodeIfPresent(UsageCredentialHealth.self, forKey: .credentialHealth)
    }
}

public struct UsageIdentitiesPageResponse: Codable, Equatable, Sendable {
    public let identities: [UsageIdentity]
    public let totalCount: Int?
    public let page: Int?
    public let pageSize: Int?
    public let totalPages: Int?

    enum CodingKeys: String, CodingKey {
        case identities, page
        case totalCount = "total_count", pageSize = "page_size", totalPages = "total_pages"
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        identities = try v.decodeIfPresent([UsageIdentity].self, forKey: .identities) ?? []
        totalCount = try v.flexibleIntIfPresent(forKey: .totalCount)
        page = try v.flexibleIntIfPresent(forKey: .page)
        pageSize = try v.flexibleIntIfPresent(forKey: .pageSize)
        totalPages = try v.flexibleIntIfPresent(forKey: .totalPages)
    }
}

public struct UsageQuotaWindow: Codable, Equatable, Sendable {
    public let seconds: Int?

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        seconds = try v.flexibleIntIfPresent(forKey: .seconds)
    }
}

public struct UsageQuotaRow: Codable, Equatable, Identifiable, Sendable {
    public let key: String
    public let label: String?
    public let used: Double?
    public let limit: Double?
    public let remaining: Double?
    public let usedPercent: Double?
    public let remainingFraction: Double?
    public let limitReached: Bool?
    public let window: UsageQuotaWindow?
    public let resetAt: String?

    public var id: String { key }

    enum CodingKeys: String, CodingKey {
        case key, label, used, limit, remaining, window
        case usedPercent, remainingFraction, limitReached, resetAt
    }

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        key = try v.decodeIfPresent(String.self, forKey: .key) ?? "unknown"
        label = try v.decodeIfPresent(String.self, forKey: .label)
        used = try v.flexibleDoubleIfPresent(forKey: .used)
        limit = try v.flexibleDoubleIfPresent(forKey: .limit)
        remaining = try v.flexibleDoubleIfPresent(forKey: .remaining)
        usedPercent = try v.flexibleDoubleIfPresent(forKey: .usedPercent)
        remainingFraction = try v.flexibleDoubleIfPresent(forKey: .remainingFraction)
        limitReached = try v.flexibleBoolIfPresent(forKey: .limitReached)
        window = try v.decodeIfPresent(UsageQuotaWindow.self, forKey: .window)
        resetAt = try v.decodeIfPresent(String.self, forKey: .resetAt)
    }
}

public struct UsageQuotaCheckResponse: Codable, Equatable, Sendable {
    public let id: String?
    public let quota: [UsageQuotaRow]

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        id = try v.decodeIfPresent(String.self, forKey: .id)
        quota = try v.decodeIfPresent([UsageQuotaRow].self, forKey: .quota) ?? []
    }
}

public struct UsageQuotaCacheItem: Codable, Equatable, Sendable {
    public let authIndex: String?
    public let fileName: String?
    public let status: String?
    public let quota: UsageQuotaCheckResponse?
    public let error: String?

    enum CodingKeys: String, CodingKey {
        case status, quota, error
        case authIndex = "auth_index", fileName = "file_name"
    }
}

public struct UsageQuotaCacheResponse: Codable, Equatable, Sendable {
    public let items: [UsageQuotaCacheItem]

    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        items = try v.decodeIfPresent([UsageQuotaCacheItem].self, forKey: .items) ?? []
    }
}

public struct UsageQuotaRefreshTaskReference: Codable, Equatable, Sendable {
    public let authIndex: String
}

public struct UsageQuotaRefreshRejection: Codable, Equatable, Sendable {
    public let authIndex: String
    public let error: String?
}

public struct UsageQuotaRefreshBatchResponse: Codable, Equatable, Sendable {
    public let tasks: [UsageQuotaRefreshTaskReference]
    public let rejected: [UsageQuotaRefreshRejection]

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try values.decodeIfPresent([UsageQuotaRefreshTaskReference].self, forKey: .tasks) ?? []
        rejected = try values.decodeIfPresent([UsageQuotaRefreshRejection].self, forKey: .rejected) ?? []
    }
}

public struct UsageQuotaRefreshTaskResponse: Codable, Equatable, Sendable {
    public let authIndex: String?
    public let status: String
    public let quota: UsageQuotaCheckResponse?
    public let error: String?

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        authIndex = try values.decodeIfPresent(String.self, forKey: .authIndex)
        status = try values.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
        quota = try values.decodeIfPresent(UsageQuotaCheckResponse.self, forKey: .quota)
        error = try values.decodeIfPresent(String.self, forKey: .error)
    }
}
