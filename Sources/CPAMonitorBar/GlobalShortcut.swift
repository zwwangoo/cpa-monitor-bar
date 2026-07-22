import Foundation

struct GlobalShortcutModifiers: OptionSet, Codable, Equatable, Sendable {
    let rawValue: UInt32

    static let command = Self(rawValue: 1 << 0)
    static let option = Self(rawValue: 1 << 1)
    static let control = Self(rawValue: 1 << 2)
    static let shift = Self(rawValue: 1 << 3)

    init(rawValue: UInt32) { self.rawValue = rawValue }

    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(UInt32.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct GlobalShortcut: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: GlobalShortcutModifiers
    let keyLabel: String
}

enum GlobalShortcutError: LocalizedError, Equatable {
    case registrationFailed

    var errorDescription: String? {
        "快捷键已被其他应用占用，请换一个组合键"
    }
}

@MainActor
protocol GlobalShortcutStoring: AnyObject {
    func loadShortcut() -> GlobalShortcut?
    func saveShortcut(_ shortcut: GlobalShortcut?)
}

@MainActor
final class UserDefaultsGlobalShortcutStore: GlobalShortcutStoring {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "globalShortcut") {
        self.defaults = defaults
        self.key = key
    }

    func loadShortcut() -> GlobalShortcut? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(GlobalShortcut.self, from: data)
    }

    func saveShortcut(_ shortcut: GlobalShortcut?) {
        guard let shortcut else {
            defaults.removeObject(forKey: key)
            return
        }
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        defaults.set(data, forKey: key)
    }
}

@MainActor
protocol GlobalHotKeyRegistering: AnyObject {
    func register(_ shortcut: GlobalShortcut, onTrigger: @escaping () -> Void) throws
    func unregister()
}

@MainActor
final class GlobalShortcutController {
    private let store: any GlobalShortcutStoring
    private let registrar: any GlobalHotKeyRegistering
    private var onTrigger: (() -> Void)?
    private var started = false
    private var suspended = false

    private(set) var shortcut: GlobalShortcut?
    private(set) var registrationError: String?

    init(
        store: any GlobalShortcutStoring,
        registrar: any GlobalHotKeyRegistering
    ) {
        self.store = store
        self.registrar = registrar
        shortcut = store.loadShortcut()
    }

    func start(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        started = true
        guard let shortcut else { return }
        do {
            try register(shortcut)
            registrationError = nil
        } catch {
            registrationError = error.localizedDescription
        }
    }

    func apply(_ next: GlobalShortcut?) throws {
        if next == shortcut {
            if suspended { try resume() }
            return
        }
        let previous = shortcut
        if started, !suspended { registrar.unregister() }
        do {
            if started, let next { try register(next) }
        } catch {
            restoreRegistration(previous)
            registrationError = error.localizedDescription
            throw error
        }
        shortcut = next
        store.saveShortcut(next)
        suspended = false
        registrationError = nil
    }

    func suspend() {
        guard started, !suspended else { return }
        registrar.unregister()
        suspended = true
    }

    func resume() throws {
        guard started, suspended else { return }
        if let shortcut { try register(shortcut) }
        suspended = false
        registrationError = nil
    }

    private func register(_ shortcut: GlobalShortcut) throws {
        try registrar.register(shortcut) { [weak self] in
            self?.onTrigger?()
        }
    }

    private func restoreRegistration(_ previous: GlobalShortcut?) {
        registrar.unregister()
        if started, let previous { try? register(previous) }
        suspended = false
    }
}
