import Combine

@MainActor
final class MonitorWindowPresentation: ObservableObject {
    @Published private(set) var isPinned = false
    @Published var selectedTab = MonitorTab.overview

    func togglePin() {
        isPinned.toggle()
    }
}
