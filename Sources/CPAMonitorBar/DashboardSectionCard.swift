import SwiftUI

enum DashboardSectionKind: CaseIterable {
    case overview
    case requestHealth
    case tokenShare

    var title: String {
        switch self {
        case .overview: "使用概览"
        case .requestHealth: "请求健康"
        case .tokenShare: "Token 占比"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .overview: "monitor.overview.summary"
        case .requestHealth: "monitor.overview.request-health"
        case .tokenShare: "monitor.overview.token-share"
        }
    }

    var accentColor: Color {
        switch self {
        case .overview: .blue
        case .requestHealth: .green
        case .tokenShare: .cyan
        }
    }
}

struct DashboardSectionCard<HeaderAccessory: View, Content: View>: View {
    let section: DashboardSectionKind
    private let headerAccessory: HeaderAccessory
    private let content: Content

    init(
        section: DashboardSectionKind,
        @ViewBuilder headerAccessory: () -> HeaderAccessory,
        @ViewBuilder content: () -> Content
    ) {
        self.section = section
        self.headerAccessory = headerAccessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Capsule()
                    .fill(section.accentColor.opacity(0.85))
                    .frame(width: 3, height: 15)
                Text(section.title)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                headerAccessory
            }
            content
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.secondary.opacity(0.075),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.secondary.opacity(0.13), lineWidth: 1)
        }
        .accessibilityIdentifier(section.accessibilityIdentifier)
    }
}

extension DashboardSectionCard where HeaderAccessory == EmptyView {
    init(
        section: DashboardSectionKind,
        @ViewBuilder content: () -> Content
    ) {
        self.init(section: section, headerAccessory: { EmptyView() }, content: content)
    }
}
