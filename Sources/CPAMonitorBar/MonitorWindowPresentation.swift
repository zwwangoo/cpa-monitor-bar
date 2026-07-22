import AppKit
import Combine

@MainActor
final class MonitorWindowPresentation: ObservableObject {
    @Published private(set) var isPinned = false
    @Published var selectedTab = MonitorTab.overview

    func pin() {
        isPinned = true
    }

    func unpin() {
        isPinned = false
    }

    func togglePin() {
        isPinned.toggle()
    }
}

@MainActor
func configureMonitorPopover(_ popover: NSPopover, isPinned: Bool) {
    popover.behavior = isPinned ? .applicationDefined : .transient
}
