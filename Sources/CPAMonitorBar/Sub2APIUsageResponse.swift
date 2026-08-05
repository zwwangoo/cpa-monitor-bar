import Foundation

struct Sub2APIUsageResponse: Decodable {
    let mode: String
    let status: String?
    let planName: String?
    let unit: String?
    let balance: Double?
    let remaining: Double?
    let expiresAt: String?
    let quota: Sub2APIQuota?
    let subscription: Sub2APISubscription?
    let rateLimits: [Sub2APIRateLimit]?

    enum CodingKeys: String, CodingKey {
        case mode, status, unit, balance, remaining, quota, subscription
        case planName
        case expiresAt = "expires_at"
        case rateLimits = "rate_limits"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        mode = try values.decode(String.self, forKey: .mode)
        status = try values.decodeIfPresent(String.self, forKey: .status)
        planName = try values.decodeIfPresent(String.self, forKey: .planName)
        unit = try values.decodeIfPresent(String.self, forKey: .unit)
        balance = try values.finiteDoubleIfPresent(forKey: .balance)
        remaining = try values.finiteDoubleIfPresent(forKey: .remaining)
        expiresAt = try values.decodeIfPresent(String.self, forKey: .expiresAt)
        quota = try values.decodeIfPresent(Sub2APIQuota.self, forKey: .quota)
        subscription = try values.decodeIfPresent(
            Sub2APISubscription.self,
            forKey: .subscription
        )
        rateLimits = try values.decodeIfPresent(
            [Sub2APIRateLimit].self,
            forKey: .rateLimits
        )
    }
}

struct Sub2APIQuota: Decodable {
    let used: Double?
    let limit: Double?
    let remaining: Double?

    enum CodingKeys: CodingKey { case used, limit, remaining }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        used = try values.finiteDoubleIfPresent(forKey: .used)
        limit = try values.finiteDoubleIfPresent(forKey: .limit)
        remaining = try values.finiteDoubleIfPresent(forKey: .remaining)
    }
}

struct Sub2APISubscription: Decodable {
    let dailyUsage: Double?
    let dailyLimit: Double?
    let weeklyUsage: Double?
    let weeklyLimit: Double?
    let monthlyUsage: Double?
    let monthlyLimit: Double?
    let expiresAt: String?

    var windows: [Sub2APIUsageWindow] {
        [
            window(id: "1d", usage: dailyUsage, limit: dailyLimit),
            window(id: "7d", usage: weeklyUsage, limit: weeklyLimit),
            window(id: "30d", usage: monthlyUsage, limit: monthlyLimit),
        ].compactMap { $0 }
    }

    enum CodingKeys: String, CodingKey {
        case dailyUsage = "daily_usage_usd"
        case dailyLimit = "daily_limit_usd"
        case weeklyUsage = "weekly_usage_usd"
        case weeklyLimit = "weekly_limit_usd"
        case monthlyUsage = "monthly_usage_usd"
        case monthlyLimit = "monthly_limit_usd"
        case expiresAt = "expires_at"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        dailyUsage = try values.finiteDoubleIfPresent(forKey: .dailyUsage)
        dailyLimit = try values.finiteDoubleIfPresent(forKey: .dailyLimit)
        weeklyUsage = try values.finiteDoubleIfPresent(forKey: .weeklyUsage)
        weeklyLimit = try values.finiteDoubleIfPresent(forKey: .weeklyLimit)
        monthlyUsage = try values.finiteDoubleIfPresent(forKey: .monthlyUsage)
        monthlyLimit = try values.finiteDoubleIfPresent(forKey: .monthlyLimit)
        expiresAt = try values.decodeIfPresent(String.self, forKey: .expiresAt)
    }

    private func window(
        id: String,
        usage: Double?,
        limit: Double?
    ) -> Sub2APIUsageWindow? {
        guard let limit else { return nil }
        return Sub2APIUsageWindow(
            id: id,
            used: usage ?? 0,
            limit: limit,
            resetsAt: nil
        )
    }
}

struct Sub2APIRateLimit: Decodable {
    let window: String
    let used: Double
    let limit: Double
    let resetAt: String?

    enum CodingKeys: String, CodingKey {
        case window, used, limit
        case resetAt = "reset_at"
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        window = try values.decode(String.self, forKey: .window)
        used = try values.finiteDouble(forKey: .used)
        limit = try values.finiteDouble(forKey: .limit)
        resetAt = try values.decodeIfPresent(String.self, forKey: .resetAt)
    }
}

struct Sub2APIUsageWindow {
    let id: String
    let used: Double
    let limit: Double
    let resetsAt: String?
}

private extension KeyedDecodingContainer {
    func finiteDouble(forKey key: Key) throws -> Double {
        guard let value = try finiteDoubleIfPresent(forKey: key) else {
            throw DecodingError.valueNotFound(
                Double.self,
                .init(
                    codingPath: codingPath + [key],
                    debugDescription: "Missing number"
                )
            )
        }
        return value
    }

    func finiteDoubleIfPresent(forKey key: Key) throws -> Double? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        let value: Double?
        if let number = try? decode(Double.self, forKey: key) {
            value = number
        } else if let integer = try? decode(Int.self, forKey: key) {
            value = Double(integer)
        } else if let text = try? decode(String.self, forKey: key) {
            value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            value = nil
        }
        guard let value, value.isFinite else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: self,
                debugDescription: "Expected a finite number"
            )
        }
        return value
    }
}
