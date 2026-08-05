import Foundation

enum ProviderUsageRefreshResult: Equatable, Sendable {
    case success(ProviderUsageSnapshot)
    case failure(ProviderUsageError)
}

typealias ProviderUsageAdapterFactory = @Sendable (
    ProviderUsageConfiguration,
    ProviderUsageServiceRoot
) throws -> any ProviderUsageAdapter

protocol ProviderUsageMonitoring: Sendable {
    func refresh(
        keeperRoot: String,
        providerIDs: [String]
    ) async -> [String: ProviderUsageRefreshResult]

    func validate(
        configuration: ProviderUsageConfiguration,
        key: String
    ) async throws -> ProviderUsageSnapshot
}

struct ProviderUsageMonitor: ProviderUsageMonitoring, Sendable {
    private static let maximumConcurrentRequests = 3
    private static let liveAdapterFactory: ProviderUsageAdapterFactory = {
        _,
        root in
        Sub2APIUsageClient(root: root)
    }

    private let configurationStore: any ProviderUsageConfigurationStoring
    private let credentialStore: any ProviderUsageCredentialStoring
    private let adapterFactory: ProviderUsageAdapterFactory

    init(
        configurationStore: any ProviderUsageConfigurationStoring,
        credentialStore: any ProviderUsageCredentialStoring,
        adapterFactory: @escaping ProviderUsageAdapterFactory = Self.liveAdapterFactory
    ) {
        self.configurationStore = configurationStore
        self.credentialStore = credentialStore
        self.adapterFactory = adapterFactory
    }

    func refresh(
        keeperRoot: String,
        providerIDs: [String]
    ) async -> [String: ProviderUsageRefreshResult] {
        let currentProviderIDs = Set(providerIDs)
        let configurations: [ProviderUsageConfiguration]
        do {
            configurations = try configurationStore.load(keeperRoot: keeperRoot)
                .filter {
                    $0.isEnabled && currentProviderIDs.contains($0.providerID)
                }
        } catch {
            return [:]
        }
        var results: [String: ProviderUsageRefreshResult] = [:]

        for startIndex in stride(
            from: 0,
            to: configurations.count,
            by: Self.maximumConcurrentRequests
        ) {
            guard !Task.isCancelled else { break }
            let endIndex = min(
                startIndex + Self.maximumConcurrentRequests,
                configurations.count
            )
            let batch = Array(configurations[startIndex..<endIndex])
            let batchResults = await withTaskGroup(
                of: (String, ProviderUsageRefreshResult)?.self,
                returning: [(String, ProviderUsageRefreshResult)].self
            ) { group in
                for configuration in batch {
                    group.addTask {
                        await refreshOne(
                            configuration: configuration,
                            keeperRoot: keeperRoot
                        )
                    }
                }

                var values: [(String, ProviderUsageRefreshResult)] = []
                for await value in group {
                    if let value { values.append(value) }
                }
                return values
            }
            for (providerID, result) in batchResults {
                results[providerID] = result
            }
        }
        return results
    }

    func validate(
        configuration: ProviderUsageConfiguration,
        key: String
    ) async throws -> ProviderUsageSnapshot {
        guard !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ProviderUsageError.missingKey
        }
        do {
            let root = try ProviderUsageServiceRoot(configuration.baseURL)
            let adapter = try adapterFactory(configuration, root)
            return try await adapter.fetchUsage(key: key)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as ProviderUsageError {
            throw error
        } catch let error as URLError {
            throw ProviderUsageError.network(error.localizedDescription)
        } catch {
            throw ProviderUsageError.unsupportedResponse
        }
    }

    private func refreshOne(
        configuration: ProviderUsageConfiguration,
        keeperRoot: String
    ) async -> (String, ProviderUsageRefreshResult)? {
        guard !Task.isCancelled else { return nil }
        do {
            let scope = ProviderUsageScope(
                keeperRoot: keeperRoot,
                providerID: configuration.providerID
            )
            guard let key = try await credentialStore.loadKey(scope: scope),
                  !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return (configuration.providerID, .failure(.missingKey))
            }
            let root = try ProviderUsageServiceRoot(configuration.baseURL)
            let adapter = try adapterFactory(configuration, root)
            let snapshot = try await adapter.fetchUsage(key: key)
            return (configuration.providerID, .success(snapshot))
        } catch is CancellationError {
            return nil
        } catch let error as ProviderUsageError {
            return (configuration.providerID, .failure(error))
        } catch let error as URLError {
            return (
                configuration.providerID,
                .failure(.network(error.localizedDescription))
            )
        } catch {
            return (
                configuration.providerID,
                .failure(.network("无法读取供应商监控配置"))
            )
        }
    }

}
