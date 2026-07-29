import Foundation
import CPAModels

private let dashboardFractionalDateFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

private let dashboardDateFormatter = ISO8601DateFormatter()

func compactInteger(_ value: Int?) -> String {
    value?.formatted(.number.notation(.compactName)) ?? "—"
}

func formattedInteger(_ value: Int?) -> String {
    value?.formatted() ?? "—"
}

func formattedPercent(_ value: Double?, fractionDigits: Int = 1) -> String {
    guard let value, value.isFinite else { return "—" }
    return String(format: "%.\(max(fractionDigits, 0))f%%", value)
}

func formattedCurrency(_ value: Double?) -> String {
    guard let value, value.isFinite else { return "—" }
    return value >= 1 ? String(format: "$%.2f", value) : String(format: "$%.4f", value)
}

func quotaRemainingPercent(_ row: UsageQuotaRow) -> Double? {
    let value: Double?
    if let fraction = row.remainingFraction {
        value = fraction * 100
    } else if let usedPercent = row.usedPercent {
        value = 100 - usedPercent
    } else if let remaining = row.remaining, let limit = row.limit, limit > 0 {
        value = remaining / limit * 100
    } else if let used = row.used, let limit = row.limit, limit > 0 {
        value = 100 - used / limit * 100
    } else if row.limitReached == true {
        value = 0
    } else {
        value = nil
    }
    return value.map { min(max($0, 0), 100) }
}

func dashboardShortTime(_ rawValue: String?) -> String {
    guard let rawValue else { return "—" }
    let date = dashboardFractionalDateFormatter.date(from: rawValue)
        ?? dashboardDateFormatter.date(from: rawValue)
    return date?.formatted(date: .omitted, time: .shortened) ?? rawValue
}

func compactLatency(_ milliseconds: Int?) -> String {
    guard let milliseconds else { return "—" }
    guard milliseconds.magnitude >= 1_000 else { return "\(milliseconds)ms" }
    return String(format: "%.1fs", Double(milliseconds) / 1_000)
}

func credentialRequestCount(success: Int?, failure: Int?) -> Double {
    max(Double(success ?? 0), 0) + max(Double(failure ?? 0), 0)
}

func eventLatencyText(ttftMS: Int?, latencyMS: Int?) -> String {
    "\(compactLatency(ttftMS))/\(compactLatency(latencyMS))"
}

func displayAPIKey(_ rawValue: String?) -> String {
    guard let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty else { return "—" }
    if value.contains("*") || value.contains("•") || value.count <= 8 {
        return value
    }
    return "\(value.prefix(4))••••\(value.suffix(4))"
}

func eventCountSummary(totalCount: Int?) -> String {
    "共 \((totalCount ?? 0).formatted()) 条"
}

func preferredText(_ values: String?...) -> String {
    values.compactMap { value in
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return value
    }.first ?? "未知"
}

func visibleAuthFiles(_ identities: [UsageIdentity]) -> [UsageIdentity] {
    identities.filter { $0.disabled != true }
}

func authAccountName(_ identity: UsageIdentity) -> String {
    preferredText(identity.displayName, identity.name, "未知账号")
}
