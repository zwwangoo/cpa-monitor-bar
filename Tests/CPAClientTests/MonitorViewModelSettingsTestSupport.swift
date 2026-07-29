import CPAClient
@testable import CPAMonitorBar

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
}
