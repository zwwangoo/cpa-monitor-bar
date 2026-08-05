import Darwin
import Foundation

struct SecureLocalCredentialFile: Sendable {
    static let defaultURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".cpamonitorbar", isDirectory: true)
        .appendingPathComponent("config.toml", isDirectory: false)

    let url: URL

    init(url: URL = Self.defaultURL) {
        self.url = url.standardizedFileURL
    }

    func read() throws -> Data? {
        let directoryURL = url.deletingLastPathComponent()
        guard try validateDirectory(directoryURL, createIfMissing: false) else {
            return nil
        }

        var pathInfo = stat()
        guard lstat(url.path, &pathInfo) == 0 else {
            if errno == ENOENT { return nil }
            throw LocalCredentialStorageError.io(errno)
        }
        try validateCredentialFile(pathInfo)

        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else {
            throw errno == ELOOP
                ? LocalCredentialStorageError.unsafePath
                : LocalCredentialStorageError.io(errno)
        }
        defer { close(descriptor) }

        var openedInfo = stat()
        guard fstat(descriptor, &openedInfo) == 0 else {
            throw LocalCredentialStorageError.io(errno)
        }
        try validateCredentialFile(openedInfo)
        guard openedInfo.st_dev == pathInfo.st_dev,
              openedInfo.st_ino == pathInfo.st_ino else {
            throw LocalCredentialStorageError.unsafePath
        }
        return try readData(from: descriptor)
    }

    func write(_ data: Data) throws {
        guard data.count <= LocalCredentialTOMLCodec.maximumBytes else {
            throw LocalCredentialStorageError.fileTooLarge
        }
        let directoryURL = url.deletingLastPathComponent()
        _ = try validateDirectory(directoryURL, createIfMissing: true)
        try validateExistingTarget()

        let temporaryURL = directoryURL.appendingPathComponent(
            ".\(url.lastPathComponent).\(UUID().uuidString).tmp",
            isDirectory: false
        )
        var shouldRemoveTemporaryFile = true
        defer {
            if shouldRemoveTemporaryFile {
                _ = unlink(temporaryURL.path)
            }
        }

        let flags = O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC
        let descriptor = open(temporaryURL.path, flags, mode_t(0o600))
        guard descriptor >= 0 else {
            throw LocalCredentialStorageError.io(errno)
        }
        do {
            guard fchmod(descriptor, mode_t(0o600)) == 0 else {
                throw LocalCredentialStorageError.io(errno)
            }
            try write(data, to: descriptor)
            guard fsync(descriptor) == 0 else {
                throw LocalCredentialStorageError.io(errno)
            }
            guard close(descriptor) == 0 else {
                throw LocalCredentialStorageError.io(errno)
            }
        } catch {
            _ = close(descriptor)
            throw error
        }

        guard rename(temporaryURL.path, url.path) == 0 else {
            throw LocalCredentialStorageError.io(errno)
        }
        shouldRemoveTemporaryFile = false
        try syncDirectory(directoryURL)
    }

    private func validateDirectory(
        _ directoryURL: URL,
        createIfMissing: Bool
    ) throws -> Bool {
        var info = stat()
        if lstat(directoryURL.path, &info) != 0 {
            guard errno == ENOENT else {
                throw LocalCredentialStorageError.io(errno)
            }
            guard createIfMissing else { return false }
            guard mkdir(directoryURL.path, mode_t(0o700)) == 0 else {
                throw LocalCredentialStorageError.io(errno)
            }
            guard lstat(directoryURL.path, &info) == 0 else {
                throw LocalCredentialStorageError.io(errno)
            }
        }
        guard isDirectory(info.st_mode), !isSymbolicLink(info.st_mode) else {
            throw LocalCredentialStorageError.unsafePath
        }
        guard info.st_uid == getuid(), permissions(info.st_mode) == 0o700 else {
            throw LocalCredentialStorageError.invalidPermissions
        }
        return true
    }

    private func validateExistingTarget() throws {
        var info = stat()
        guard lstat(url.path, &info) == 0 else {
            if errno == ENOENT { return }
            throw LocalCredentialStorageError.io(errno)
        }
        try validateCredentialFile(info)
    }

    private func validateCredentialFile(_ info: stat) throws {
        guard isRegularFile(info.st_mode), !isSymbolicLink(info.st_mode),
              info.st_nlink == 1 else {
            throw LocalCredentialStorageError.unsafePath
        }
        guard info.st_uid == getuid(), permissions(info.st_mode) == 0o600 else {
            throw LocalCredentialStorageError.invalidPermissions
        }
        guard info.st_size >= 0,
              info.st_size <= LocalCredentialTOMLCodec.maximumBytes else {
            throw LocalCredentialStorageError.fileTooLarge
        }
    }

    private func readData(from descriptor: Int32) throws -> Data {
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)
        while true {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count == 0 { return result }
            if count < 0 {
                if errno == EINTR { continue }
                throw LocalCredentialStorageError.io(errno)
            }
            guard result.count + count <= LocalCredentialTOMLCodec.maximumBytes else {
                throw LocalCredentialStorageError.fileTooLarge
            }
            result.append(contentsOf: buffer[0..<count])
        }
    }

    private func write(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            var offset = 0
            while offset < rawBuffer.count {
                let count = Darwin.write(
                    descriptor,
                    baseAddress.advanced(by: offset),
                    rawBuffer.count - offset
                )
                if count < 0 {
                    if errno == EINTR { continue }
                    throw LocalCredentialStorageError.io(errno)
                }
                guard count > 0 else {
                    throw LocalCredentialStorageError.io(EIO)
                }
                offset += count
            }
        }
    }

    private func syncDirectory(_ directoryURL: URL) throws {
        let descriptor = open(
            directoryURL.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW
        )
        guard descriptor >= 0 else {
            throw LocalCredentialStorageError.io(errno)
        }
        defer { close(descriptor) }
        guard fsync(descriptor) == 0 else {
            throw LocalCredentialStorageError.io(errno)
        }
    }

    private func isDirectory(_ mode: mode_t) -> Bool {
        mode & S_IFMT == S_IFDIR
    }

    private func isRegularFile(_ mode: mode_t) -> Bool {
        mode & S_IFMT == S_IFREG
    }

    private func isSymbolicLink(_ mode: mode_t) -> Bool {
        mode & S_IFMT == S_IFLNK
    }

    private func permissions(_ mode: mode_t) -> mode_t {
        mode & mode_t(0o777)
    }
}
