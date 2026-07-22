import AppKit
import SwiftUI

func isValidGlobalShortcutModifiers(
    _ modifiers: GlobalShortcutModifiers
) -> Bool {
    !modifiers.intersection([.command, .option, .control]).isEmpty
}

func globalShortcutModifiers(
    from flags: NSEvent.ModifierFlags
) -> GlobalShortcutModifiers {
    var result: GlobalShortcutModifiers = []
    if flags.contains(.command) { result.insert(.command) }
    if flags.contains(.option) { result.insert(.option) }
    if flags.contains(.control) { result.insert(.control) }
    if flags.contains(.shift) { result.insert(.shift) }
    return result
}

func shortcutDisplayText(_ shortcut: GlobalShortcut?) -> String {
    guard let shortcut else { return "未设置" }
    var result = ""
    if shortcut.modifiers.contains(.control) { result += "⌃" }
    if shortcut.modifiers.contains(.option) { result += "⌥" }
    if shortcut.modifiers.contains(.shift) { result += "⇧" }
    if shortcut.modifiers.contains(.command) { result += "⌘" }
    return result + shortcut.keyLabel
}

func shortcutKeyLabel(keyCode: UInt16, characters: String?) -> String? {
    switch keyCode {
    case ShortcutKeyCode.space: return "Space"
    case ShortcutKeyCode.returnKey: return "↩"
    case ShortcutKeyCode.tab: return "⇥"
    case ShortcutKeyCode.left: return "←"
    case ShortcutKeyCode.right: return "→"
    case ShortcutKeyCode.down: return "↓"
    case ShortcutKeyCode.up: return "↑"
    default:
        guard let value = characters?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value.uppercased()
    }
}

struct ShortcutRecorder: View {
    @Binding var shortcut: GlobalShortcut?
    let onRecordingChanged: (Bool) -> Void

    @State private var isRecording = false
    @State private var eventMonitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggleRecording) {
                Text(isRecording ? "请按下组合键…" : shortcutDisplayText(shortcut))
                    .monospacedDigit()
                    .frame(minWidth: 118)
            }
            .help("至少包含 Command、Option 或 Control 之一")

            Button(action: clearShortcut) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(shortcut == nil)
            .help("清除全局快捷键")
        }
        .onDisappear { finishRecording() }
    }

    private func toggleRecording() {
        isRecording ? finishRecording() : beginRecording()
    }

    private func beginRecording() {
        guard !isRecording else { return }
        isRecording = true
        onRecordingChanged(true)
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyDown(event)
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        if event.keyCode == ShortcutKeyCode.escape {
            finishRecording()
            return nil
        }
        if ShortcutKeyCode.deleteKeys.contains(event.keyCode) {
            shortcut = nil
            finishRecording()
            return nil
        }
        let modifiers = globalShortcutModifiers(from: event.modifierFlags)
        guard isValidGlobalShortcutModifiers(modifiers),
              let label = shortcutKeyLabel(
                keyCode: event.keyCode,
                characters: event.charactersIgnoringModifiers
              ) else {
            NSSound.beep()
            return nil
        }
        shortcut = GlobalShortcut(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers,
            keyLabel: label
        )
        finishRecording()
        return nil
    }

    private func clearShortcut() {
        shortcut = nil
        finishRecording()
    }

    private func finishRecording() {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
        eventMonitor = nil
        guard isRecording else { return }
        isRecording = false
        onRecordingChanged(false)
    }
}

private enum ShortcutKeyCode {
    static let returnKey: UInt16 = 36
    static let tab: UInt16 = 48
    static let space: UInt16 = 49
    static let delete: UInt16 = 51
    static let escape: UInt16 = 53
    static let forwardDelete: UInt16 = 117
    static let left: UInt16 = 123
    static let right: UInt16 = 124
    static let down: UInt16 = 125
    static let up: UInt16 = 126
    static let deleteKeys: Set<UInt16> = [delete, forwardDelete]
}
