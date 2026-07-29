import Foundation
import CPAClient
import CPAModels

extension MonitorViewModel {
    var canLoadMoreEvents: Bool {
        guard let response = events.value, !response.events.isEmpty else { return false }
        if let page = response.page, let totalPages = response.totalPages {
            return page < totalPages
        }
        if let totalCount = response.totalCount {
            return response.events.count < totalCount
        }
        return response.events.count >= Self.eventsPageSize
    }

    func loadMoreEvents() async {
        guard let client,
              isAuthenticated,
              !isRefreshing,
              !isLoadingMoreEvents,
              canLoadMoreEvents,
              let current = events.value else { return }
        let requestedRange = usageRange
        let generation = eventsPageGeneration
        let nextPage = max((current.page ?? 1) + 1, 2)
        isLoadingMoreEvents = true
        eventsLoadMoreError = nil
        do {
            let next = try await client.events(
                range: requestedRange,
                page: nextPage,
                pageSize: Self.eventsPageSize
            )
            guard generation == eventsPageGeneration, requestedRange == usageRange else {
                isLoadingMoreEvents = false
                return
            }
            events.value = mergedEvents(
                current,
                next,
                requestedPage: nextPage,
                defaultPageSize: Self.eventsPageSize
            )
            markUpdated()
            events.errorMessage = nil
        } catch {
            guard generation == eventsPageGeneration else { return }
            eventsLoadMoreError = displayMessage(error)
            if error as? CPAClientError == .authenticationRequired {
                isAuthenticated = false
            }
        }
        isLoadingMoreEvents = false
    }
}

private func mergedEvents(
    _ current: UsageEventsResponse,
    _ next: UsageEventsResponse,
    requestedPage: Int,
    defaultPageSize: Int
) -> UsageEventsResponse {
    var seen = Set(current.events.map(eventStableKey))
    var merged = current.events
    for event in next.events where seen.insert(eventStableKey(event)).inserted {
        merged.append(event)
    }
    return UsageEventsResponse(
        events: merged,
        totalCount: next.totalCount ?? current.totalCount,
        page: max(current.page ?? 1, next.page ?? requestedPage),
        pageSize: next.pageSize ?? current.pageSize ?? defaultPageSize,
        totalPages: next.totalPages ?? current.totalPages
    )
}

private func eventStableKey(_ event: UsageEvent) -> String {
    if let id = event.id?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty {
        return "id:\(id)"
    }
    return [
        event.timestamp, event.apiKey, event.source, event.model,
        event.endpoint, event.ttftMS.map(String.init), event.latencyMS.map(String.init),
    ]
    .map { $0 ?? "" }
    .joined(separator: "|")
}
