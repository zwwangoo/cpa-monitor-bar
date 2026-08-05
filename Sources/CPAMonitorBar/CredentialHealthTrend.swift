import SwiftUI
import CPAModels

private let criticalSuccessRateThreshold = 50.0
private let criticalConsecutiveFailureCount = 3
private let minimumTrendBarHeight: CGFloat = 4
private let maximumTrendBarHeight: CGFloat = 24

struct CredentialHealthTrend: View {
    let health: UsageCredentialHealth?

    var body: some View {
        if let health, !health.buckets.isEmpty {
            let tones = credentialHealthTones(health)
            let maximumRequestCount = health.buckets.map {
                credentialRequestCount(success: $0.success, failure: $0.failure)
            }.max() ?? 0
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("成功率 \(formattedPercent(health.successRate))")
                    Spacer()
                    Text("失败 \(health.totalFailure ?? 0)")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(health.buckets.enumerated()), id: \.offset) { index, bucket in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(color(for: tones[index]))
                            .frame(maxWidth: .infinity)
                            .frame(height: barHeight(
                                bucket,
                                maximumRequestCount: maximumRequestCount
                            ))
                            .help(bucketHelp(bucket))
                    }
                }
                .frame(height: maximumTrendBarHeight, alignment: .bottom)
                Text("5 小时前")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .trailing) { Text("现在") }
            }
        } else {
            Text("暂无 5 小时健康数据")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func color(for tone: CredentialHealthTone) -> Color {
        switch tone {
        case .idle: .secondary.opacity(0.18)
        case .normal: .primary.opacity(0.72)
        case .warning: .yellow
        case .critical: .red
        }
    }

    private func barHeight(
        _ bucket: UsageCredentialHealthBucket,
        maximumRequestCount: Double
    ) -> CGFloat {
        let count = credentialRequestCount(success: bucket.success, failure: bucket.failure)
        return credentialHealthBarHeight(
            requestCount: count,
            maximumRequestCount: maximumRequestCount
        )
    }

    private func bucketHelp(_ bucket: UsageCredentialHealthBucket) -> String {
        "\(dashboardShortTime(bucket.startTime))–\(dashboardShortTime(bucket.endTime)) · "
            + "成功 \(bucket.success ?? 0) / 失败 \(bucket.failure ?? 0)"
    }
}

enum CredentialHealthTone: Equatable {
    case idle
    case normal
    case warning
    case critical
}

func credentialHealthTones(_ health: UsageCredentialHealth) -> [CredentialHealthTone] {
    let overallCritical = credentialOverallSuccessRate(health).map {
        $0 < criticalSuccessRateThreshold
    } == true
    var consecutiveCompleteFailures = 0
    return health.buckets.map { bucket in
        let success = max(bucket.success ?? 0, 0)
        let failure = max(bucket.failure ?? 0, 0)
        guard success > 0 || failure > 0 else {
            consecutiveCompleteFailures = 0
            return .idle
        }
        guard failure > 0 else {
            consecutiveCompleteFailures = 0
            return .normal
        }
        if success == 0 {
            consecutiveCompleteFailures += 1
        } else {
            consecutiveCompleteFailures = 0
        }
        if overallCritical
            || consecutiveCompleteFailures >= criticalConsecutiveFailureCount {
            return .critical
        }
        return .warning
    }
}

func credentialHealthBarHeight(
    requestCount: Double,
    maximumRequestCount: Double
) -> CGFloat {
    guard requestCount > 0, maximumRequestCount > 0 else { return minimumTrendBarHeight }
    let ratio = min(max(requestCount / maximumRequestCount, 0), 1)
    return max(minimumTrendBarHeight, maximumTrendBarHeight * ratio)
}

private func credentialOverallSuccessRate(_ health: UsageCredentialHealth) -> Double? {
    if let rate = health.successRate { return min(max(rate, 0), 100) }
    let total = credentialRequestCount(
        success: health.totalSuccess,
        failure: health.totalFailure
    )
    guard total > 0 else { return nil }
    return max(Double(health.totalSuccess ?? 0), 0) / total * 100
}
