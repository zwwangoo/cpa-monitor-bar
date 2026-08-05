import Foundation

enum LocalCredentialStorageError: Error, Equatable, LocalizedError, Sendable {
    case invalidFormat
    case unsupportedVersion
    case fileTooLarge
    case unsafePath
    case invalidPermissions
    case io(Int32)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            "本地凭证配置格式无效"
        case .unsupportedVersion:
            "本地凭证配置版本不受支持"
        case .fileTooLarge:
            "本地凭证配置超过安全大小限制"
        case .unsafePath:
            "本地凭证配置路径不安全"
        case .invalidPermissions:
            "本地凭证配置的所有者或权限不安全"
        case let .io(code):
            "本地凭证配置读写失败（\(code)）"
        }
    }
}

struct LocalAdministratorCredential: Equatable, Sendable {
    let keeperRoot: String
    let password: String
}

struct LocalProviderCredential: Equatable, Sendable {
    let keeperRoot: String
    let providerID: String
    let key: String
}

struct LocalCredentialDocument: Equatable, Sendable {
    var administrators: [LocalAdministratorCredential] = []
    var providers: [LocalProviderCredential] = []
}

enum LocalCredentialTOMLCodec {
    static let maximumBytes = 1_048_576

    static func decode(_ data: Data) throws -> LocalCredentialDocument {
        guard data.count <= maximumBytes else {
            throw LocalCredentialStorageError.fileTooLarge
        }
        guard let source = String(data: data, encoding: .utf8) else {
            throw LocalCredentialStorageError.invalidFormat
        }

        var version: Int?
        var document = LocalCredentialDocument()
        var section = LocalCredentialSection.root
        for rawLine in source.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") { continue }

            if line == "[[administrator_credentials]]" {
                try finish(section, into: &document)
                section = .administrator(LocalAdministratorFields())
                continue
            }
            if line == "[[provider_credentials]]" {
                try finish(section, into: &document)
                section = .provider(LocalProviderFields())
                continue
            }
            if line.hasPrefix("[") {
                throw LocalCredentialStorageError.invalidFormat
            }

            let (name, rawValue) = try assignment(from: line)
            switch section {
            case .root:
                guard name == "version", version == nil,
                      rawValue == "1" else {
                    if name == "version" {
                        throw LocalCredentialStorageError.unsupportedVersion
                    }
                    throw LocalCredentialStorageError.invalidFormat
                }
                version = 1
            case var .administrator(fields):
                try fields.set(name: name, value: decodeString(rawValue))
                section = .administrator(fields)
            case var .provider(fields):
                try fields.set(name: name, value: decodeString(rawValue))
                section = .provider(fields)
            }
        }
        try finish(section, into: &document)
        guard version == 1 else {
            throw LocalCredentialStorageError.unsupportedVersion
        }
        try validate(document)
        return document
    }

    static func encode(_ document: LocalCredentialDocument) throws -> Data {
        try validate(document)
        var lines = ["version = 1"]

        for credential in document.administrators.sorted(by: {
            $0.keeperRoot < $1.keeperRoot
        }) {
            lines.append(contentsOf: [
                "",
                "[[administrator_credentials]]",
                "keeper_root = \(try encodeString(credential.keeperRoot))",
                "password = \(try encodeString(credential.password))",
            ])
        }

        for credential in document.providers.sorted(by: {
            ($0.keeperRoot, $0.providerID) < ($1.keeperRoot, $1.providerID)
        }) {
            lines.append(contentsOf: [
                "",
                "[[provider_credentials]]",
                "keeper_root = \(try encodeString(credential.keeperRoot))",
                "provider_id = \(try encodeString(credential.providerID))",
                "key = \(try encodeString(credential.key))",
            ])
        }

        let data = Data((lines.joined(separator: "\n") + "\n").utf8)
        guard data.count <= maximumBytes else {
            throw LocalCredentialStorageError.fileTooLarge
        }
        return data
    }

    private static func assignment(from line: String) throws -> (String, String) {
        guard let separator = line.firstIndex(of: "=") else {
            throw LocalCredentialStorageError.invalidFormat
        }
        let name = line[..<separator].trimmingCharacters(in: .whitespaces)
        let value = line[line.index(after: separator)...]
            .trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !value.isEmpty else {
            throw LocalCredentialStorageError.invalidFormat
        }
        return (name, value)
    }

    private static func encodeString(_ value: String) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: value,
            options: [.fragmentsAllowed, .withoutEscapingSlashes]
        )
        guard let result = String(data: data, encoding: .utf8) else {
            throw LocalCredentialStorageError.invalidFormat
        }
        return result
    }

    private static func decodeString(_ value: String) throws -> String {
        do {
            return try JSONDecoder().decode(String.self, from: Data(value.utf8))
        } catch {
            throw LocalCredentialStorageError.invalidFormat
        }
    }

    private static func finish(
        _ section: LocalCredentialSection,
        into document: inout LocalCredentialDocument
    ) throws {
        switch section {
        case .root:
            return
        case let .administrator(fields):
            document.administrators.append(try fields.credential())
        case let .provider(fields):
            document.providers.append(try fields.credential())
        }
    }

    private static func validate(_ document: LocalCredentialDocument) throws {
        var administratorRoots = Set<String>()
        for credential in document.administrators {
            guard !credential.keeperRoot.isEmpty,
                  !credential.password.isEmpty,
                  administratorRoots.insert(credential.keeperRoot).inserted else {
                throw LocalCredentialStorageError.invalidFormat
            }
        }

        var providerScopes = Set<ProviderUsageScope>()
        for credential in document.providers {
            let scope = ProviderUsageScope(
                keeperRoot: credential.keeperRoot,
                providerID: credential.providerID
            )
            guard !credential.keeperRoot.isEmpty,
                  !credential.providerID.isEmpty,
                  !credential.key.isEmpty,
                  providerScopes.insert(scope).inserted else {
                throw LocalCredentialStorageError.invalidFormat
            }
        }
    }
}

private enum LocalCredentialSection {
    case root
    case administrator(LocalAdministratorFields)
    case provider(LocalProviderFields)
}

private struct LocalAdministratorFields {
    var keeperRoot: String?
    var password: String?

    mutating func set(name: String, value: @autoclosure () throws -> String) throws {
        switch name {
        case "keeper_root" where keeperRoot == nil:
            keeperRoot = try value()
        case "password" where password == nil:
            password = try value()
        default:
            throw LocalCredentialStorageError.invalidFormat
        }
    }

    func credential() throws -> LocalAdministratorCredential {
        guard let keeperRoot, let password else {
            throw LocalCredentialStorageError.invalidFormat
        }
        return LocalAdministratorCredential(
            keeperRoot: keeperRoot,
            password: password
        )
    }
}

private struct LocalProviderFields {
    var keeperRoot: String?
    var providerID: String?
    var key: String?

    mutating func set(name: String, value: @autoclosure () throws -> String) throws {
        switch name {
        case "keeper_root" where keeperRoot == nil:
            keeperRoot = try value()
        case "provider_id" where providerID == nil:
            providerID = try value()
        case "key" where key == nil:
            key = try value()
        default:
            throw LocalCredentialStorageError.invalidFormat
        }
    }

    func credential() throws -> LocalProviderCredential {
        guard let keeperRoot, let providerID, let key else {
            throw LocalCredentialStorageError.invalidFormat
        }
        return LocalProviderCredential(
            keeperRoot: keeperRoot,
            providerID: providerID,
            key: key
        )
    }
}
