import AppKit
import SwiftUI
import CPAClient

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: MonitorViewModel
    let shortcutController: GlobalShortcutController
    @State private var baseURL = ""
    @State private var password = ""
    @State private var launchAtLogin = false
    @State private var refreshFrequency = RefreshFrequency.oneMinute
    @State private var usageRange = UsageTimeRange.today
    @State private var globalShortcut: GlobalShortcut?
    @State private var consentToInsecureHTTP = false
    @State private var providerUsageDrafts: [ProviderUsageDraft] = []
    @State private var isLoadingProviderUsageDrafts = true
    @State private var providerValidationRequestIDs: [String: UUID] = [:]
    @State private var providerValidationTasks: [String: Task<Void, Never>] = [:]
    @State private var validationError: String?
    @State private var isApplying = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    connectionCard
                    monitoringCard
                    ProviderUsageSettingsCard(
                        drafts: $providerUsageDrafts,
                        isLoading: isLoadingProviderUsageDrafts,
                        blockReason: model.providerUsageSettingsBlockReason(
                            for: baseURL
                        ),
                        onValidate: validateProviderUsageDraft
                    )
                    aboutCard
                }
                .padding(18)
            }
            .scrollIndicators(.hidden)
            .disabled(isApplying)
            .onScrollPhaseChange { _, phase in
                guard phase != .idle else { return }
                endSettingsTextEditing()
            }

            Divider()
            actionBar
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
        }
        .frame(width: 520, height: 540)
        .controlSize(.regular)
        .onAppear(perform: loadCurrentSettings)
        .onDisappear(perform: cancelProviderValidations)
        .onChange(of: baseURL) { _, newValue in
            consentToInsecureHTTP = model.hasInsecureHTTPConsent(for: newValue)
        }
        .onChange(of: providerUsageDrafts.map(\.validationInput)) {
            oldInputs,
            newInputs in
            invalidateProviderValidations(
                oldInputs: oldInputs,
                newInputs: newInputs
            )
        }
        .onChange(of: model.providers.value?.identities.map(\.id)) {
            oldProviderIDs,
            newProviderIDs in
            guard oldProviderIDs == nil, newProviderIDs != nil else { return }
            loadProviderUsageSettings()
        }
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
                        .onSubmit { endSettingsTextEditing() }
                }
                if requiresInsecureHTTPConsent {
                    Divider()
                    Toggle(
                        "我确认仅在可信网络中使用未加密的远程 HTTP 服务",
                        isOn: $consentToInsecureHTTP
                    )
                    .toggleStyle(.checkbox)
                    .font(.caption)
                }
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
                settingRow("全局快捷键") {
                    ShortcutRecorder(
                        shortcut: $globalShortcut,
                        onRecordingChanged: handleShortcutRecording
                    )
                }
                Text("未设置时不注册快捷键；重复按键可显示或收起监控窗口。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                .disabled(
                    isApplying || trimmedBaseURL.isEmpty
                        || requiresInsecureHTTPConsent && !consentToInsecureHTTP
                        || isLoadingProviderUsageDrafts
                            && model.providerUsageSettingsBlockReason(
                                for: baseURL
                            ) == nil
                )
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

    private var requiresInsecureHTTPConsent: Bool {
        guard let root = try? CPAServiceRoot(trimmedBaseURL) else { return false }
        return root.requiresInsecureHTTPConsent
            && !model.hasInsecureHTTPConsent(for: trimmedBaseURL)
    }

    private func apply() {
        guard !isApplying else { return }
        endSettingsTextEditing()
        validationError = nil
        isApplying = true
        let submission = SettingsSubmission(
            baseURL: baseURL,
            password: password,
            launchAtLogin: launchAtLogin,
            refreshFrequency: refreshFrequency,
            usageRange: usageRange,
            globalShortcut: globalShortcut,
            consentToInsecureHTTP: consentToInsecureHTTP,
            providerUsageDrafts: providerUsageDrafts
        )
        let previousShortcut = shortcutController.shortcut
        Task {
            do {
                try await applyChanges(
                    submission: submission,
                    previousShortcut: previousShortcut
                )
                baseURL = model.baseURL
                password = ""
                for index in providerUsageDrafts.indices {
                    providerUsageDrafts[index].enteredKey = ""
                }
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
        globalShortcut = shortcutController.shortcut
        consentToInsecureHTTP = model.hasInsecureHTTPConsent(for: baseURL)
        validationError = shortcutController.registrationError
        cancelProviderValidations()
        loadProviderUsageSettings()
    }

    private func loadProviderUsageSettings() {
        isLoadingProviderUsageDrafts = true
        Task {
            do {
                providerUsageDrafts = try await model.loadProviderUsageDrafts()
            } catch let error as ProviderUsageError
                where error == .providerListUnavailable {
                providerUsageDrafts = []
            } catch {
                validationError = error.localizedDescription
            }
            isLoadingProviderUsageDrafts = false
        }
    }

    private func applyChanges(
        submission: SettingsSubmission,
        previousShortcut: GlobalShortcut?
    ) async throws {
        let shouldApplyProviderUsage = model.providerUsageSettingsBlockReason(
            for: submission.baseURL
        ) == nil
        let expectedKeeperRoot = try CPAServiceRoot(
            submission.baseURL
        ).url.absoluteString
        if shouldApplyProviderUsage {
            try await model.validateProviderUsageDrafts(
                submission.providerUsageDrafts,
                keeperRoot: expectedKeeperRoot
            )
        }
        try shortcutController.apply(submission.globalShortcut)
        do {
            try await model.applySettings(
                baseURL: submission.baseURL,
                password: submission.password,
                usageRange: submission.usageRange,
                refreshFrequency: submission.refreshFrequency,
                launchAtLogin: submission.launchAtLogin,
                consentToInsecureHTTP: submission.consentToInsecureHTTP
            )
            if shouldApplyProviderUsage {
                try await model.applyProviderUsageDrafts(
                    submission.providerUsageDrafts,
                    expectedKeeperRoot: expectedKeeperRoot
                )
            }
        } catch {
            try? shortcutController.apply(previousShortcut)
            throw error
        }
    }

    private func validateProviderUsageDraft(_ draft: ProviderUsageDraft) {
        guard let index = providerUsageDrafts.firstIndex(where: {
            $0.providerID == draft.providerID
        }) else { return }
        let requestID = UUID()
        let validationInput = draft.validationInput
        providerValidationTasks.removeValue(forKey: draft.providerID)?.cancel()
        providerValidationRequestIDs[draft.providerID] = requestID
        providerUsageDrafts[index].validation = .validating
        providerValidationTasks[draft.providerID] = Task {
            do {
                _ = try await model.validateProviderUsageDraft(draft)
                updateProviderValidation(
                    providerID: draft.providerID,
                    requestID: requestID,
                    validationInput: validationInput,
                    state: .success
                )
            } catch {
                updateProviderValidation(
                    providerID: draft.providerID,
                    requestID: requestID,
                    validationInput: validationInput,
                    state: .failure(error.localizedDescription)
                )
            }
        }
    }

    private func updateProviderValidation(
        providerID: String,
        requestID: UUID,
        validationInput: ProviderUsageValidationInput,
        state: ProviderUsageValidationState
    ) {
        guard let index = providerUsageDrafts.firstIndex(where: {
            $0.providerID == providerID
        }),
        providerValidationRequestIDs[providerID] == requestID,
        providerUsageDrafts[index].validationInput == validationInput else {
            return
        }
        providerValidationRequestIDs.removeValue(forKey: providerID)
        providerValidationTasks.removeValue(forKey: providerID)
        providerUsageDrafts[index].validation = state
    }

    private func invalidateProviderValidations(
        oldInputs: [ProviderUsageValidationInput],
        newInputs: [ProviderUsageValidationInput]
    ) {
        let previous = Dictionary(
            uniqueKeysWithValues: oldInputs.map { ($0.providerID, $0) }
        )
        for input in newInputs where previous[input.providerID] != input {
            providerValidationRequestIDs.removeValue(forKey: input.providerID)
            providerValidationTasks.removeValue(forKey: input.providerID)?.cancel()
            guard let index = providerUsageDrafts.firstIndex(where: {
                $0.providerID == input.providerID
            }), providerUsageDrafts[index].validation != .idle else {
                continue
            }
            providerUsageDrafts[index].validation = .idle
        }
    }

    private func cancelProviderValidations() {
        for task in providerValidationTasks.values { task.cancel() }
        providerValidationTasks.removeAll()
        providerValidationRequestIDs.removeAll()
    }

    private func handleShortcutRecording(_ isRecording: Bool) {
        if isRecording {
            shortcutController.suspend()
        } else {
            do { try shortcutController.resume() }
            catch { validationError = error.localizedDescription }
        }
    }

    private func closeSettingsWindow() {
        let settingsWindow = NSApp.keyWindow
        dismiss()
        settingsWindow?.performClose(nil)
    }
}

private struct SettingsSubmission {
    let baseURL: String
    let password: String
    let launchAtLogin: Bool
    let refreshFrequency: RefreshFrequency
    let usageRange: UsageTimeRange
    let globalShortcut: GlobalShortcut?
    let consentToInsecureHTTP: Bool
    let providerUsageDrafts: [ProviderUsageDraft]
}
