import Foundation

func applicationVersionText(shortVersion: String?, buildVersion: String?) -> String {
    guard let shortVersion = normalizedVersionPart(shortVersion) else {
        return "开发构建"
    }
    guard let buildVersion = normalizedVersionPart(buildVersion) else {
        return shortVersion
    }
    return "\(shortVersion) (\(buildVersion))"
}

func currentApplicationVersion(bundle: Bundle = .main) -> String {
    applicationVersionText(
        shortVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
        buildVersion: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
    )
}

private func normalizedVersionPart(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty else { return nil }
    return value
}
