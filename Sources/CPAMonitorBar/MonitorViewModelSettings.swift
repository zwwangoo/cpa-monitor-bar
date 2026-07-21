import Foundation
import CPAClient

extension MonitorViewModel {
    func applySettings(baseURL: String, password: String) async throws {
        try await applySettings(
            baseURL: baseURL,
            password: password,
            usageRange: usageRange,
            refreshFrequency: refreshFrequency,
            launchAtLogin: launchAtLoginEnabled
        )
    }

    func applySettings(
        baseURL: String,
        password: String,
        usageRange: UsageTimeRange,
        refreshFrequency: RefreshFrequency,
        launchAtLogin: Bool
    ) async throws {
        let normalizedURL = try CPAServiceRoot(baseURL).url.absoluteString
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
    }
}

private enum SettingsApplicationError: LocalizedError {
    case loginFailed(String)

    var errorDescription: String? {
        switch self {
        case let .loginFailed(message): message
        }
    }
}
