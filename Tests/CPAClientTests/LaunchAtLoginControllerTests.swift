import ServiceManagement
import XCTest
@testable import CPAMonitorBar

@MainActor
final class LaunchAtLoginControllerTests: XCTestCase {
    func testNotFoundStatusStillAttemptsRegistration() throws {
        let service = FakeAppService(status: .notFound)
        let controller = LaunchAtLoginController(service: service)

        try controller.setEnabled(true)

        XCTAssertEqual(service.registerCount, 1)
        XCTAssertTrue(controller.isEnabled)
    }
}

@MainActor
private final class FakeAppService: AppServiceControlling {
    var status: SMAppService.Status
    private(set) var registerCount = 0

    init(status: SMAppService.Status) { self.status = status }

    func register() throws {
        registerCount += 1
        status = .enabled
    }

    func unregister() throws {
        status = .notRegistered
    }
}
