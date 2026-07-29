import Foundation

public struct UsageCredentialHealthBucket: Decodable, Sendable {
    public let startTime: String?
    public let endTime: String?
    public let success: Int?
    public let failure: Int?

    enum CodingKeys: String, CodingKey {
        case success, failure
        case startTime = "start_time"
        case endTime = "end_time"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        startTime = try values.decodeIfPresent(String.self, forKey: .startTime)
        endTime = try values.decodeIfPresent(String.self, forKey: .endTime)
        success = try values.flexibleIntIfPresent(forKey: .success)
        failure = try values.flexibleIntIfPresent(forKey: .failure)
    }
}

public struct UsageCredentialHealth: Decodable, Sendable {
    public let totalSuccess: Int?
    public let totalFailure: Int?
    public let successRate: Double?
    public let buckets: [UsageCredentialHealthBucket]

    enum CodingKeys: String, CodingKey {
        case buckets
        case totalSuccess = "total_success"
        case totalFailure = "total_failure"
        case successRate = "success_rate"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        totalSuccess = try values.flexibleIntIfPresent(forKey: .totalSuccess)
        totalFailure = try values.flexibleIntIfPresent(forKey: .totalFailure)
        successRate = try values.flexibleDoubleIfPresent(forKey: .successRate)
        buckets = try values.decodeIfPresent(
            [UsageCredentialHealthBucket].self,
            forKey: .buckets
        ) ?? []
    }
}

public struct UsageIdentity: Decodable, Identifiable, Sendable {
    public let id: String
    public let name: String?
    public let displayName: String?
    public let identity: String?
    public let type: String?
    public let provider: String?
    public let disabled: Bool?
    public let credentialHealth: UsageCredentialHealth?

    enum CodingKeys: String, CodingKey {
        case id, name, displayName, identity, type, provider, disabled
        case credentialHealth = "credential_health"
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(String.self, forKey: .id) ?? "unknown"
        name = try values.decodeIfPresent(String.self, forKey: .name)
        displayName = try values.decodeIfPresent(String.self, forKey: .displayName)
        identity = try values.decodeIfPresent(String.self, forKey: .identity)
        type = try values.decodeIfPresent(String.self, forKey: .type)
        provider = try values.decodeIfPresent(String.self, forKey: .provider)
        disabled = try values.flexibleBoolIfPresent(forKey: .disabled)
        credentialHealth = try values.decodeIfPresent(
            UsageCredentialHealth.self,
            forKey: .credentialHealth
        )
    }
}

public struct UsageIdentitiesPageResponse: Decodable, Sendable {
    public let identities: [UsageIdentity]

    enum CodingKeys: CodingKey {
        case identities
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        identities = try values.decodeIfPresent([UsageIdentity].self, forKey: .identities) ?? []
    }
}

public struct UsageQuotaRow: Decodable, Sendable {
    public let key: String
    public let label: String?
    public let used: Double?
    public let limit: Double?
    public let remaining: Double?
    public let usedPercent: Double?
    public let remainingFraction: Double?
    public let limitReached: Bool?
    public let resetAt: String?

    enum CodingKeys: CodingKey {
        case key, label, used, limit, remaining
        case usedPercent, remainingFraction, limitReached, resetAt
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        key = try values.decodeIfPresent(String.self, forKey: .key) ?? "unknown"
        label = try values.decodeIfPresent(String.self, forKey: .label)
        used = try values.flexibleDoubleIfPresent(forKey: .used)
        limit = try values.flexibleDoubleIfPresent(forKey: .limit)
        remaining = try values.flexibleDoubleIfPresent(forKey: .remaining)
        usedPercent = try values.flexibleDoubleIfPresent(forKey: .usedPercent)
        remainingFraction = try values.flexibleDoubleIfPresent(forKey: .remainingFraction)
        limitReached = try values.flexibleBoolIfPresent(forKey: .limitReached)
        resetAt = try values.decodeIfPresent(String.self, forKey: .resetAt)
    }
}

public struct UsageQuotaCheckResponse: Decodable, Sendable {
    public let quota: [UsageQuotaRow]

    enum CodingKeys: CodingKey {
        case quota
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        quota = try values.decodeIfPresent([UsageQuotaRow].self, forKey: .quota) ?? []
    }
}

public struct UsageQuotaCacheItem: Decodable, Sendable {
    public let authIndex: String?
    public let quota: UsageQuotaCheckResponse?
    public let error: String?

    enum CodingKeys: String, CodingKey {
        case quota, error
        case authIndex = "auth_index"
    }
}

public struct UsageQuotaCacheResponse: Decodable, Sendable {
    public let items: [UsageQuotaCacheItem]

    enum CodingKeys: CodingKey {
        case items
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        items = try values.decodeIfPresent([UsageQuotaCacheItem].self, forKey: .items) ?? []
    }
}

public struct UsageQuotaRefreshTaskReference: Decodable, Sendable {
    public let authIndex: String
}

public struct UsageQuotaRefreshRejection: Decodable, Sendable {
    public let authIndex: String
    public let error: String?
}

public struct UsageQuotaRefreshBatchResponse: Decodable, Sendable {
    public let tasks: [UsageQuotaRefreshTaskReference]
    public let rejected: [UsageQuotaRefreshRejection]

    enum CodingKeys: CodingKey {
        case tasks, rejected
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        tasks = try values.decodeIfPresent(
            [UsageQuotaRefreshTaskReference].self,
            forKey: .tasks
        ) ?? []
        rejected = try values.decodeIfPresent(
            [UsageQuotaRefreshRejection].self,
            forKey: .rejected
        ) ?? []
    }
}

public struct UsageQuotaRefreshTaskResponse: Decodable, Sendable {
    public let status: String

    enum CodingKeys: CodingKey {
        case status
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        status = try values.decodeIfPresent(String.self, forKey: .status) ?? "unknown"
    }
}
