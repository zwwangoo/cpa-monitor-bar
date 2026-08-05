import Foundation
import SwiftUI

enum ProviderUsageTone: Equatable {
    case normal
    case warning
    case critical
}

struct ProviderUsageRowPresentation: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let fractionUsed: Double?
    let tone: ProviderUsageTone
    let resetText: String?
}

struct ProviderUsagePresentation: Equatable {
    let modeTitle: String
    let rows: [ProviderUsageRowPresentation]
    let statusMessage: String?
    let updatedText: String?
    let expiryText: String?

    init(state: ProviderUsageState) {
        guard let snapshot = state.snapshot else {
            modeTitle = ""
            rows = []
            statusMessage = state.isLoading
                ? "正在读取用量…"
                : state.errorMessage
            updatedText = nil
            expiryText = nil
            return
        }

        let content = Self.content(for: snapshot)
        modeTitle = content.title
        rows = content.rows
        if state.isLoading {
            statusMessage = "正在更新用量…"
        } else if state.errorMessage != nil {
            statusMessage = "用量暂不可用"
        } else {
            statusMessage = nil
        }
        updatedText = "更新于 " + snapshot.fetchedAt.formatted(
            date: .omitted,
            time: .shortened
        )
        expiryText = snapshot.expiresAt.map {
            "到期 " + $0.formatted(date: .abbreviated, time: .omitted)
        }
    }

    private static func content(
        for snapshot: ProviderUsageSnapshot
    ) -> (title: String, rows: [ProviderUsageRowPresentation]) {
        switch snapshot.mode {
        case let .wallet(balance):
            return (
                "钱包",
                [amountRow(
                    id: "balance",
                    label: "余额",
                    amount: balance,
                    currency: snapshot.currency
                )]
            )
        case let .subscription(plan, remaining, windows):
            var rows: [ProviderUsageRowPresentation] = []
            if let remaining {
                rows.append(
                    amountRow(
                        id: "remaining",
                        label: "剩余额度",
                        amount: remaining,
                        currency: snapshot.currency
                    )
                )
            }
            rows.append(contentsOf: windowRows(
                windows,
                currency: snapshot.currency,
                subscription: true
            ))
            return (plan, rows)
        case let .keyQuota(status, used, limit, remaining, windows):
            var rows: [ProviderUsageRowPresentation] = []
            if remaining != nil || limit != nil || used != nil {
                rows.append(
                    totalQuotaRow(
                        used: used,
                        limit: limit,
                        remaining: remaining,
                        currency: snapshot.currency
                    )
                )
            }
            rows.append(contentsOf: windowRows(
                windows,
                currency: snapshot.currency,
                subscription: false
            ))
            let normalizedStatus = status?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? ""
            return (
                normalizedStatus.isEmpty
                    ? "Key 额度"
                    : "Key 额度 · \(normalizedStatus)",
                rows
            )
        }
    }

    private static func amountRow(
        id: String,
        label: String,
        amount: Double,
        currency: String
    ) -> ProviderUsageRowPresentation {
        ProviderUsageRowPresentation(
            id: id,
            label: label,
            value: providerUsageCurrency(amount, currency: currency),
            fractionUsed: nil,
            tone: .normal,
            resetText: nil
        )
    }

    private static func totalQuotaRow(
        used: Double?,
        limit: Double?,
        remaining: Double?,
        currency: String
    ) -> ProviderUsageRowPresentation {
        let normalizedLimit = finiteNonnegative(limit)
        let normalizedUsed = finiteNonnegative(used)
        let normalizedRemaining = finiteNonnegative(remaining)
            ?? normalizedLimit.flatMap { limit in
                normalizedUsed.map { max(limit - $0, 0) }
            }
        let value: String
        if let remaining = normalizedRemaining, let limit = normalizedLimit {
            value = "\(providerUsageCurrency(remaining, currency: currency)) / "
                + providerUsageCurrency(limit, currency: currency)
        } else if let remaining = normalizedRemaining {
            value = providerUsageCurrency(remaining, currency: currency)
        } else if let used = normalizedUsed, let limit = normalizedLimit {
            value = "已用 \(providerUsageCurrency(used, currency: currency)) / "
                + providerUsageCurrency(limit, currency: currency)
        } else {
            value = "—"
        }
        let fraction = usageFraction(used: normalizedUsed, limit: normalizedLimit)
        return ProviderUsageRowPresentation(
            id: "total",
            label: "剩余额度",
            value: value,
            fractionUsed: fraction,
            tone: providerUsageTone(fractionUsed: fraction),
            resetText: nil
        )
    }

    private static func windowRows(
        _ windows: [ProviderUsageWindow],
        currency: String,
        subscription: Bool
    ) -> [ProviderUsageRowPresentation] {
        windows.enumerated().compactMap { index, window in
            guard window.limit.isFinite, window.limit > 0,
                  window.used.isFinite else { return nil }
            let used = max(window.used, 0)
            let fraction = min(max(used / window.limit, 0), 1)
            let percent = Int((fraction * 100).rounded())
            return ProviderUsageRowPresentation(
                id: "window-\(index)-\(window.id)",
                label: windowLabel(window.id, subscription: subscription),
                value: "\(providerUsageCurrency(used, currency: currency)) / "
                    + "\(providerUsageCurrency(window.limit, currency: currency))"
                    + " · \(percent)%",
                fractionUsed: fraction,
                tone: providerUsageTone(fractionUsed: fraction),
                resetText: window.resetsAt.map {
                    "重置 " + $0.formatted(date: .omitted, time: .shortened)
                }
            )
        }
    }

    private static func windowLabel(
        _ id: String,
        subscription: Bool
    ) -> String {
        switch id.lowercased() {
        case "5h": "5 小时"
        case "1d": subscription ? "日额度" : "1 天"
        case "7d": subscription ? "周额度" : "7 天"
        case "30d": subscription ? "月额度" : "30 天"
        default: id
        }
    }

    private static func finiteNonnegative(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        return max(value, 0)
    }

    private static func usageFraction(
        used: Double?,
        limit: Double?
    ) -> Double? {
        guard let used, let limit, limit > 0 else { return nil }
        return min(max(used / limit, 0), 1)
    }
}

func providerUsageTone(fractionUsed: Double?) -> ProviderUsageTone {
    guard let fractionUsed else { return .normal }
    if fractionUsed >= 0.9 { return .critical }
    if fractionUsed >= 0.7 { return .warning }
    return .normal
}

private func providerUsageCurrency(
    _ value: Double,
    currency: String
) -> String {
    let normalizedValue = value.isFinite ? max(value, 0) : 0
    let normalizedCurrency = currency.uppercased()
    switch normalizedCurrency {
    case "USD":
        return String(
            format: "$%.2f",
            locale: Locale(identifier: "en_US_POSIX"),
            normalizedValue
        )
    case "CNY", "RMB":
        return String(
            format: "¥%.2f",
            locale: Locale(identifier: "en_US_POSIX"),
            normalizedValue
        )
    default:
        return String(
            format: "%.2f %@",
            locale: Locale(identifier: "en_US_POSIX"),
            normalizedValue,
            normalizedCurrency
        )
    }
}

struct ProviderUsageSummaryView: View {
    let state: ProviderUsageState

    private var presentation: ProviderUsagePresentation {
        ProviderUsagePresentation(state: state)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !presentation.modeTitle.isEmpty {
                HStack(spacing: 8) {
                    Text(presentation.modeTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Color.accentColor.opacity(0.1),
                            in: Capsule()
                        )
                    Spacer()
                    if let updatedText = presentation.updatedText {
                        Text(updatedText)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            ForEach(presentation.rows) { row in
                usageRow(row)
            }

            HStack {
                if let statusMessage = presentation.statusMessage {
                    Text(statusMessage)
                        .foregroundStyle(
                            state.snapshot == nil
                                ? Color.secondary
                                : Color.orange
                        )
                }
                Spacer()
                if let expiryText = presentation.expiryText {
                    Text(expiryText).foregroundStyle(.secondary)
                }
            }
            .font(.caption2)
            .frame(minHeight: 14)
        }
        .padding(10)
        .background(
            Color.secondary.opacity(0.055),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
    }

    private func usageRow(
        _ row: ProviderUsageRowPresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(row.label).foregroundStyle(.secondary)
                Spacer()
                Text(row.value)
                    .monospacedDigit()
                    .foregroundStyle(color(for: row.tone))
                if let resetText = row.resetText {
                    Text(resetText).foregroundStyle(.tertiary)
                }
            }
            .font(.caption)
            if let fraction = row.fractionUsed {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.12))
                        Capsule()
                            .fill(color(for: row.tone))
                            .frame(width: proxy.size.width * fraction)
                    }
                }
                .frame(height: 4)
            }
        }
    }

    private func color(for tone: ProviderUsageTone) -> Color {
        switch tone {
        case .normal: Color.accentColor
        case .warning: .orange
        case .critical: .red
        }
    }
}
