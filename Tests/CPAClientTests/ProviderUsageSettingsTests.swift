import Foundation
import XCTest
@testable import CPAMonitorBar

@MainActor
final class ProviderUsageSettingsTests: XCTestCase {
    func testLoadsDraftsFromKeeperProvidersWithoutRevealingSavedKey() async throws {
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [makeProviderClient()],
            providerUsageConfigurations: [
                configuration(
                    providerID: "provider-1",
                    baseURL: "https://sub2api.example"
                ),
            ],
            providerUsageKeys: ["provider-1": "saved-secret"]
        )
        let model = dependencies.makeModel()
        await model.start()

        let drafts = try await model.loadProviderUsageDrafts()

        XCTAssertEqual(drafts.count, 2)
        XCTAssertEqual(drafts[0].providerID, "provider-1")
        XCTAssertEqual(drafts[0].providerName, "Sub2API")
        XCTAssertEqual(drafts[0].baseURL, "https://sub2api.example")
        XCTAssertTrue(drafts[0].isEnabled)
        XCTAssertTrue(drafts[0].hasSavedKey)
        XCTAssertEqual(drafts[0].enteredKey, "")
        XCTAssertEqual(drafts[1].providerID, "provider-2")
        XCTAssertEqual(drafts[1].baseURL, "")
        XCTAssertFalse(drafts[1].isEnabled)
        XCTAssertFalse(drafts[1].hasSavedKey)
    }

    func testBlankKeyKeepsSavedCredentialWhenApplying() async throws {
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [makeProviderClient()],
            providerUsageConfigurations: [configuration(providerID: "provider-1")],
            providerUsageKeys: ["provider-1": "saved-secret"]
        )
        let model = dependencies.makeModel()
        await model.start()
        var drafts = try await model.loadProviderUsageDrafts()
        drafts[0].enteredKey = ""

        try await model.applyProviderUsageDrafts(drafts)

        let key = await dependencies.providerUsageCredentialStore.loadKey(
            scope: scope(providerID: "provider-1")
        )
        XCTAssertEqual(key, "saved-secret")
        let savedKeys = await dependencies.providerUsageCredentialStore.savedKeys
        XCTAssertTrue(savedKeys.isEmpty)
    }

    func testRemoteHTTPIsTrustedAndPersistedWithoutConfirmation() async throws {
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [makeProviderClient()]
        )
        let model = dependencies.makeModel()
        await model.start()
        var drafts = try await model.loadProviderUsageDrafts()
        drafts[0].baseURL = "http://usage.example"
        drafts[0].enteredKey = "new-secret"
        drafts[0].isEnabled = true

        try await model.applyProviderUsageDrafts(drafts)

        let savedConfiguration = try XCTUnwrap(
            try dependencies.providerUsageConfigurationStore.load(
                keeperRoot: model.baseURL
            ).first
        )
        XCTAssertEqual(savedConfiguration.baseURL, "http://usage.example")
        let savedKeys = await dependencies.providerUsageCredentialStore.savedKeys
        XCTAssertEqual(savedKeys["provider-1"], "new-secret")
    }

    func testDisablingMonitorDeletesCredential() async throws {
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [makeProviderClient()],
            providerUsageConfigurations: [configuration(providerID: "provider-1")],
            providerUsageKeys: ["provider-1": "saved-secret"]
        )
        let model = dependencies.makeModel()
        await model.start()
        var drafts = try await model.loadProviderUsageDrafts()
        drafts[0].isEnabled = false

        try await model.applyProviderUsageDrafts(drafts)

        let key = await dependencies.providerUsageCredentialStore.loadKey(
            scope: scope(providerID: "provider-1")
        )
        XCTAssertNil(key)
        let deleted = await dependencies.providerUsageCredentialStore.deletedProviderIDs
        XCTAssertEqual(deleted, ["provider-1"])
    }

    func testApplyingDraftsRemovesCredentialsForProvidersMissingFromKeeper() async throws {
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [makeProviderClient()],
            providerUsageConfigurations: [
                configuration(providerID: "provider-1"),
                configuration(providerID: "removed-provider"),
            ],
            providerUsageKeys: [
                "provider-1": "current-secret",
                "removed-provider": "orphan-secret",
                "detached-provider": "detached-secret",
            ]
        )
        let model = dependencies.makeModel()
        await model.start()
        let drafts = try await model.loadProviderUsageDrafts()

        try await model.applyProviderUsageDrafts(drafts)

        let configurations = try dependencies.providerUsageConfigurationStore.load(
            keeperRoot: model.baseURL
        )
        XCTAssertFalse(configurations.contains { $0.providerID == "removed-provider" })
        let keys = await dependencies.providerUsageCredentialStore.allKeys
        XCTAssertNil(keys["removed-provider"])
        XCTAssertNil(keys["detached-provider"])
    }

    func testMissingProviderListDoesNotPruneLocalCredentials() async throws {
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [CountingClient()],
            providerUsageConfigurations: [
                configuration(providerID: "provider-1"),
            ],
            providerUsageKeys: ["provider-1": "saved-secret"]
        )
        let model = dependencies.makeModel()

        do {
            try await model.applyProviderUsageDrafts([])
            XCTFail("Expected missing provider list to block cleanup")
        } catch {}

        let keys = await dependencies.providerUsageCredentialStore.allKeys
        XCTAssertEqual(keys, ["provider-1": "saved-secret"])
        XCTAssertEqual(
            try dependencies.providerUsageConfigurationStore.load(
                keeperRoot: model.baseURL
            ).map(\.providerID),
            ["provider-1"]
        )
    }

    func testResponseWithoutIdentitiesDoesNotPruneLocalCredentials() async throws {
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [CountingClient(
                authenticated: true,
                providerResponseBody: "{}"
            )],
            providerUsageConfigurations: [
                configuration(providerID: "provider-1"),
            ],
            providerUsageKeys: ["provider-1": "saved-secret"]
        )
        let model = dependencies.makeModel()
        await model.start()

        do {
            _ = try await model.loadProviderUsageDrafts()
            XCTFail("Expected incomplete provider response to block editing")
        } catch {
            XCTAssertEqual(error as? ProviderUsageError, .providerListUnavailable)
        }

        do {
            try await model.applyProviderUsageDrafts([])
            XCTFail("Expected incomplete provider response to block cleanup")
        } catch {
            XCTAssertEqual(error as? ProviderUsageError, .providerListUnavailable)
        }

        let keys = await dependencies.providerUsageCredentialStore.allKeys
        XCTAssertEqual(keys, ["provider-1": "saved-secret"])
    }

    func testStaleDraftListDoesNotPruneNewlyLoadedProviders() async throws {
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [makeProviderClient()],
            providerUsageConfigurations: [
                configuration(providerID: "provider-1"),
            ],
            providerUsageKeys: ["provider-1": "saved-secret"]
        )
        let model = dependencies.makeModel()
        await model.start()

        do {
            try await model.applyProviderUsageDrafts([])
            XCTFail("Expected stale drafts to block cleanup")
        } catch {}

        let keys = await dependencies.providerUsageCredentialStore.allKeys
        XCTAssertEqual(keys, ["provider-1": "saved-secret"])
    }

    func testCredentialFailureDoesNotPartiallyApplyProviderKeys() async throws {
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [makeProviderClient()],
            providerUsageConfigurations: [
                configuration(providerID: "provider-1"),
                configuration(providerID: "provider-2"),
            ],
            providerUsageKeys: [
                "provider-1": "old-one",
                "provider-2": "old-two",
            ],
            providerUsageCredentialUpdateFails: true
        )
        let model = dependencies.makeModel()
        await model.start()
        var drafts = try await model.loadProviderUsageDrafts()
        drafts[0].enteredKey = "new-one"
        drafts[1].enteredKey = "new-two"

        do {
            try await model.applyProviderUsageDrafts(drafts)
            XCTFail("Expected provider credential update to fail")
        } catch {
            XCTAssertEqual(error as? LocalCredentialStorageError, .io(EIO))
        }

        let keys = await dependencies.providerUsageCredentialStore.allKeys
        XCTAssertEqual(
            keys,
            ["provider-1": "old-one", "provider-2": "old-two"]
        )
    }

    func testConfigurationFailureDoesNotModifyProviderKeys() async throws {
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [makeProviderClient()],
            providerUsageConfigurations: [
                configuration(providerID: "provider-1"),
                configuration(providerID: "provider-2"),
            ],
            providerUsageConfigurationFails: true,
            providerUsageKeys: [
                "provider-1": "old-one",
                "provider-2": "old-two",
            ]
        )
        let model = dependencies.makeModel()
        await model.start()
        let drafts = [
            ProviderUsageDraft(
                providerID: "provider-1",
                providerName: "First",
                baseURL: "https://usage.example",
                enteredKey: "new-one",
                hasSavedKey: true,
                isEnabled: true,
                validation: .idle
            ),
            ProviderUsageDraft(
                providerID: "provider-2",
                providerName: "Second",
                baseURL: "https://usage.example",
                enteredKey: "new-two",
                hasSavedKey: true,
                isEnabled: true,
                validation: .idle
            ),
        ]

        do {
            try await model.applyProviderUsageDrafts(drafts)
            XCTFail("Expected configuration read to fail before updating keys")
        } catch {
            XCTAssertEqual(
                error as? ProviderUsageConfigurationStorageError,
                .corruptedData
            )
        }

        let keys = await dependencies.providerUsageCredentialStore.allKeys
        XCTAssertEqual(
            keys,
            ["provider-1": "old-one", "provider-2": "old-two"]
        )
    }

    func testKeeperChangeBlocksProviderDraftApplication() async throws {
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [makeProviderClient()],
            providerUsageConfigurations: [configuration(providerID: "provider-1")],
            providerUsageKeys: ["provider-1": "saved-secret"]
        )
        let model = dependencies.makeModel()
        await model.start()
        let drafts = try await model.loadProviderUsageDrafts()

        do {
            try await model.applyProviderUsageDrafts(
                drafts,
                expectedKeeperRoot: "https://other-keeper.example/cpa"
            )
            XCTFail("Expected keeper mismatch to block provider changes")
        } catch {
            XCTAssertEqual(error as? ProviderUsageError, .keeperChanged)
        }

        let keys = await dependencies.providerUsageCredentialStore.allKeys
        XCTAssertEqual(keys, ["provider-1": "saved-secret"])
    }

    func testValidationUsesEnteredKeyWithoutSaving() async throws {
        let snapshot = ProviderUsageSnapshot(
            mode: .wallet(balance: 8),
            currency: "USD",
            expiresAt: nil,
            fetchedAt: Date(timeIntervalSince1970: 1)
        )
        let monitor = RecordingProviderUsageMonitor(
            validationResult: .success(snapshot)
        )
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [makeProviderClient()],
            providerUsageMonitor: monitor
        )
        let model = dependencies.makeModel()
        await model.start()
        let drafts = try await model.loadProviderUsageDrafts()
        var draft = try XCTUnwrap(drafts.first)
        draft.isEnabled = true
        draft.baseURL = "https://usage.example"
        draft.enteredKey = "draft-secret"

        let result = try await model.validateProviderUsageDraft(draft)

        XCTAssertEqual(result, snapshot)
        let validationKeys = await monitor.validationKeys
        XCTAssertEqual(validationKeys, ["draft-secret"])
        let savedKeys = await dependencies.providerUsageCredentialStore.savedKeys
        XCTAssertTrue(savedKeys.isEmpty)
    }

    func testValidationInputChangesWithEveryConnectionSetting() {
        let original = ProviderUsageDraft(
            providerID: "provider-1",
            providerName: "Sub2API",
            baseURL: "https://usage.example",
            enteredKey: "key-one",
            hasSavedKey: false,
            isEnabled: true,
            validation: .success
        )

        var changed = original
        changed.baseURL = "https://other.example"
        XCTAssertNotEqual(changed.validationInput, original.validationInput)
        changed = original
        changed.enteredKey = "key-two"
        XCTAssertNotEqual(changed.validationInput, original.validationInput)
        changed = original
        changed.hasSavedKey = true
        XCTAssertNotEqual(changed.validationInput, original.validationInput)
        changed = original
        changed.isEnabled = false
        XCTAssertNotEqual(changed.validationInput, original.validationInput)
    }

    func testKeeperMismatchBlocksProviderEditing() async {
        let dependencies = Dependencies(
            savedURL: "https://keeper.example/cpa",
            clients: [makeProviderClient()]
        )
        let model = dependencies.makeModel()
        await model.start()

        XCTAssertNil(
            model.providerUsageSettingsBlockReason(
                for: "https://keeper.example/cpa"
            )
        )
        XCTAssertEqual(
            model.providerUsageSettingsBlockReason(
                for: "https://new-keeper.example/cpa"
            ),
            "请先应用 Keeper 地址并重新打开设置"
        )
    }

    private func makeProviderClient() -> CountingClient {
        CountingClient(
            authenticated: true,
            providerResponseBody: #"{"identities":[{"id":"provider-1","displayName":"Sub2API"},{"id":"provider-2","name":"Backup"}]}"#
        )
    }

    private func configuration(
        providerID: String,
        baseURL: String = "https://usage.example"
    ) -> ProviderUsageConfiguration {
        ProviderUsageConfiguration(
            providerID: providerID,
            baseURL: baseURL,
            isEnabled: true
        )
    }

    private func scope(providerID: String) -> ProviderUsageScope {
        ProviderUsageScope(
            keeperRoot: "https://keeper.example/cpa",
            providerID: providerID
        )
    }
}
