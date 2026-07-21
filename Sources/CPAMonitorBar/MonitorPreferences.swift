import Foundation
import CPAClient

enum RefreshFrequency: Int, CaseIterable, Identifiable, Sendable {
    case thirtySeconds = 30
    case oneMinute = 60
    case twoMinutes = 120
    case fiveMinutes = 300

    var id: Int { rawValue }
    var duration: Duration { .seconds(rawValue) }

    var title: String {
        switch self {
        case .thirtySeconds: "30 秒"
        case .oneMinute: "1 分钟"
        case .twoMinutes: "2 分钟"
        case .fiveMinutes: "5 分钟"
        }
    }
}

extension UsageTimeRange {
    var title: String {
        switch self {
        case .last8Hours: "最近 8 小时"
        case .today: "今天"
        case .yesterday: "昨天"
        }
    }
}

struct MonitorPreferences: Equatable, Sendable {
    var usageRange: UsageTimeRange = .today
    var refreshFrequency: RefreshFrequency = .oneMinute
}

protocol MonitorPreferencesStoring: AnyObject {
    func load() -> MonitorPreferences
    func save(_ preferences: MonitorPreferences)
}

final class UserDefaultsMonitorPreferencesStore: MonitorPreferencesStoring {
    private let defaults: UserDefaults
    private let rangeKey: String
    private let refreshKey: String

    init(
        defaults: UserDefaults = .standard,
        rangeKey: String = "usageTimeRange",
        refreshKey: String = "refreshFrequencySeconds"
    ) {
        self.defaults = defaults
        self.rangeKey = rangeKey
        self.refreshKey = refreshKey
    }

    func load() -> MonitorPreferences {
        let range = defaults.string(forKey: rangeKey)
            .flatMap(UsageTimeRange.init(rawValue:)) ?? .today
        let frequency = RefreshFrequency(rawValue: defaults.integer(forKey: refreshKey))
            ?? .oneMinute
        return MonitorPreferences(usageRange: range, refreshFrequency: frequency)
    }

    func save(_ preferences: MonitorPreferences) {
        defaults.set(preferences.usageRange.rawValue, forKey: rangeKey)
        defaults.set(preferences.refreshFrequency.rawValue, forKey: refreshKey)
    }
}
