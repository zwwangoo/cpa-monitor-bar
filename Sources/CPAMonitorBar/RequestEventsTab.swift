import SwiftUI
import CPAClient
import CPAModels

struct RequestEventsTab: View {
    let state: SectionState<UsageEventsResponse>
    let range: UsageTimeRange
    let canLoadMore: Bool
    let isLoadingMore: Bool
    let loadMoreError: String?
    let onLoadMore: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(range.title)
                        .font(.headline)
                    Spacer()
                    Text(eventCountSummary(totalCount: state.value?.totalCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let events = state.value?.events, !events.isEmpty {
                    RequestEventColumnHeader()
                    Divider()
                    ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                        RequestEventRow(event: event)
                        if index < events.count - 1 { Divider() }
                    }
                    loadMoreFooter
                } else if !state.isLoading && state.errorMessage == nil {
                    ContentUnavailableView(
                        "暂无请求事件",
                        systemImage: "tray",
                        description: Text("所选时间范围内没有可展示的请求。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 180)
                }
                SectionFeedback(state: state)
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("monitor.tab.events")
    }

    @ViewBuilder
    private var loadMoreFooter: some View {
        if isLoadingMore {
            HStack(spacing: 7) {
                ProgressView().controlSize(.small)
                Text("正在加载更多…")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else if let loadMoreError {
            HStack(spacing: 8) {
                Text(loadMoreError).lineLimit(1)
                Button("重试", action: onLoadMore)
            }
            .font(.caption)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else if canLoadMore {
            Color.clear
                .frame(height: 1)
                .onAppear(perform: onLoadMore)
        }
    }
}

private enum EventColumnWidth {
    static let status: CGFloat = 8
    static let time: CGFloat = 35
    static let apiKey: CGFloat = 54
    static let credential: CGFloat = 69
    static let model: CGFloat = 62
    static let type: CGFloat = 34
    static let latency: CGFloat = 78
}

private struct RequestEventColumnHeader: View {
    var body: some View {
        HStack(spacing: 6) {
            Color.clear.frame(width: EventColumnWidth.status, height: 1)
            column("时间", width: EventColumnWidth.time)
            column("Key", width: EventColumnWidth.apiKey)
            column("凭证", width: EventColumnWidth.credential)
            column("模型", width: EventColumnWidth.model)
            column("类型", width: EventColumnWidth.type)
            column("首字/总耗时", width: EventColumnWidth.latency, alignment: .trailing)
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .lineLimit(1)
    }

    private func column(
        _ title: String,
        width: CGFloat,
        alignment: Alignment = .leading
    ) -> some View {
        Text(title)
            .minimumScaleFactor(0.8)
            .frame(width: width, alignment: alignment)
    }
}

private struct RequestEventRow: View {
    let event: UsageEvent
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            statusIndicator
            cell(dashboardShortTime(event.timestamp), width: EventColumnWidth.time)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
            cell(apiKeyText, width: EventColumnWidth.apiKey)
                .foregroundStyle(.secondary)
                .truncationMode(.middle)
                .help(apiKeyText)
            cell(credentialText, width: EventColumnWidth.credential)
                .fontWeight(.semibold)
                .truncationMode(.middle)
                .help(credentialText)
            cell(modelText, width: EventColumnWidth.model)
                .help(modelText)
            RequestTypeBadge(type: typeText)
                .frame(width: EventColumnWidth.type)
            cell(latencyText, width: EventColumnWidth.latency, alignment: .trailing)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .help(latencyHelp)
        }
        .font(.caption2)
        .lineLimit(1)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(
            isHovered ? Color.primary.opacity(0.04) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
        .onHover { isHovered = $0 }
    }

    private var statusIndicator: some View {
        Circle()
            .fill(event.failed == true ? Color.red : Color.green)
            .frame(width: EventColumnWidth.status, height: EventColumnWidth.status)
            .help(event.failed == true ? "失败" : "成功")
            .accessibilityLabel(event.failed == true ? "请求失败" : "请求成功")
    }

    private func cell(
        _ value: String,
        width: CGFloat,
        alignment: Alignment = .leading
    ) -> some View {
        Text(value).frame(width: width, alignment: alignment)
    }

    private var apiKeyText: String { displayAPIKey(event.apiKey) }
    private var credentialText: String { preferredText(event.source) }
    private var modelText: String { preferredText(event.modelAlias, event.model) }
    private var typeText: String { requestType(for: event) }
    private var latencyText: String {
        eventLatencyText(ttftMS: event.ttftMS, latencyMS: event.latencyMS)
    }
    private var latencyHelp: String {
        "首字延迟：\(fullLatency(event.ttftMS)) · 总耗时：\(fullLatency(event.latencyMS))"
    }

    private func fullLatency(_ milliseconds: Int?) -> String {
        milliseconds.map { "\($0) ms" } ?? "—"
    }
}

private struct RequestTypeBadge: View {
    let type: String

    var body: some View {
        Text(type)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
            .help(type)
    }

    private var color: Color {
        switch type {
        case "SSE": .blue
        case "WS": .purple
        default: .secondary
        }
    }
}

func requestType(for event: UsageEvent) -> String {
    guard let method = event.endpoint?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .split(whereSeparator: { $0.isWhitespace })
        .first?
        .uppercased() else { return "—" }
    switch method {
    case "POST": return "SSE"
    case "GET": return "WS"
    default: return "—"
    }
}
