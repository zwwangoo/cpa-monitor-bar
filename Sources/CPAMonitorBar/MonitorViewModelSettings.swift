import Foundation
import CPAClient

extension MonitorViewModel {
    func applySettings(
        baseURL: String,
        password: String,
        consentToInsecureHTTP: Bool = false
    ) async throws {
        try await applySettings(
            baseURL: baseURL,
            password: password,
            usageRange: usageRange,
            refreshFrequency: refreshFrequency,
            launchAtLogin: launchAtLoginEnabled,
            consentToInsecureHTTP: consentToInsecureHTTP
        )
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
        try previousCredentialStore?.deletePassword()
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
