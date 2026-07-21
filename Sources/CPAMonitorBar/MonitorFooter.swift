import AppKit
import SwiftUI

struct MonitorFooter: View {
    @ObservedObject var model: MonitorViewModel
    let onOpenSettings: () -> Void
    @State private var isQuitting = false

    var body: some View {
        VStack(spacing: 9) {
            if model.configurationState == .configured {
                keeperInfoRow
                Divider()
            }
            actionRow
        }
    }

    private var keeperInfoRow: some View {
        HStack(spacing: 8) {
            Label(versionText, systemImage: "shippingbox")
                .lineLimit(1)
            Spacer()
            Button {
                openKeeperInBrowser()
            } label: {
                Label("浏览器打开", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.borderless)
            .help(model.baseURL)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var actionRow: some View {
        HStack(spacing: 6) {
            FooterActionButton(title: "设置", symbol: "gearshape") {
                onOpenSettings()
            }
            .accessibilityIdentifier("monitor.footer.settings")
            if model.configurationState == .configured {
                FooterActionButton(
                    title: "刷新",
                    symbol: "arrow.clockwise",
                    isLoading: model.isRefreshing,
                    isDisabled: model.isRefreshing
                ) {
                    Task { await model.refresh() }
                }
                if let date = model.lastUpdatedAt {
                    Text(date.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .help("更新于 \(date.formatted(date: .omitted, time: .shortened))")
                }
            }
            Spacer(minLength: 4)
            if model.isAuthenticated {
                FooterActionButton(title: "退出登录", symbol: "rectangle.portrait.and.arrow.right") {
                    Task { await model.logout() }
                }
            }
            FooterActionButton(
                title: "退出应用",
                symbol: "power",
                isLoading: isQuitting,
                isDisabled: isQuitting,
                role: .danger
            ) {
                isQuitting = true
                Task {
                    await performApplicationQuit(
                        logout: { await model.logout() },
                        terminate: { NSApplication.shared.terminate(nil) }
                    )
                }
            }
        }
    }

    private var versionText: String {
        guard let version = model.keeperVersion.value?.version,
              !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Keeper 版本未知"
        }
        return "Keeper \(version)"
    }

    private func openKeeperInBrowser() {
        guard let url = URL(string: model.baseURL) else { return }
        NSWorkspace.shared.open(url)
    }
}

@MainActor
func performApplicationQuit(
    logout: @escaping () async -> Void,
    terminate: @escaping () -> Void
) async {
    await logout()
    terminate()
}

private struct FooterActionButton: View {
    enum Role { case normal, danger }

    let title: String
    let symbol: String
    var isLoading = false
    var isDisabled = false
    var role = Role.normal
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                ZStack {
                    Image(systemName: symbol).opacity(isLoading ? 0 : 1)
                    if isLoading { ProgressView().controlSize(.mini) }
                }
                .frame(width: 12, height: 12)
                Text(title)
            }
            .font(.caption)
            .foregroundStyle(role == .danger ? Color.red : Color.primary)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
