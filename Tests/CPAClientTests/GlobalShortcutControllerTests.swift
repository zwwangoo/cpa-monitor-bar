import XCTest
@testable import CPAMonitorBar

@MainActor
final class GlobalShortcutControllerTests: XCTestCase {
    func testUserDefaultsStoreRoundTripsAndClearsShortcut() throws {
        let suiteName = "GlobalShortcutControllerTests.\(UUID().uuidString)"
        let suite = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { suite.removePersistentDomain(forName: suiteName) }
        let store = UserDefaultsGlobalShortcutStore(defaults: suite)
        let shortcut = makeShortcut(keyCode: 8, modifiers: [.command], label: "C")

        store.saveShortcut(shortcut)
        XCTAssertEqual(store.loadShortcut(), shortcut)

        store.saveShortcut(nil)
        XCTAssertNil(store.loadShortcut())
    }

    func testStartWithoutSavedShortcutDoesNotRegister() {
        let registrar = RecordingGlobalHotKeyRegistrar()
        let controller = GlobalShortcutController(
            store: MemoryGlobalShortcutStore(),
            registrar: registrar
        )

        controller.start(onTrigger: {})

        XCTAssertEqual(registrar.registered, [])
    }

    func testStartRegistersSavedShortcutAndForwardsTrigger() {
        let shortcut = makeShortcut(keyCode: 8, modifiers: [.command], label: "C")
        let registrar = RecordingGlobalHotKeyRegistrar()
        var triggerCount = 0
        let controller = GlobalShortcutController(
            store: MemoryGlobalShortcutStore(shortcut: shortcut),
            registrar: registrar
        )

        controller.start { triggerCount += 1 }
        registrar.trigger()

        XCTAssertEqual(registrar.registered, [shortcut])
        XCTAssertEqual(triggerCount, 1)
    }

    func testApplyPersistsAndReplacesShortcut() throws {
        let old = makeShortcut(keyCode: 8, modifiers: [.command], label: "C")
        let new = makeShortcut(keyCode: 9, modifiers: [.option], label: "V")
        let store = MemoryGlobalShortcutStore(shortcut: old)
        let registrar = RecordingGlobalHotKeyRegistrar()
        let controller = GlobalShortcutController(store: store, registrar: registrar)
        controller.start(onTrigger: {})

        try controller.apply(new)

        XCTAssertEqual(controller.shortcut, new)
        XCTAssertEqual(store.shortcut, new)
        XCTAssertEqual(registrar.registered, [old, new])
        XCTAssertEqual(registrar.unregisterCount, 1)
    }

    func testClearUnregistersAndRemovesSavedShortcut() throws {
        let old = makeShortcut(keyCode: 8, modifiers: [.command], label: "C")
        let store = MemoryGlobalShortcutStore(shortcut: old)
        let registrar = RecordingGlobalHotKeyRegistrar()
        let controller = GlobalShortcutController(store: store, registrar: registrar)
        controller.start(onTrigger: {})

        try controller.apply(nil)

        XCTAssertNil(controller.shortcut)
        XCTAssertNil(store.shortcut)
        XCTAssertEqual(registrar.unregisterCount, 1)
    }

    func testRegistrationFailureRestoresOldShortcut() {
        let old = makeShortcut(keyCode: 8, modifiers: [.command], label: "C")
        let rejected = makeShortcut(keyCode: 9, modifiers: [.option], label: "V")
        let store = MemoryGlobalShortcutStore(shortcut: old)
        let registrar = RecordingGlobalHotKeyRegistrar(rejected: rejected)
        let controller = GlobalShortcutController(store: store, registrar: registrar)
        controller.start(onTrigger: {})

        XCTAssertThrowsError(try controller.apply(rejected))

        XCTAssertEqual(controller.shortcut, old)
        XCTAssertEqual(store.shortcut, old)
        XCTAssertEqual(registrar.registered, [old, rejected, old])
    }

    func testSuspendAndResumeTemporarilyUnregisterCurrentShortcut() throws {
        let shortcut = makeShortcut(keyCode: 8, modifiers: [.control], label: "C")
        let registrar = RecordingGlobalHotKeyRegistrar()
        let controller = GlobalShortcutController(
            store: MemoryGlobalShortcutStore(shortcut: shortcut),
            registrar: registrar
        )
        controller.start(onTrigger: {})

        controller.suspend()
        try controller.resume()

        XCTAssertEqual(registrar.unregisterCount, 1)
        XCTAssertEqual(registrar.registered, [shortcut, shortcut])
    }
}

@MainActor
private final class MemoryGlobalShortcutStore: GlobalShortcutStoring {
    private(set) var shortcut: GlobalShortcut?

    init(shortcut: GlobalShortcut? = nil) { self.shortcut = shortcut }

    func loadShortcut() -> GlobalShortcut? { shortcut }
    func saveShortcut(_ shortcut: GlobalShortcut?) { self.shortcut = shortcut }
}

@MainActor
private final class RecordingGlobalHotKeyRegistrar: GlobalHotKeyRegistering {
    private let rejected: GlobalShortcut?
    private var onTrigger: (() -> Void)?
    private(set) var registered: [GlobalShortcut] = []
    private(set) var unregisterCount = 0

    init(rejected: GlobalShortcut? = nil) { self.rejected = rejected }

    func register(_ shortcut: GlobalShortcut, onTrigger: @escaping () -> Void) throws {
        registered.append(shortcut)
        if shortcut == rejected { throw GlobalShortcutError.registrationFailed }
        self.onTrigger = onTrigger
    }

    func unregister() {
        unregisterCount += 1
        onTrigger = nil
    }

    func trigger() { onTrigger?() }
}

private func makeShortcut(
    keyCode: UInt32,
    modifiers: GlobalShortcutModifiers,
    label: String
) -> GlobalShortcut {
    GlobalShortcut(keyCode: keyCode, modifiers: modifiers, keyLabel: label)
}
