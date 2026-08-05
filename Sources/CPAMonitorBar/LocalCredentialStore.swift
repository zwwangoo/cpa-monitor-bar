import Foundation

protocol CredentialStore: Sendable {
    func savePassword(_ password: String) async throws
    func loadPassword() async throws -> String?
    func deletePassword() async throws
}

actor LocalCredentialVault {
    static let shared = LocalCredentialVault()

    private let file: SecureLocalCredentialFile

    init(file: SecureLocalCredentialFile = SecureLocalCredentialFile()) {
        self.file = file
    }

    func saveAdministratorPassword(
        _ password: String,
        keeperRoot: String
    ) throws {
        guard !password.isEmpty, !keeperRoot.isEmpty else {
            throw LocalCredentialStorageError.invalidFormat
        }
        var document = try loadDocument()
        document.administrators.removeAll { $0.keeperRoot == keeperRoot }
        document.administrators.append(
            LocalAdministratorCredential(
                keeperRoot: keeperRoot,
                password: password
            )
        )
        try saveDocument(document)
    }

    func administratorPassword(keeperRoot: String) throws -> String? {
        try loadDocument().administrators.first {
            $0.keeperRoot == keeperRoot
        }?.password
    }

    func deleteAdministratorPassword(keeperRoot: String) throws {
        var document = try loadDocument()
        let originalCount = document.administrators.count
        document.administrators.removeAll { $0.keeperRoot == keeperRoot }
        if document.administrators.count != originalCount {
            try saveDocument(document)
        }
    }

    func updateProviderKeys(
        keeperRoot: String,
        upserts: [String: String],
        keeping providerIDs: Set<String>
    ) throws {
        guard !keeperRoot.isEmpty,
              upserts.keys.allSatisfy({ !$0.isEmpty }),
              upserts.values.allSatisfy({ !$0.isEmpty }),
              providerIDs.allSatisfy({ !$0.isEmpty }),
              Set(upserts.keys).isSubset(of: providerIDs) else {
            throw LocalCredentialStorageError.invalidFormat
        }
        var document = try loadDocument()
        let original = document
        document.providers.removeAll {
            $0.keeperRoot == keeperRoot
                && (!providerIDs.contains($0.providerID)
                    || upserts[$0.providerID] != nil)
        }
        document.providers.append(contentsOf:
            upserts.map { providerID, key in
                LocalProviderCredential(
                    keeperRoot: keeperRoot,
                    providerID: providerID,
                    key: key
                )
            }
        )
        guard document != original else { return }
        try saveDocument(document)
    }

    func providerKey(scope: ProviderUsageScope) throws -> String? {
        try loadDocument().providers.first {
            matches($0, scope: scope)
        }?.key
    }

    private func loadDocument() throws -> LocalCredentialDocument {
        guard let data = try file.read() else { return LocalCredentialDocument() }
        return try LocalCredentialTOMLCodec.decode(data)
    }

    private func saveDocument(_ document: LocalCredentialDocument) throws {
        try file.write(LocalCredentialTOMLCodec.encode(document))
    }

    private func matches(
        _ credential: LocalProviderCredential,
        scope: ProviderUsageScope
    ) -> Bool {
        credential.keeperRoot == scope.keeperRoot
            && credential.providerID == scope.providerID
    }
}

struct LocalAdministratorCredentialStore: CredentialStore, Sendable {
    private let vault: LocalCredentialVault
    private let keeperRoot: String

    init(vault: LocalCredentialVault, keeperRoot: String) {
        self.vault = vault
        self.keeperRoot = keeperRoot
    }

    func savePassword(_ password: String) async throws {
        try await vault.saveAdministratorPassword(
            password,
            keeperRoot: keeperRoot
        )
    }

    func loadPassword() async throws -> String? {
        try await vault.administratorPassword(keeperRoot: keeperRoot)
    }

    func deletePassword() async throws {
        try await vault.deleteAdministratorPassword(keeperRoot: keeperRoot)
    }
}

struct LocalProviderUsageCredentialStore: ProviderUsageCredentialStoring, Sendable {
    private let vault: LocalCredentialVault

    init(vault: LocalCredentialVault) {
        self.vault = vault
    }

    func loadKey(scope: ProviderUsageScope) async throws -> String? {
        try await vault.providerKey(scope: scope)
    }

    func updateKeys(
        keeperRoot: String,
        upserts: [String: String],
        keeping providerIDs: Set<String>
    ) async throws {
        try await vault.updateProviderKeys(
            keeperRoot: keeperRoot,
            upserts: upserts,
            keeping: providerIDs
        )
    }
}
