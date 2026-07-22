import AppKit
import SwiftUI

struct MonitorPopover: View {
    @ObservedObject var model: MonitorViewModel
    @ObservedObject var windowPresentation: MonitorWindowPresentation
    let onTogglePin: () -> Void
    let onDragPinnedWindow: (CGSize, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            windowToolbar
            Divider()
                .padding(.vertical, 14)
            if model.configurationState == .unconfigured {
                configurationView
            } else if model.health.isLoading && model.health.value == nil {
                loadingView
            } else if let error = model.health.errorMessage {
                offlineView(error: error)
            } else if !model.isAuthenticated {
                LoginView(error: model.loginError)
            } else {
                dashboard
            }
            Divider()
                .padding(.vertical, 6)
            footer
        }
        .padding(16)
        .frame(width: 420)
    }

    private var windowToolbar: some View {
        HStack(spacing: 10) {
            Button(action: handlePinButton) {
                Image(systemName: windowPresentation.isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(windowPresentation.isPinned ? Color.accentColor : .secondary)
                    .frame(width: 28, height: 28)
                    .background(pinBackground, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .help(pinHelp)
            .accessibilityLabel(pinHelp)

            if model.isAuthenticated {
                dashboardToolbar
            } else {
                Spacer()
            }

            if windowPresentation.isPinned {
                dragHandle
            }
        }
    }

    private var dragHandle: some View {
        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { onDragPinnedWindow($0.translation, false) }
                    .onEnded { onDragPinnedWindow($0.translation, true) }
            )
            .help("拖动置顶窗口")
            .accessibilityLabel("拖动置顶窗口")
    }

    private var pinBackground: Color {
        windowPresentation.isPinned ? Color.accentColor.opacity(0.14) : Color.secondary.opacity(0.08)
    }

    private var pinHelp: String {
        windowPresentation.isPinned ? "取消置顶" : "置顶窗口"
    }

    private func handlePinButton() {
        onTogglePin()
    }

    private var dashboardToolbar: some View {
        Picker("监控页面", selection: $windowPresentation.selectedTab) {
            ForEach(MonitorTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 2)
    }

    private var loadingView: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("正在连接 Keeper…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
    }

    private var configurationView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("尚未配置 CPA Keeper", systemImage: "gear.badge.questionmark")
                .font(.headline)
            Text("请先设置 CPA 服务根 URL，配置完成后应用会检查连接与登录状态。")
                .font(.caption)
                .foregroundStyle(.secondary)
            SettingsLink {
                Text("打开设置…")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
    }

    private func offlineView(error: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ErrorBanner(message: error, stale: model.health.isStale)
            Button("重新连接") { Task { await model.refresh() } }
        }
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
    }

    private var dashboard: some View {
        Group {
            switch windowPresentation.selectedTab {
            case .overview:
                overviewDashboard
            case .events:
                RequestEventsTab(
                    state: model.events,
                    range: model.usageRange,
                    canLoadMore: model.canLoadMoreEvents,
                    isLoadingMore: model.isLoadingMoreEvents,
                    loadMoreError: model.eventsLoadMoreError,
                    onLoadMore: { Task { await model.loadMoreEvents() } }
                )
            case .credentials:
                ScrollView {
                    CredentialsTab(
                        authFiles: model.authFiles,
                        quotaCache: model.quotaCache,
                        isRefreshingQuota: model.isRefreshingQuota,
                        quotaRefreshError: model.quotaRefreshError,
                        onRefreshQuota: { model.refreshQuota(authIndexes: $0) }
                    )
                }
                .scrollIndicators(.hidden)
            case .providers:
                ScrollView { ProvidersTab(providers: model.providers) }
                    .scrollIndicators(.hidden)
            }
        }
        .frame(height: dashboardHeight)
    }

    private var overviewDashboard: some View {
        VStack(alignment: .leading, spacing: 14) {
            summarySection
            TokenShareSection(analysis: model.analysis.value)
        }
    }

    private var summarySection: some View {
        GroupBox("使用概览") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    MetricCard(title: "请求", value: integer(model.overview.value?.usage?.totalRequests))
                    MetricCard(title: "Tokens", value: integer(model.overview.value?.usage?.totalTokens))
                    MetricCard(title: "成功率", value: percent(model.overview.value?.serviceHealth?.successRate))
                    MetricCard(title: "总成本", value: currency(model.overview.value?.summary?.totalCost))
                }
                SectionFeedback(state: model.overview)
            }
        }
    }

    private var footer: some View {
        MonitorFooter(model: model)
    }

    private func integer(_ value: Int?) -> String {
        value?.formatted(.number.notation(.compactName)) ?? "—"
    }

    private func percent(_ value: Double?) -> String {
        value.map { String(format: "%.1f%%", $0) } ?? "—"
    }

    private func currency(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value >= 1 ? String(format: "$%.2f", value) : String(format: "$%.4f", value)
    }

    private var dashboardHeight: CGFloat {
        let availableHeight = NSScreen.main?.visibleFrame.height ?? 900
        return min(max(availableHeight * 0.58, 460), 620)
    }

}

enum MonitorTab: String, CaseIterable, Identifiable {
    case overview, events, credentials, providers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "概览"
        case .events: "请求事件"
        case .credentials: "认证文件"
        case .providers: "供应商"
        }
    }
}
