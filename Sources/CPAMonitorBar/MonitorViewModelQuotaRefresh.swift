import Foundation
import CPAClient
import CPAModels

private struct QuotaTaskPollResult: Sendable {
    let authIndex: String
    let result: SectionResult<UsageQuotaRefreshTaskResponse>
}

extension MonitorViewModel {
    static let maximumQuotaRefreshPolls = 60

    func refreshQuota(authIndexes: [String]) {
        let indexes = normalizedQuotaIndexes(authIndexes)
        guard let activeClient = client,
              isAuthenticated,
              !isRefreshingQuota,
              !indexes.isEmpty else { return }
        let generation = currentConnectionGeneration
        isRefreshingQuota = true
        quotaRefreshError = nil
        quotaRefreshTask = Task { [weak self] in
            await self?.performQuotaRefresh(
                indexes: indexes,
                using: activeClient,
                generation: generation
            )
        }
    }

    private func performQuotaRefresh(
        indexes: [String],
        using activeClient: any CPAServiceClient,
        generation: Int
    ) async {
        let batchResult = await capture { try await activeClient.refreshQuota(authIndexes: indexes) }
        guard isCurrent(generation), !Task.isCancelled else { return }
        guard case let .success(batch) = batchResult else {
            if case let .failure(error) = batchResult {
                handleQuotaRefreshError(error)
                finishQuotaRefresh(error.localizedDescription, generation: generation)
            }
            return
        }
        let duplicates = batch.rejected.filter { $0.error?.lowercased() == "duplicate" }
        var pending = Set(batch.tasks.map(\.authIndex) + duplicates.map(\.authIndex))
        var failedCount = batch.rejected.count - duplicates.count
        var pollCount = 0
        while !pending.isEmpty, pollCount < Self.maximumQuotaRefreshPolls {
            let results = await pollQuotaTasks(pending, using: activeClient)
            guard isCurrent(generation), !Task.isCancelled else { return }
            failedCount += applyPollResults(results, pending: &pending)
            pollCount += 1
            if !pending.isEmpty {
                do { try await Task.sleep(for: quotaRefreshPollingInterval) }
                catch { return }
            }
        }
        let timedOutCount = pending.count
        await reloadQuotaCache(using: activeClient, fallback: indexes, generation: generation)
        finishQuotaRefreshMessage(
            failedCount: failedCount,
            timedOutCount: timedOutCount,
            generation: generation
        )
    }

    private func pollQuotaTasks(
        _ indexes: Set<String>,
        using activeClient: any CPAServiceClient
    ) async -> [QuotaTaskPollResult] {
        await withTaskGroup(of: QuotaTaskPollResult.self) { group in
            for index in indexes {
                group.addTask {
                    let result = await capture {
                        try await activeClient.quotaRefreshStatus(authIndex: index)
                    }
                    return QuotaTaskPollResult(authIndex: index, result: result)
                }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }
    }

    private func applyPollResults(
        _ results: [QuotaTaskPollResult],
        pending: inout Set<String>
    ) -> Int {
        var failedCount = 0
        for item in results {
            switch item.result {
            case let .success(response):
                let status = response.status.lowercased()
                if status == "completed" { pending.remove(item.authIndex) }
                if status == "failed" {
                    pending.remove(item.authIndex)
                    failedCount += 1
                }
            case let .failure(error):
                handleQuotaRefreshError(error)
                pending.remove(item.authIndex)
                failedCount += 1
            }
        }
        return failedCount
    }

    private func reloadQuotaCache(
        using activeClient: any CPAServiceClient,
        fallback: [String],
        generation: Int
    ) async {
        let loaded = authFiles.value?.identities.compactMap(\.identity) ?? []
        let indexes = normalizedQuotaIndexes(loaded.isEmpty ? fallback : loaded)
        let result = await capture { try await activeClient.quotaCache(authIndexes: indexes) }
        guard isCurrent(generation), !Task.isCancelled else { return }
        quotaCache.isLoading = false
        switch result {
        case let .success(response):
            quotaCache.value = response
            quotaCache.errorMessage = nil
            quotaCache.updatedAt = .now
        case let .failure(error):
            quotaCache.errorMessage = error.localizedDescription
        }
    }

    private func finishQuotaRefreshMessage(
        failedCount: Int,
        timedOutCount: Int,
        generation: Int
    ) {
        let message: String?
        if timedOutCount > 0 {
            message = "额度刷新超时，\(timedOutCount) 个账号尚未完成"
        } else if failedCount > 0 {
            message = "\(failedCount) 个账号刷新失败"
        } else {
            message = nil
        }
        finishQuotaRefresh(message, generation: generation)
    }

    private func finishQuotaRefresh(_ message: String?, generation: Int) {
        guard isCurrent(generation) else { return }
        quotaRefreshError = message
        isRefreshingQuota = false
        quotaRefreshTask = nil
    }

    private func handleQuotaRefreshError(_ error: CPAClientError) {
        guard error == .authenticationRequired else { return }
        isAuthenticated = false
        loginError = error.localizedDescription
    }

    private func normalizedQuotaIndexes(_ indexes: [String]) -> [String] {
        var seen = Set<String>()
        return indexes.compactMap {
            let value = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return !value.isEmpty && seen.insert(value).inserted ? value : nil
        }
    }

    private var currentConnectionGeneration: Int { connectionGeneration }
}
