import Foundation
import ServiceManagement

@MainActor
protocol LaunchAtLoginControlling: AnyObject {
    var isEnabled: Bool { get }
    func setEnabled(_ enabled: Bool) throws
}

@MainActor
protocol AppServiceControlling: AnyObject {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
}

@MainActor
private final class SystemAppService: AppServiceControlling {
    private let service = SMAppService.mainApp

    var status: SMAppService.Status { service.status }
    func register() throws { try service.register() }
    func unregister() throws { try service.unregister() }
}

@MainActor
final class LaunchAtLoginController: LaunchAtLoginControlling {
    private let service: any AppServiceControlling

    init(service: (any AppServiceControlling)? = nil) {
        self.service = service ?? SystemAppService()
    }

    var isEnabled: Bool {
        service.status == .enabled || service.status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            switch service.status {
            case .notRegistered, .notFound:
                try service.register()
            case .enabled, .requiresApproval:
                break
            @unknown default:
                throw LaunchAtLoginError.unknownStatus
            }
        } else {
            switch service.status {
            case .enabled, .requiresApproval:
                try service.unregister()
            case .notRegistered, .notFound:
                break
            @unknown default:
                throw LaunchAtLoginError.unknownStatus
            }
        }
    }
}

private enum LaunchAtLoginError: LocalizedError {
    case unknownStatus

    var errorDescription: String? {
        switch self {
        case .unknownStatus: "无法读取开机启动状态"
        }
    }
}
