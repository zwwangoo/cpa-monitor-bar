import CPAClient
import OSLog

private let connectionLogger = Logger(
    subsystem: "top.wangzhiwen.CPAMonitorBar",
    category: "keeper-session"
)

extension MonitorViewModel {
    func updateBaseURL(_ value: String) async throws {
        let root = try CPAServiceRoot(value)
        pollingTask?.cancel()
        if isAuthenticated, let previousClient = client {
            do {
                try await previousClient.logout()
            } catch {
                connectionLogger.warning(
                    "旧 Keeper 会话注销失败：\(error.localizedDescription, privacy: .public)"
                )
            }
        }
        connectionGeneration += 1
        resetConnectionState()
        client = clientFactory(root)
        credentialStore = credentialStoreFactory(root)
        baseURL = root.url.absoluteString
        configurationState = .configured
        baseURLStore.saveBaseURL(baseURL)
        started = true
        startPolling()
        await refresh()
    }

    func hasInsecureHTTPConsent(for value: String) -> Bool {
        guard let root = try? CPAServiceRoot(value) else { return false }
        return insecureHTTPConsentStore.contains(root.url.absoluteString)
    }
}
