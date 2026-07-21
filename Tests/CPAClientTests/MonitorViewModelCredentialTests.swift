import XCTest
@testable import CPAMonitorBar

@MainActor
final class MonitorViewModelCredentialTests: XCTestCase {
    func testStartAutomaticallyLogsInWithSavedPassword() async {
        let client = CountingClient(authenticated: false)
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client],
            savedPassword: "saved-secret"
        )
        let model = dependencies.makeModel()

        await model.start()
        let loginPasswords = await client.loginPasswords

        XCTAssertTrue(model.isAuthenticated)
        XCTAssertEqual(loginPasswords, ["saved-secret"])
        XCTAssertEqual(dependencies.credentialFactory.store.loadCount, 1)
    }

    func testEmptyPasswordLoadsSavedPasswordWithoutReplacingIt() async {
        let client = CountingClient(authenticated: false)
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [client],
            savedPassword: "saved-secret"
        )
        let model = dependencies.makeModel()

        await model.login(password: "")

        XCTAssertTrue(model.isAuthenticated)
        XCTAssertEqual(dependencies.credentialFactory.store.loadCount, 1)
        XCTAssertEqual(
            dependencies.credentialFactory.store.savedPassword,
            "saved-secret"
        )
        let loginPasswords = await client.loginPasswords
        XCTAssertEqual(loginPasswords, ["saved-secret"])
    }
}
