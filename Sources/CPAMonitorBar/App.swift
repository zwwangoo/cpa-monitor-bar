import AppKit
import SwiftUI

@main
struct CPAMonitorBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(
                model: appDelegate.model,
                shortcutController: appDelegate.globalShortcutController
            )
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = MonitorViewModel()
    let windowPresentation = MonitorWindowPresentation()
    let globalShortcutController = GlobalShortcutController()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let statusBarController = StatusBarController(
            model: model,
            presentation: windowPresentation
        )
        self.statusBarController = statusBarController
        globalShortcutController.start { [weak statusBarController] in
            statusBarController?.togglePanel(anchor: .pointer)
        }
        Task { await model.start() }
    }
}
