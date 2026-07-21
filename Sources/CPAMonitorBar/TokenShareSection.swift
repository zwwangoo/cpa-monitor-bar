import SwiftUI
import CPAModels

enum TokenShareDimension: String, CaseIterable, Identifiable {
    case models, apiKeys, authFiles, aiProviders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .models: "模型"
        case .apiKeys: "API Key"
        case .authFiles: "认证文件"
        case .aiProviders: "AI 提供商"
        }
    }
}

func tokenShareItems(
    for dimension: TokenShareDimension,
    in analysis: UsageAnalysisResponse?
) -> [CompositionItem] {
    guard let analysis else { return [] }
    switch dimension {
    case .models: return analysis.modelComposition
    case .apiKeys: return analysis.apiKeyComposition
    case .authFiles: return analysis.authFilesComposition
    case .aiProviders: return analysis.aiProviderComposition
    }
}

func tokenSharePercent(_ item: CompositionItem) -> Double {
    min(max(item.percent ?? 0, 0), 100)
}

struct TokenShareSection: View {
    let analysis: UsageAnalysisResponse?
    @State private var dimension = TokenShareDimension.models

    var body: some View {
        GroupBox("Token 占比") {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Token 占比维度", selection: $dimension) {
                    ForEach(TokenShareDimension.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                let items = tokenShareItems(for: dimension, in: analysis)
                if items.isEmpty {
                    Text("暂无数据")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                                TokenShareRow(item: item)
                                if index < items.count - 1 { Divider() }
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityIdentifier("monitor.overview.token-share")
    }
}

private struct TokenShareRow: View {
    let item: CompositionItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(preferredText(item.label, item.key))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer()
                Text(String(format: "%.2f%%", tokenSharePercent(item)))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            shareTrack
            HStack(spacing: 6) {
                TokenMetricPill(label: "Tokens", value: compact(item.totalTokens))
                TokenMetricPill(label: "请求", value: integer(item.requests))
                if let cost = item.costUSD {
                    TokenMetricPill(label: "成本", value: currency(cost))
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var shareTrack: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule()
                    .fill(LinearGradient(
                        colors: [.blue, .teal],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geometry.size.width * tokenSharePercent(item) / 100)
            }
        }
        .frame(height: 6)
    }

    private func compact(_ value: Int?) -> String {
        value?.formatted(.number.notation(.compactName)) ?? "—"
    }

    private func integer(_ value: Int?) -> String {
        value?.formatted() ?? "—"
    }

    private func currency(_ value: Double) -> String {
        value >= 1 ? String(format: "$%.2f", value) : String(format: "$%.4f", value)
    }
}

private struct TokenMetricPill: View {
    let label: String
    let value: String

    var body: some View {
        Text("\(label)  \(value)")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .overlay { Capsule().stroke(.quaternary) }
    }
}
