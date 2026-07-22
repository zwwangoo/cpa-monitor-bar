import SwiftUI
import CPAModels

struct CredentialsTab: View {
    let authFiles: SectionState<UsageIdentitiesPageResponse>
    let quotaCache: SectionState<UsageQuotaCacheResponse>
    let isRefreshingQuota: Bool
    let quotaRefreshError: String?
    let onRefreshQuota: ([String]) -> Void
    @State private var selectedCategory = AuthFileCategory.all

    var body: some View {
        authFilesSection
            .accessibilityIdentifier("monitor.tab.credentials")
    }

    private var authFilesSection: some View {
        let identities = visibleAuthFiles(authFiles.value?.identities ?? [])
        let categories = visibleAuthFileCategories(identities)
        let filtered = filterAuthFiles(identities, matching: selectedCategory)
        let refreshIndexes = quotaRefreshIndexes(identities, matching: selectedCategory)
        return GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                credentialToolbar(
                    categories,
                    identities: identities,
                    refreshIndexes: refreshIndexes
                )
                if let quotaRefreshError {
                    Label(quotaRefreshError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .lineLimit(1)
                        .help(quotaRefreshError)
                }
                if !filtered.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(filtered) { identity in
                            AuthFileRow(
                                identity: identity,
                                cache: quotaItem(for: identity)
                            )
                        }
                    }
                } else if !authFiles.isLoading && authFiles.errorMessage == nil {
                    Text("暂无启用的认证文件").foregroundStyle(.tertiary)
                }
                SectionFeedback(state: authFiles)
                SectionFeedback(state: quotaCache)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: categories) { _, nextCategories in
            if !nextCategories.contains(selectedCategory) {
                selectedCategory = .all
            }
        }
    }

    private func credentialToolbar(
        _ categories: [AuthFileCategory],
        identities: [UsageIdentity],
        refreshIndexes: [String]
    ) -> some View {
        HStack(spacing: 8) {
            categoryBar(categories, identities: identities)
                .frame(maxWidth: .infinity, alignment: .leading)
            quotaRefreshButton(refreshIndexes)
        }
    }

    private func quotaRefreshButton(_ indexes: [String]) -> some View {
        Button { onRefreshQuota(indexes) } label: {
            HStack(spacing: 4) {
                ZStack {
                    Image(systemName: "arrow.clockwise")
                        .opacity(isRefreshingQuota ? 0 : 1)
                    if isRefreshingQuota { ProgressView().controlSize(.mini) }
                }
                .frame(width: 12, height: 12)
                Text("刷新额度")
            }
            .font(.caption)
            .fixedSize()
        }
        .controlSize(.small)
        .disabled(isRefreshingQuota || indexes.isEmpty)
        .help(isRefreshingQuota ? "正在刷新当前分类的额度" : "刷新当前分类的额度")
    }

    private func categoryBar(
        _ categories: [AuthFileCategory],
        identities: [UsageIdentity]
    ) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(categories) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text("\(category.title) \(filterAuthFiles(identities, matching: category).count)")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .foregroundStyle(selectedCategory == category ? Color.white : Color.primary)
                            .background(
                                selectedCategory == category ? Color.accentColor : Color.secondary.opacity(0.12),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func quotaItem(for identity: UsageIdentity) -> UsageQuotaCacheItem? {
        quotaCache.value?.items.first { $0.authIndex == identity.identity }
    }
}

enum AuthFileCategory: String, CaseIterable, Identifiable {
    case all, antigravity, claude, codex, geminiCLI, iflow, xai

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "全部"
        case .antigravity: "Antigravity"
        case .claude: "Claude"
        case .codex: "Codex"
        case .geminiCLI: "GeminiCLI"
        case .iflow: "iFlow"
        case .xai: "xAI"
        }
    }

    fileprivate var identityType: String? {
        switch self {
        case .all: nil
        case .antigravity: "antigravity"
        case .claude: "claude"
        case .codex: "codex"
        case .geminiCLI: "gemini-cli"
        case .iflow: "iflow"
        case .xai: "xai"
        }
    }
}

func visibleAuthFileCategories(_ identities: [UsageIdentity]) -> [AuthFileCategory] {
    [.all] + AuthFileCategory.allCases.dropFirst().filter {
        !filterAuthFiles(identities, matching: $0).isEmpty
    }
}

func filterAuthFiles(
    _ identities: [UsageIdentity],
    matching category: AuthFileCategory
) -> [UsageIdentity] {
    guard let type = category.identityType else { return identities }
    return identities.filter {
        $0.type?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == type
    }
}

func quotaRefreshIndexes(
    _ identities: [UsageIdentity],
    matching category: AuthFileCategory
) -> [String] {
    filterAuthFiles(visibleAuthFiles(identities), matching: category).compactMap {
        guard let identity = $0.identity?.trimmingCharacters(in: .whitespacesAndNewlines),
              !identity.isEmpty else { return nil }
        return identity
    }
}

private struct AuthFileRow: View {
    let identity: UsageIdentity
    let cache: UsageQuotaCacheItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(authAccountName(identity), systemImage: "person.crop.circle")
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            if let rows = cache?.quota?.quota, !rows.isEmpty {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    QuotaRow(row: row)
                }
            } else if cache?.error != nil {
                Text("限额缓存读取失败").font(.caption2).foregroundStyle(.orange)
            } else {
                Text("暂无限额缓存").font(.caption2).foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 9, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.8), lineWidth: 0.75)
        }
    }
}

private struct QuotaRow: View {
    let row: UsageQuotaRow

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(row.label ?? row.key).lineLimit(1)
                Spacer()
                Text(remainingText).monospacedDigit()
            }
            .font(.caption2)
            if let remaining = quotaRemainingPercent(row) {
                quotaTrack(remaining)
            }
            if row.resetAt != nil {
                Text("重置：\(dashboardShortTime(row.resetAt))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var remainingText: String {
        guard let percent = quotaRemainingPercent(row) else { return "—" }
        return "\(formattedPercent(percent, fractionDigits: 0)) 可用"
    }

    private func remainingColor(_ value: Double) -> Color {
        if value < 20 { return .red }
        if value < 50 { return .orange }
        return .green
    }

    private func quotaTrack(_ remaining: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.18))
                Capsule()
                    .fill(remainingColor(remaining))
                    .frame(width: geometry.size.width * remaining / 100)
            }
        }
        .frame(height: 4)
    }
}
