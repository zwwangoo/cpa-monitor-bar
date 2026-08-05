import Darwin
import Foundation
import XCTest
@testable import CPAMonitorBar

final class LocalCredentialStoreTests: XCTestCase {
    func testAdministratorAndProviderCredentialsRoundTripByScope() async throws {
        let fixture = try makeFixture()
        let administrator = LocalAdministratorCredentialStore(
            vault: fixture.vault,
            keeperRoot: "https://keeper.example/cpa"
        )
        let firstProvider = LocalProviderUsageCredentialStore(vault: fixture.vault)
        let firstScope = ProviderUsageScope(
            keeperRoot: "https://keeper.example/cpa",
            providerID: "provider-1"
        )
        let otherScope = ProviderUsageScope(
            keeperRoot: "https://other.example/cpa",
            providerID: "provider-1"
        )

        try await administrator.savePassword("admin-secret")
        try await firstProvider.updateKeys(
            keeperRoot: firstScope.keeperRoot,
            upserts: [firstScope.providerID: "provider-secret"],
            keeping: [firstScope.providerID]
        )

        let password = try await administrator.loadPassword()
        let firstKey = try await firstProvider.loadKey(scope: firstScope)
        let otherKey = try await firstProvider.loadKey(scope: otherScope)
        XCTAssertEqual(password, "admin-secret")
        XCTAssertEqual(firstKey, "provider-secret")
        XCTAssertNil(otherKey)
        let document = try LocalCredentialTOMLCodec.decode(
            try XCTUnwrap(try fixture.file.read())
        )
        XCTAssertEqual(document.administrators.count, 1)
        XCTAssertEqual(document.providers.count, 1)
    }

    func testDeleteRemovesOnlyRequestedCredential() async throws {
        let fixture = try makeFixture()
        let provider = LocalProviderUsageCredentialStore(vault: fixture.vault)
        let first = ProviderUsageScope(keeperRoot: "keeper", providerID: "one")
        let second = ProviderUsageScope(keeperRoot: "keeper", providerID: "two")
        try await provider.updateKeys(
            keeperRoot: "keeper",
            upserts: ["one": "first", "two": "second"],
            keeping: ["one", "two"]
        )

        try await provider.updateKeys(
            keeperRoot: "keeper",
            upserts: [:],
            keeping: [second.providerID]
        )

        let firstKey = try await provider.loadKey(scope: first)
        let secondKey = try await provider.loadKey(scope: second)
        XCTAssertNil(firstKey)
        XCTAssertEqual(secondKey, "second")
    }

    func testMissingFileReturnsNoCredentialsWithoutCreatingIt() async throws {
        let fixture = try makeFixture()
        let administrator = LocalAdministratorCredentialStore(
            vault: fixture.vault,
            keeperRoot: "keeper"
        )

        let password = try await administrator.loadPassword()
        XCTAssertNil(password)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.file.url.path))
    }

    func testWriteCreatesPrivateDirectoryAndFilePermissions() async throws {
        let fixture = try makeFixture()
        let administrator = LocalAdministratorCredentialStore(
            vault: fixture.vault,
            keeperRoot: "keeper"
        )

        try await administrator.savePassword("secret")

        XCTAssertEqual(try permissions(fixture.file.url.deletingLastPathComponent()), 0o700)
        XCTAssertEqual(try permissions(fixture.file.url), 0o600)
    }

    func testRejectsDirectoryAndCredentialFileWithOverlyBroadPermissions() throws {
        let directoryFixture = try makeFixture()
        let directoryURL = directoryFixture.file.url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: false
        )
        XCTAssertEqual(chmod(directoryURL.path, 0o755), 0)
        XCTAssertThrowsError(
            try directoryFixture.file.write(Data("version = 1\n".utf8))
        ) { error in
            XCTAssertEqual(
                error as? LocalCredentialStorageError,
                .invalidPermissions
            )
        }

        let fileFixture = try makeFixture()
        try fileFixture.file.write(Data("version = 1\n".utf8))
        XCTAssertEqual(chmod(fileFixture.file.url.path, 0o644), 0)
        XCTAssertThrowsError(try fileFixture.file.read()) { error in
            XCTAssertEqual(
                error as? LocalCredentialStorageError,
                .invalidPermissions
            )
        }
        XCTAssertThrowsError(
            try fileFixture.file.write(Data("version = 1\n".utf8))
        ) { error in
            XCTAssertEqual(
                error as? LocalCredentialStorageError,
                .invalidPermissions
            )
        }
    }

    func testRejectsSymbolicLinkDirectoryAndCredentialFile() async throws {
        let root = temporaryRoot()
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        let realDirectory = root.appendingPathComponent("real", isDirectory: true)
        try FileManager.default.createDirectory(
            at: realDirectory,
            withIntermediateDirectories: false
        )
        let linkedDirectory = root.appendingPathComponent("linked", isDirectory: true)
        try FileManager.default.createSymbolicLink(
            at: linkedDirectory,
            withDestinationURL: realDirectory
        )
        let linkedDirectoryFile = SecureLocalCredentialFile(
            url: linkedDirectory.appendingPathComponent("config.toml")
        )
        XCTAssertThrowsError(try linkedDirectoryFile.write(Data("version = 1\n".utf8)))

        let target = realDirectory.appendingPathComponent("target.toml")
        try Data("version = 1\n".utf8).write(to: target)
        let linkedFileURL = realDirectory.appendingPathComponent("config.toml")
        try FileManager.default.createSymbolicLink(
            at: linkedFileURL,
            withDestinationURL: target
        )
        let linkedFile = SecureLocalCredentialFile(url: linkedFileURL)
        XCTAssertThrowsError(try linkedFile.read())
        XCTAssertThrowsError(try linkedFile.write(Data("version = 1\n".utf8)))
    }

    func testRejectsHardLinkedAndOversizedCredentialFiles() async throws {
        let fixture = try makeFixture()
        try fixture.file.write(Data("version = 1\n".utf8))
        let hardLinkURL = fixture.file.url.deletingLastPathComponent()
            .appendingPathComponent("copy.toml")
        XCTAssertEqual(link(fixture.file.url.path, hardLinkURL.path), 0)
        XCTAssertThrowsError(try fixture.file.read())

        try FileManager.default.removeItem(at: hardLinkURL)
        let oversized = Data(
            repeating: UInt8(ascii: "x"),
            count: LocalCredentialTOMLCodec.maximumBytes + 1
        )
        try oversized.write(to: fixture.file.url, options: .atomic)
        XCTAssertEqual(chmod(fixture.file.url.path, 0o600), 0)
        XCTAssertThrowsError(try fixture.file.read())
    }

    func testFailedOversizedUpdatePreservesPreviousDocument() async throws {
        let fixture = try makeFixture()
        let administrator = LocalAdministratorCredentialStore(
            vault: fixture.vault,
            keeperRoot: "keeper"
        )
        try await administrator.savePassword("original")

        do {
            try await administrator.savePassword(
                String(repeating: "x", count: LocalCredentialTOMLCodec.maximumBytes)
            )
            XCTFail("Expected oversized credential failure")
        } catch {
            XCTAssertEqual(error as? LocalCredentialStorageError, .fileTooLarge)
        }

        let password = try await administrator.loadPassword()
        XCTAssertEqual(password, "original")
        let siblingNames = try FileManager.default.contentsOfDirectory(
            atPath: fixture.file.url.deletingLastPathComponent().path
        )
        XCTAssertEqual(siblingNames, ["config.toml"])
    }

    func testFailedProviderBatchPreservesEveryPreviousKey() async throws {
        let fixture = try makeFixture()
        let provider = LocalProviderUsageCredentialStore(vault: fixture.vault)
        try await provider.updateKeys(
            keeperRoot: "keeper",
            upserts: ["one": "old-one", "two": "old-two"],
            keeping: ["one", "two"]
        )

        do {
            try await provider.updateKeys(
                keeperRoot: "keeper",
                upserts: [
                    "one": "new-one",
                    "two": String(
                        repeating: "x",
                        count: LocalCredentialTOMLCodec.maximumBytes
                    ),
                ],
                keeping: ["one", "two"]
            )
            XCTFail("Expected oversized provider batch failure")
        } catch {
            XCTAssertEqual(error as? LocalCredentialStorageError, .fileTooLarge)
        }

        let first = try await provider.loadKey(
            scope: ProviderUsageScope(keeperRoot: "keeper", providerID: "one")
        )
        let second = try await provider.loadKey(
            scope: ProviderUsageScope(keeperRoot: "keeper", providerID: "two")
        )
        XCTAssertEqual(first, "old-one")
        XCTAssertEqual(second, "old-two")
    }

    private func makeFixture() throws -> CredentialFixture {
        let root = temporaryRoot()
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        let url = root.appendingPathComponent(".cpamonitorbar/config.toml")
        let file = SecureLocalCredentialFile(url: url)
        return CredentialFixture(
            file: file,
            vault: LocalCredentialVault(file: file)
        )
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "CPAMonitorBarCredentialTests-\(UUID().uuidString)",
            isDirectory: true
        )
    }

    private func permissions(_ url: URL) throws -> mode_t {
        var info = stat()
        guard lstat(url.path, &info) == 0 else {
            throw LocalCredentialStorageError.io(errno)
        }
        return info.st_mode & 0o777
    }
}

private struct CredentialFixture {
    let file: SecureLocalCredentialFile
    let vault: LocalCredentialVault
}
