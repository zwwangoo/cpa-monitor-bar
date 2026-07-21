import SwiftUI

@main
struct CPAMonitorBarApp: App {
    @StateObject private var model = MonitorViewModel()
    @StateObject private var windowPresentation = MonitorWindowPresentation()

    var body: some Scene {
        MenuBarExtra {
            MonitorPopover(
                model: model,
                windowPresentation: windowPresentation,
                presentationMode: .menuBar
            )
        } label: {
            Label(model.statusText, systemImage: model.statusSymbol)
                .task { await model.start() }
        }
        .menuBarExtraStyle(.window)

        Window("CPA Monitor Bar", id: MonitorWindowPresentation.pinnedWindowID) {
            MonitorPopover(
                model: model,
                windowPresentation: windowPresentation,
                presentationMode: .pinned
            )
            .ignoresSafeArea(.container, edges: .top)
            .background(PinnedMonitorWindowAccessor())
            .onDisappear { windowPresentation.unpin() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)

        Settings {
            SettingsView(model: model)
        }
    }
}
