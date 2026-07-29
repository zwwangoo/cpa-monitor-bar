import Foundation

extension MonitorViewModel {
    var statusText: String {
        if configurationState == .unconfigured { return "尚未配置" }
        if health.isLoading && health.value == nil { return "连接中" }
        if health.errorMessage != nil { return "离线" }
        if !isAuthenticated { return "未登录" }
        if keeperStatus.value?.running == false || keeperStatus.errorMessage != nil {
            return "服务异常"
        }
        return "运行中"
    }

    var statusSymbol: String {
        if configurationState == .unconfigured { return "gear.badge.questionmark" }
        if health.errorMessage != nil
            || keeperStatus.value?.running == false
            || keeperStatus.errorMessage != nil {
            return "exclamationmark.triangle.fill"
        }
        if !isAuthenticated { return "lock.fill" }
        return "waveform.path.ecg"
    }
}
