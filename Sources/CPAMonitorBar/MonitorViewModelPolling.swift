import Foundation

extension MonitorViewModel {
    func startPolling() {
        pollingTask?.cancel()
        guard configurationState == .configured else { return }
        let interval = pollingIntervalOverride ?? refreshFrequency.duration
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: interval) }
                catch { return }
                guard let self else { return }
                await self.refresh()
            }
        }
    }
}
