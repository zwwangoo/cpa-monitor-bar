import Foundation
import SwiftUI

enum ProviderUsageValidationState: Equatable {
    case idle
    case validating
    case success
    case failure(String)
}

struct ProviderUsageValidationInput: Equatable {
    let providerID: String
    let baseURL: String
    let enteredKey: String
    let hasSavedKey: Bool
    let isEnabled: Bool
}

struct ProviderUsageDraft: Identifiable, Equatable {
    let providerID: String
    let providerName: String
    var baseURL: String
    var enteredKey: String
    var hasSavedKey: Bool
    var isEnabled: Bool
    var validation: ProviderUsageValidationState

    var id: String { providerID }

    var validationInput: ProviderUsageValidationInput {
        ProviderUsageValidationInput(
            providerID: providerID,
            baseURL: baseURL,
            enteredKey: enteredKey,
            hasSavedKey: hasSavedKey,
            isEnabled: isEnabled
        )
    }
}

struct ProviderUsageSettingsCard: View {
    @Binding var drafts: [ProviderUsageDraft]
    let isLoading: Bool
    let blockReason: String?
    let onValidate: (ProviderUsageDraft) -> Void

    @State private var expandedProviderIDs = Set<String>()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("供应商用量", systemImage: "creditcard.and.123")
                .font(.headline)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)

            Text("按供应商配置独立的 Sub2API 地址和监控 Key；未启用时不会发起请求。")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let blockReason {
                Label(blockReason, systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在读取供应商配置…")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            } else if drafts.isEmpty {
                Text("Keeper 暂未返回可配置的供应商。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach($drafts) { $draft in
                    providerEditor(draft: $draft)
                    if draft.id != drafts.last?.id { Divider() }
                }
            }
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
        .disabled(blockReason != nil)
    }

    private func providerEditor(
        draft: Binding<ProviderUsageDraft>
    ) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedProviderIDs.contains(draft.wrappedValue.providerID) },
                set: { isExpanded in
                    if isExpanded {
                        expandedProviderIDs.insert(draft.wrappedValue.providerID)
                    } else {
                        expandedProviderIDs.remove(draft.wrappedValue.providerID)
                    }
                }
            )
        ) {
            if draft.wrappedValue.isEnabled {
                VStack(spacing: 10) {
                    fieldRow("API 地址") {
                        TextField(
                            "https://sub2api.example",
                            text: draft.baseURL
                        )
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { endSettingsTextEditing() }
                    }
                    fieldRow("监控 Key") {
                        SecureField(
                            draft.wrappedValue.hasSavedKey
                                ? "留空保留已保存 Key"
                                : "输入 Sub2API Key",
                            text: draft.enteredKey
                        )
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { endSettingsTextEditing() }
                    }
                    if draft.wrappedValue.hasSavedKey {
                        Text("已有 Key 保存在 ~/.cpamonitorbar/config.toml，不会在设置中回显。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    HStack {
                        validationStatus(draft.wrappedValue.validation)
                        Spacer()
                        Button("验证连接") {
                            onValidate(draft.wrappedValue)
                        }
                        .disabled(
                            draft.wrappedValue.validation == .validating
                                || draft.wrappedValue.baseURL
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                    .isEmpty
                                || draft.wrappedValue.enteredKey
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                    .isEmpty && !draft.wrappedValue.hasSavedKey
                        )
                    }
                    .frame(minHeight: 20)
                }
                .padding(.top, 10)
            }
        } label: {
            HStack {
                Text(draft.wrappedValue.providerName)
                    .lineLimit(1)
                Spacer()
                Text(draft.wrappedValue.isEnabled ? "已启用" : "未配置")
                    .font(.caption)
                    .foregroundStyle(
                        draft.wrappedValue.isEnabled
                            ? Color.accentColor
                            : Color.secondary
                    )
                Toggle("", isOn: draft.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        }
        .onChange(of: draft.wrappedValue.isEnabled) { _, enabled in
            if enabled {
                expandedProviderIDs.insert(draft.wrappedValue.providerID)
            }
        }
    }

    @ViewBuilder
    private func validationStatus(
        _ state: ProviderUsageValidationState
    ) -> some View {
        switch state {
        case .idle:
            Color.clear.frame(width: 1, height: 16)
        case .validating:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("正在验证…")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        case .success:
            Label("连接成功", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case let .failure(message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(1)
        }
    }

    private func fieldRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            Text(title).frame(width: 76, alignment: .leading)
            content()
        }
    }
}
