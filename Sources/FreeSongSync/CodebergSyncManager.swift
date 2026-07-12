import Foundation
import CryptoKit
import FreeSongCore
import FreeSongStorage

// MARK: - Sync Manager

/// Orchestrates bidirectional sync between the local song library and a Codeberg repository.
///
/// ## Architecture
/// - Uses ``CodebergAPIClient`` for all remote operations
/// - Uses ``FileSongRepository`` for all local operations
/// - Content comparison uses the Git blob SHA-1 of generated ChordPro output
/// - Conflicts can be resolved individually or auto-resolved during pull
///
/// ## Thread Safety
/// All public methods are `async` and safe to call from any task.
/// Internal actor crossings (``CodebergAPIClient``, ``FileSongRepository``) are handled cooperatively.
public struct CodebergSyncManager: Sendable {

    private let apiClient: CodebergAPIClient
    private let fileRepository: FileSongRepository
    private let configuration: CodebergConfiguration
    private let parser = SongParser.self

    // MARK: - Initialization

    public init(
        apiClient: CodebergAPIClient,
        fileRepository: FileSongRepository,
        configuration: CodebergConfiguration
    ) {
        self.apiClient = apiClient
        self.fileRepository = fileRepository
        self.configuration = configuration
    }

    // MARK: - Push (Local → Remote)

    /// Upload local changes to Codeberg.
    ///
    /// New songs are created. Changed songs are updated.
    /// Identical songs are skipped (matched by Git blob SHA of generated content).
    ///
    /// - Parameter progress: Closure called with progress updates (called from arbitrary `Task`).
    /// - Returns: ``SyncResult`` summarising what was uploaded and any errors.
    public func pushSongs(
        progress: @Sendable @escaping (SyncProgress) -> Void = { _ in }
    ) async throws -> SyncResult {
        try await validateAccess(progress: progress)
        progress(.fetchingRemoteSongs)

        let remoteFiles = try await apiClient.listDirectory(path: configuration.songsPath)
        let remoteByName = Dictionary(uniqueKeysWithValues: remoteFiles.map { ($0.name, $0) })

        let localSongs = try await fileRepository.getAllSongs()
        progress(.comparingSongs(current: 0, total: localSongs.count))

        var result = SyncResult()

        for (index, song) in localSongs.enumerated() {
            progress(.comparingSongs(current: index + 1, total: localSongs.count))

            let filename = Self.sanitizedFilename(song.title) + ".onsong"
            let remotePath = "\(configuration.songsPath)/\(filename)"
            let content = SongSerializer.serialize(song)

            guard let contentData = content.data(using: .utf8) else {
                result.errors.append("Local encoding error: \(song.title)")
                continue
            }
            let contentSHA = Self.gitBlobSHA(for: contentData)

            let uploadProgress = { (title: String) async throws in
                progress(.uploadingSong(title: title, current: index + 1, total: localSongs.count))
            }

            if let remoteFile = remoteByName[filename] {
                // Remote exists — compare SHA
                guard remoteFile.sha != contentSHA else {
                    continue // identical → skip
                }
                try await uploadProgress(song.title)
                do {
                    _ = try await apiClient.createOrUpdateFile(
                        path: remotePath,
                        content: contentData,
                        sha: remoteFile.sha
                    )
                    result.uploaded.append(song.title)
                } catch {
                    result.errors.append("\(song.title): \(error.localizedDescription)")
                }
            } else {
                // New file
                try await uploadProgress(song.title)
                do {
                    _ = try await apiClient.createOrUpdateFile(
                        path: remotePath,
                        content: contentData,
                        sha: nil
                    )
                    result.uploaded.append(song.title)
                } catch {
                    result.errors.append("\(song.title): \(error.localizedDescription)")
                }
            }
        }

        progress(.completed(result))
        return result
    }

    // MARK: - Pull (Remote → Local)

    /// Download changes from Codeberg to the local library.
    ///
    /// New files are downloaded and parsed as ``Song``s.
    /// Files with local changes are flagged as ``SyncConflict``(s).
    /// Pass `autoResolveConflicts` to handle all conflicts with a single strategy.
    ///
    /// - Parameters:
    ///   - progress: Progress callback.
    ///   - autoResolveConflicts: If set, all conflicts are auto-resolved instead of reported.
    /// - Returns: ``SyncResult`` with downloads, conflicts, and errors.
    public func pullSongs(
        progress: @Sendable @escaping (SyncProgress) -> Void = { _ in },
        autoResolveConflicts: ConflictResolution? = nil
    ) async throws -> SyncResult {
        try await validateAccess(progress: progress)
        progress(.fetchingRemoteSongs)

        let remoteFiles = try await apiClient.listDirectory(path: configuration.songsPath)
            .filter { $0.type == "file" }

        let localSongs = try await fileRepository.getAllSongs()
        let localByTitle = Dictionary(uniqueKeysWithValues: localSongs.map { ($0.title, $0) })

        progress(.comparingSongs(current: 0, total: remoteFiles.count))

        var result = SyncResult()

        for (index, remoteFile) in remoteFiles.enumerated() {
            progress(.comparingSongs(current: index + 1, total: remoteFiles.count))

            // Strip extension for title matching
            let title = Self.filenameToTitle(remoteFile.name)

            let (remoteData, _) = try await apiClient.getFileContent(
                path: "\(configuration.songsPath)/\(remoteFile.name)"
            )

            guard let remoteContent = String(data: remoteData, encoding: .utf8) else {
                result.errors.append("Decoding failed: \(remoteFile.name)")
                continue
            }

            if let localSong = localByTitle[title] {
                let localContent = SongSerializer.serialize(localSong)

                guard localContent != remoteContent else {
                    continue // identical → skip
                }

                // Content differs → conflict
                let conflict = SyncConflict(
                    id: title,
                    title: title,
                    localSHA: Self.gitBlobSHA(for: Data(localContent.utf8)),
                    remoteSHA: remoteFile.sha
                )

                if let resolution = autoResolveConflicts {
                    progress(.resolvingConflicts(current: index + 1, total: remoteFiles.count))
                    try await resolve(conflict: conflict, resolution: resolution, remoteData: remoteData)
                    result.downloaded.append(title)
                } else {
                    result.conflicts.append(conflict)
                }
            } else {
                // New remote song
                progress(.downloadingSong(title: title, current: index + 1, total: remoteFiles.count))
                try await saveRemoteSong(content: remoteContent, title: title)
                result.downloaded.append(title)
            }
        }

        progress(.completed(result))
        return result
    }

    // MARK: - Conflict Resolution

    /// Resolve a single sync conflict.
    ///
    /// - Parameters:
    ///   - conflict: The conflict to resolve.
    ///   - resolution: Strategy to apply.
    public func resolveConflict(
        _ conflict: SyncConflict,
        resolution: ConflictResolution
    ) async throws {
        // For .useRemote and .keepBoth we need remote content.
        // Fetch it unconditionally so we can cover all three cases.
        let (remoteData, _) = try await apiClient.getFileContent(
            path: "\(configuration.songsPath)/\(Self.sanitizedFilename(conflict.title)).onsong"
        )
        try await resolve(conflict: conflict, resolution: resolution, remoteData: remoteData)
    }

    // MARK: - Private Helpers

    /// Validate authentication and configuration.
    private func validateAccess(progress: @Sendable @escaping (SyncProgress) -> Void) async throws {
        progress(.authenticating)
        guard try await apiClient.validateAccess() else {
            throw SyncError.authenticationFailed("Cannot access Codeberg with current token")
        }
    }

    /// Apply a resolution strategy.
    private func resolve(
        conflict: SyncConflict,
        resolution: ConflictResolution,
        remoteData: Data
    ) async throws {
        guard let remoteContent = String(data: remoteData, encoding: .utf8) else {
            throw SyncError.networkError("Failed to decode remote content for: \(conflict.title)")
        }

        switch resolution {
        case .useLocal:
            // Push local version to remote
            try await pushSingleSong(title: conflict.title)

        case .useRemote:
            // Overwrite local with remote
            try await saveRemoteSong(content: remoteContent, title: conflict.title)

        case .keepBoth:
            // Rename local → keep remote as primary
            let filename = Self.sanitizedFilename(conflict.title)
            let libraryRoot = fileRepository.libraryRoot

            let localURL = libraryRoot.appendingPathComponent("\(filename).onsong")
            let conflictURL = libraryRoot.appendingPathComponent("\(filename)_conflict.onsong")

            // Only rename if local actually exists on disk
            if FileManager.default.fileExists(atPath: localURL.path) {
                try FileManager.default.moveItem(at: localURL, to: conflictURL)
            }

            try await saveRemoteSong(content: remoteContent, title: conflict.title)
        }
    }

    /// Push a single song by title to Codeberg.
    private func pushSingleSong(title: String) async throws {
        let allSongs = try await fileRepository.getAllSongs()
        guard let song = allSongs.first(where: { $0.title == title }) else {
            throw SyncError.notFound("Local song not found: \(title)")
        }

        let filename = Self.sanitizedFilename(title) + ".onsong"
        let remotePath = "\(configuration.songsPath)/\(filename)"
        let content = SongSerializer.serialize(song)
        guard let contentData = content.data(using: .utf8) else {
            throw SyncError.ioError("Failed to encode song: \(title)")
        }

        // Check if remote exists
        let remoteFiles = try await apiClient.listDirectory(path: configuration.songsPath)
        if let existing = remoteFiles.first(where: { $0.name == filename }) {
            _ = try await apiClient.createOrUpdateFile(
                path: remotePath, content: contentData, sha: existing.sha
            )
        } else {
            _ = try await apiClient.createOrUpdateFile(
                path: remotePath, content: contentData, sha: nil
            )
        }
    }

    /// Parse remote content and save as a local song file.
    private func saveRemoteSong(content: String, title: String) async throws {
        // Try to parse; fall back to a minimal song if parsing fails.
        let song = parser.parse(content)

        let filename = Self.sanitizedFilename(title) + ".onsong"
        let localPath = fileRepository.libraryRoot
            .appendingPathComponent(filename)
            .path
        try await fileRepository.saveSong(song, at: localPath)
    }

    // MARK: - Static Helpers

    /// Compute the Git blob SHA-1 for a data blob.
    /// Git blob SHA = `SHA1("blob \(size)\0\(content)")`.
    static func gitBlobSHA(for data: Data) -> String {
        let prefix = "blob \(data.count)\0"
        var sha1 = Insecure.SHA1()
        sha1.update(data: Data(prefix.utf8))
        sha1.update(data: data)
        return sha1.finalize()
            .compactMap { String(format: "%02x", $0) }
            .joined()
    }

    /// Convert a title to a safe filename (no path separators or colons).
    static func sanitizedFilename(_ title: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.whitespaces).subtracting(.controlCharacters)
        return title
            .components(separatedBy: allowed.inverted)
            .joined()
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
    }

    /// Derive a display title from a filename (strip extension, decode percent-encoding).
    static func filenameToTitle(_ filename: String) -> String {
        let withoutExt = (filename as NSString).deletingPathExtension
        return withoutExt
            .replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
