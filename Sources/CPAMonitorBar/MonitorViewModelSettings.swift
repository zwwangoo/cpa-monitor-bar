import Foundation
import CPAClient
import CPAModels

extension MonitorViewModel {
    func loadProviderUsageDrafts() async throws -> [ProviderUsageDraft] {
        guard !baseURL.isEmpty else { return [] }
        guard let providerResponse = providers.value,
              providerResponse.hasAuthoritativeIdentities else {
            throw ProviderUsageError.providerListUnavailable
        }
        let configurations = try providerUsageConfigurationStore.load(
            keeperRoot: baseURL
        )
        let configurationsByID = Dictionary(
            configurations.map { ($0.providerID, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        var drafts: [ProviderUsageDraft] = []
        for provider in providerResponse.identities {
            let configuration = configurationsByID[provider.id]
            let scope = ProviderUsageScope(
                keeperRoot: baseURL,
                providerID: provider.id
            )
            let hasSavedKey = try await providerUsageCredentialStore
                .loadKey(scope: scope) != nil
            drafts.append(
                ProviderUsageDraft(
                    providerID: provider.id,
                    providerName: providerUsageDisplayName(provider),
                    baseURL: configuration?.baseURL ?? "",
                    enteredKey: "",
                    hasSavedKey: hasSavedKey,
                    isEnabled: configuration?.isEnabled ?? false,
                    validation: .idle
                )
            )
        }
        return drafts
    }

    func validateProviderUsageDraft(
        _ draft: ProviderUsageDraft
    ) async throws -> ProviderUsageSnapshot {
        let key = try await resolvedProviderUsageKey(for: draft)
        return try await providerUsageMonitor.validate(
            configuration: configuration(from: draft),
            key: key
        )
    }

    func validateProviderUsageDrafts(
        _ drafts: [ProviderUsageDraft],
        keeperRoot: String? = nil
    ) async throws {
        let resolvedKeeperRoot = keeperRoot ?? baseURL
        for draft in drafts where draft.isEnabled {
            _ = try ProviderUsageServiceRoot(draft.baseURL)
            _ = try await resolvedProviderUsageKey(
                for: draft,
                keeperRoot: resolvedKeeperRoot
            )
        }
    }

    func applyProviderUsageDrafts(
        _ drafts: [ProviderUsageDraft],
        expectedKeeperRoot: String? = nil
    ) async throws {
        let keeperRoot = expectedKeeperRoot ?? baseURL
        guard keeperRoot == baseURL else {
            throw ProviderUsageError.keeperChanged
        }
        let generation = connectionGeneration
        guard let providerResponse = providers.value,
              providerResponse.hasAuthoritativeIdentities else {
            throw ProviderUsageError.providerListUnavailable
        }
        let currentProviderIDs = Set(providerResponse.identities.map(\.id))
        guard Set(drafts.map(\.providerID)) == currentProviderIDs else {
            throw ProviderUsageError.providerListChanged
        }
        try await validateProviderUsageDrafts(
            drafts,
            keeperRoot: keeperRoot
        )
        guard generation == connectionGeneration, keeperRoot == baseURL else {
            throw ProviderUsageError.keeperChanged
        }
        guard let latestProviderResponse = providers.value,
              latestProviderResponse.hasAuthoritativeIdentities,
              Set(latestProviderResponse.identities.map(\.id))
                == currentProviderIDs else {
            throw ProviderUsageError.providerListChanged
        }
        let existing = try providerUsageConfigurationStore.load(
            keeperRoot: keeperRoot
        )
        var configurations: [ProviderUsageConfiguration] = []
        var keyUpserts: [String: String] = [:]
        let retainedKeyIDs = Set(
            drafts.filter(\.isEnabled).map(\.providerID)
        )

        for draft in drafts {
            let trimmedURL = draft.baseURL.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let hadConfiguration = existing.contains {
                $0.providerID == draft.providerID
            }
            if draft.isEnabled || hadConfiguration || !trimmedURL.isEmpty {
                configurations.append(configuration(from: draft))
            }

            if draft.isEnabled {
                let enteredKey = draft.enteredKey.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                if !enteredKey.isEmpty {
                    keyUpserts[draft.providerID] = enteredKey
                }
            }
        }

        try await providerUsageCredentialStore.updateKeys(
            keeperRoot: keeperRoot,
            upserts: keyUpserts,
            keeping: retainedKeyIDs
        )
        try providerUsageConfigurationStore.save(
            configurations,
            keeperRoot: keeperRoot
        )
        if let providers = providers.value {
            await refreshProviderUsage(
                using: providers,
                generation: connectionGeneration
            )
        }
    }

    func providerUsageSettingsBlockReason(for proposedBaseURL: String) -> String? {
        guard isAuthenticated,
              let root = try? CPAServiceRoot(proposedBaseURL),
              root.url.absoluteString == baseURL else {
            return "请先应用 Keeper 地址并重新打开设置"
        }
        guard providers.value?.hasAuthoritativeIdentities == true else {
            return "供应商列表尚未加载，暂不能修改用量配置"
        }
        return nil
    }

    func applySettings(
        baseURL: String,
        password: String,
        usageRange: UsageTimeRange,
        refreshFrequency: RefreshFrequency,
        launchAtLogin: Bool,
        consentToInsecureHTTP: Bool = false
    ) async throws {
        let root = try CPAServiceRoot(baseURL)
        let normalizedURL = root.url.absoluteString
        guard !root.requiresInsecureHTTPConsent
                || insecureHTTPConsentStore.contains(normalizedURL)
                || consentToInsecureHTTP else {
            throw SettingsApplicationError.insecureHTTPConsentRequired
        }
        let previousCredentialStore = normalizedURL == self.baseURL ? nil : credentialStore
        try updateMonitoringPreferences(
            usageRange: usageRange,
            refreshFrequency: refreshFrequency,
            launchAtLogin: launchAtLogin
        )
        if normalizedURL != self.baseURL {
            try await updateBaseURL(normalizedURL)
        }
        await login(password: password)
        guard isAuthenticated else {
            throw SettingsApplicationError.loginFailed(
                loginError ?? "管理员登录失败"
            )
        }
        if root.requiresInsecureHTTPConsent, consentToInsecureHTTP {
            insecureHTTPConsentStore.record(normalizedURL)
        }
        try await previousCredentialStore?.deletePassword()
    }

    private func resolvedProviderUsageKey(
        for draft: ProviderUsageDraft,
        keeperRoot: String? = nil
    ) async throws -> String {
        let enteredKey = draft.enteredKey.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !enteredKey.isEmpty { return enteredKey }
        let scope = ProviderUsageScope(
            keeperRoot: keeperRoot ?? baseURL,
            providerID: draft.providerID
        )
        guard let savedKey = try await providerUsageCredentialStore.loadKey(
            scope: scope
        ), !savedKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProviderUsageError.missingKey
        }
        return savedKey
    }

    private func configuration(
        from draft: ProviderUsageDraft
    ) -> ProviderUsageConfiguration {
        ProviderUsageConfiguration(
            providerID: draft.providerID,
            baseURL: draft.baseURL.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            isEnabled: draft.isEnabled
        )
    }

    private func providerUsageDisplayName(
        _ provider: CPAModels.UsageIdentity
    ) -> String {
        [provider.displayName, provider.name, provider.provider, provider.id]
            .compactMap { value in
                let trimmed = value?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ) ?? ""
                return trimmed.isEmpty ? nil : trimmed
            }
            .first ?? provider.id
    }
}

private enum SettingsApplicationError: LocalizedError {
    case loginFailed(String)
    case insecureHTTPConsentRequired

    var errorDescription: String? {
        switch self {
        case let .loginFailed(message): message
        case .insecureHTTPConsentRequired:
            "远程 HTTP 不会加密管理员密码，请先确认仅在可信网络中使用"
        }
    }
}
