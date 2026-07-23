import AppKit
import SwiftUI

typealias SettingsPresentationAction = @MainActor @Sendable () -> Void

@MainActor
struct SettingsPresentationActions {
    let bringToFront: SettingsPresentationAction
    let deferAction: (@escaping SettingsPresentationAction) -> Void

    static let live = Self(
        bringToFront: { bringSettingsToFront() },
        deferAction: { action in DispatchQueue.main.async(execute: action) }
    )
}

@MainActor
func presentSettings(
    openSettings: () -> Void
) {
    presentSettings(openSettings: openSettings, actions: .live)
}

@MainActor
func presentSettings(
    openSettings: () -> Void,
    actions: SettingsPresentationActions
) {
    openSettings()
    actions.bringToFront()
    actions.deferAction(actions.bringToFront)
}

@MainActor
func bringSettingsToFront() {
    NSApp.activate(ignoringOtherApps: true)
    guard let window = settingsWindowCandidate(in: NSApp.windows) else { return }
    window.makeKeyAndOrderFront(nil)
    window.orderFrontRegardless()
}

@MainActor
func settingsWindowCandidate(in windows: [NSWindow]) -> NSWindow? {
    windows.first {
        $0.isVisible
            && $0.canBecomeKey
            && !($0 is NSPanel)
    }
}

@MainActor
struct ForegroundSettingsLink<Label: View>: View {
    @Environment(\.openSettings) private var openSettings
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button {
            presentSettings(openSettings: { openSettings() })
        } label: {
            label()
        }
    }
}
