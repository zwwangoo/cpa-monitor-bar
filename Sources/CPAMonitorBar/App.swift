import AppKit
import SwiftUI

@main
struct CPAMonitorBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(model: appDelegate.model)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = MonitorViewModel()
    let windowPresentation = MonitorWindowPresentation()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(
            model: model,
            presentation: windowPresentation
        )
        Task { await model.start() }
    }
}
