import CPAModels

extension MonitorViewModel {
    func refreshProviderUsage(
        using response: UsageIdentitiesPageResponse,
        generation: Int
    ) async {
        guard response.hasAuthoritativeIdentities else { return }
        let keeperRoot = baseURL
        let providerIDs = response.identities.map(\.id)
        let currentProviderIDs = Set(providerIDs)
        let configurations: [ProviderUsageConfiguration]
        do {
            configurations = try providerUsageConfigurationStore.load(
                keeperRoot: keeperRoot
            )
        } catch {
            for providerID in providerUsageStates.keys {
                providerUsageStates[providerID]?.isLoading = false
                providerUsageStates[providerID]?.errorMessage =
                    error.localizedDescription
            }
            return
        }
        let enabledProviderIDs = Set(configurations.filter {
            $0.isEnabled && currentProviderIDs.contains($0.providerID)
        }.map(\.providerID))
        providerUsageRefreshGeneration += 1
        let refreshGeneration = providerUsageRefreshGeneration

        providerUsageStates = providerUsageStates.filter {
            enabledProviderIDs.contains($0.key)
        }
        guard !enabledProviderIDs.isEmpty else {
            providerUsageTask?.cancel()
            providerUsageTask = nil
            return
        }

        let previousStateIDs = Set(providerUsageStates.keys)
        for providerID in enabledProviderIDs {
            var state = providerUsageStates[providerID] ?? ProviderUsageState()
            state.isLoading = true
            providerUsageStates[providerID] = state
        }

        providerUsageTask?.cancel()
        let monitor = providerUsageMonitor
        let task = Task {
            await monitor.refresh(
                keeperRoot: keeperRoot,
                providerIDs: providerIDs
            )
        }
        providerUsageTask = task
        let results = await task.value
        guard isCurrent(generation),
              keeperRoot == baseURL,
              refreshGeneration == providerUsageRefreshGeneration else {
            return
        }
        providerUsageTask = nil

        for providerID in enabledProviderIDs {
            guard let result = results[providerID] else {
                if previousStateIDs.contains(providerID) {
                    providerUsageStates[providerID]?.isLoading = false
                } else {
                    providerUsageStates.removeValue(forKey: providerID)
                }
                continue
            }

            var state = providerUsageStates[providerID] ?? ProviderUsageState()
            state.isLoading = false
            switch result {
            case let .success(snapshot):
                state.snapshot = snapshot
                state.errorMessage = nil
                markUpdated()
            case let .failure(error):
                state.errorMessage = error.localizedDescription
            }
            providerUsageStates[providerID] = state
        }
    }
}
