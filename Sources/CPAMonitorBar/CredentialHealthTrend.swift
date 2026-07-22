import SwiftUI
import CPAModels

struct CredentialHealthTrend: View {
    let health: UsageCredentialHealth?

    var body: some View {
        if let health, !health.buckets.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("成功率 \(formattedPercent(health.successRate))")
                    Spacer()
                    Text("失败 \(health.totalFailure ?? 0)")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(health.buckets.enumerated()), id: \.offset) { _, bucket in
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(color(for: bucket))
                            .frame(maxWidth: .infinity)
                            .frame(height: barHeight(bucket, in: health.buckets))
                            .help(bucketHelp(bucket))
                    }
                }
                .frame(height: 36, alignment: .bottom)
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

    private func color(for bucket: UsageCredentialHealthBucket) -> Color {
        let total = credentialRequestCount(success: bucket.success, failure: bucket.failure)
        guard total > 0 else { return .secondary.opacity(0.25) }
        if bucket.failure == 0 { return .green }
        if (bucket.rate ?? 0) >= 80 { return .orange }
        return .red
    }

    private func barHeight(
        _ bucket: UsageCredentialHealthBucket,
        in buckets: [UsageCredentialHealthBucket]
    ) -> CGFloat {
        let count = credentialRequestCount(success: bucket.success, failure: bucket.failure)
        let maximum = buckets.map {
            credentialRequestCount(success: $0.success, failure: $0.failure)
        }.max() ?? 0
        guard maximum > 0 else { return 4 }
        return max(4, 36 * count / maximum)
    }

    private func bucketHelp(_ bucket: UsageCredentialHealthBucket) -> String {
        "\(dashboardShortTime(bucket.startTime))–\(dashboardShortTime(bucket.endTime)) · "
            + "成功 \(bucket.success ?? 0) / 失败 \(bucket.failure ?? 0)"
    }
}
