import AppKit
import SwiftUI
import CPAClient

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: MonitorViewModel
    @State private var baseURL = ""
    @State private var password = ""
    @State private var launchAtLogin = false
    @State private var refreshFrequency = RefreshFrequency.oneMinute
    @State private var usageRange = UsageTimeRange.today
    @State private var validationError: String?
    @State private var isApplying = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    connectionCard
                    monitoringCard
                    aboutCard
                }
                .padding(18)
            }
            .scrollIndicators(.hidden)

            Divider()
            actionBar
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
        }
        .frame(width: 520, height: 540)
        .controlSize(.regular)
        .onAppear(perform: loadCurrentSettings)
    }

    private var connectionCard: some View {
        settingsCard(title: "连接", symbol: "network") {
            VStack(spacing: 11) {
                fieldRow("服务根 URL") {
                    TextField("https:// 或 http://keeper.example/cpa", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                }
                fieldRow("管理员密码") {
                    SecureField("留空使用已保存密码", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { apply() }
                }
                Divider()
                Label(
                    "支持 HTTP 与 HTTPS；密码按服务地址保存在此 Mac 的 Keychain。HTTP 连接不会加密登录密码和监控数据。",
                    systemImage: "exclamationmark.shield"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var monitoringCard: some View {
        settingsCard(title: "监控", symbol: "gauge.with.dots.needle.67percent") {
            VStack(spacing: 10) {
                settingRow("开机时自动启动") {
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                Divider()
                settingRow("刷新频率") {
                    Picker("", selection: $refreshFrequency) {
                        ForEach(RefreshFrequency.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 145)
                }
                Divider()
                settingRow("时间范围") {
                    Picker("", selection: $usageRange) {
                        ForEach(UsageTimeRange.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 245)
                }
                Text("时间范围用于概览和请求事件；供应商固定展示最近 5 小时。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var aboutCard: some View {
        settingsCard(title: "关于", symbol: "info.circle") {
            settingRow("CPA Monitor Bar") {
                Text("版本 \(currentApplicationVersion())")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            statusMessage
            Spacer(minLength: 12)
            if isApplying {
                ProgressView().controlSize(.small)
            }
            Button("应用并关闭") { apply() }
                .keyboardShortcut(.defaultAction)
                .disabled(isApplying || trimmedBaseURL.isEmpty)
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        if let validationError {
            Label(validationError, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .lineLimit(2)
        } else if model.configurationState == .unconfigured {
            Label("首次保存后会自动连接并登录", systemImage: "info.circle")
                .foregroundStyle(.secondary)
        }
    }

    private func fieldRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 88, alignment: .leading)
            content()
        }
    }

    private func settingRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            content()
        }
    }

    private func settingsCard<Content: View>(
        title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.65), lineWidth: 1)
        )
    }

    private var trimmedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func apply() {
        guard !isApplying else { return }
        validationError = nil
        isApplying = true
        let submittedPassword = password
        Task {
            do {
                try await model.applySettings(
                    baseURL: baseURL,
                    password: submittedPassword,
                    usageRange: usageRange,
                    refreshFrequency: refreshFrequency,
                    launchAtLogin: launchAtLogin
                )
                baseURL = model.baseURL
                password = ""
                isApplying = false
                closeSettingsWindow()
            } catch {
                validationError = error.localizedDescription
                isApplying = false
            }
        }
    }

    private func loadCurrentSettings() {
        baseURL = model.baseURL
        launchAtLogin = model.launchAtLoginEnabled
        refreshFrequency = model.refreshFrequency
        usageRange = model.usageRange
    }

    private func closeSettingsWindow() {
        let settingsWindow = NSApp.keyWindow
        dismiss()
        settingsWindow?.performClose(nil)
    }
}
