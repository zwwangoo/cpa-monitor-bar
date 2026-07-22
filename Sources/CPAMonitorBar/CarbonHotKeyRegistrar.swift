import Carbon.HIToolbox
import Foundation

func carbonModifiers(_ modifiers: GlobalShortcutModifiers) -> UInt32 {
    var result: UInt32 = 0
    if modifiers.contains(.command) { result |= UInt32(cmdKey) }
    if modifiers.contains(.option) { result |= UInt32(optionKey) }
    if modifiers.contains(.control) { result |= UInt32(controlKey) }
    if modifiers.contains(.shift) { result |= UInt32(shiftKey) }
    return result
}

@MainActor
final class CarbonHotKeyRegistrar: GlobalHotKeyRegistering {
    private static let signature: OSType = 0x4350_414D // CPAM
    private static let identifier: UInt32 = 1
    private static let eventHandler: EventHandlerUPP = { _, _, context in
        guard let context else { return OSStatus(eventNotHandledErr) }
        let registrar = Unmanaged<CarbonHotKeyRegistrar>
            .fromOpaque(context)
            .takeUnretainedValue()
        Task { @MainActor in registrar.handleTrigger() }
        return noErr
    }

    private var hotKeyReference: EventHotKeyRef?
    private var eventHandlerReference: EventHandlerRef?
    private var onTrigger: (() -> Void)?

    func register(
        _ shortcut: GlobalShortcut,
        onTrigger: @escaping () -> Void
    ) throws {
        unregister()
        try installEventHandlerIfNeeded()
        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(
            signature: Self.signature,
            id: Self.identifier
        )
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            carbonModifiers(shortcut.modifiers),
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else {
            throw GlobalShortcutError.registrationFailed
        }
        hotKeyReference = reference
        self.onTrigger = onTrigger
    }

    func unregister() {
        if let hotKeyReference { UnregisterEventHotKey(hotKeyReference) }
        hotKeyReference = nil
        onTrigger = nil
    }

    deinit {
        if let hotKeyReference { UnregisterEventHotKey(hotKeyReference) }
        if let eventHandlerReference { RemoveEventHandler(eventHandlerReference) }
    }

    private func installEventHandlerIfNeeded() throws {
        guard eventHandlerReference == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var reference: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &reference
        )
        guard status == noErr, let reference else {
            throw GlobalShortcutError.registrationFailed
        }
        eventHandlerReference = reference
    }

    private func handleTrigger() { onTrigger?() }
}

extension GlobalShortcutController {
    convenience init() {
        self.init(
            store: UserDefaultsGlobalShortcutStore(),
            registrar: CarbonHotKeyRegistrar()
        )
    }
}
