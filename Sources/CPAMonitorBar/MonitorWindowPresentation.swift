import Combine

@MainActor
final class MonitorWindowPresentation: ObservableObject {
    static let pinnedWindowID = "pinned-monitor"

    @Published private(set) var isPinned = false
    @Published var selectedTab = MonitorTab.overview

    func pin() {
        isPinned = true
    }

    func unpin() {
        isPinned = false
    }
}
