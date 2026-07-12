import Foundation
import FreeSongCore
import FreeSongStorage

// MARK: - Public Sync API

/// Main entry point for Codeberg sync operations.
///
/// ## Usage
/// ```swift
/// let sync = FreeSongSync(
///     owner: "doobidoo",
///     repo: "FreeSong",
///     token: "your-personal-access-token"
/// )
///
/// let result = try await sync.pushSongs { progress in
///     // Update UI
/// }
/// ```
public struct FreeSongSync: Sendable {

    public static let version = "1.0.0"

    private let manager: CodebergSyncManager
    private let configuration: CodebergConfiguration
    private let apiClient: CodebergAPIClient
    private let fileRepository: FileSongRepository

    // MARK: - Initialization

    /// Create a sync instance with full control over dependencies.
    /// - Parameters:
    ///   - configuration: Codeberg repo configuration.
    ///   - apiClient: Codeberg API client.
    ///   - fileRepository: Local song repository.
    public init(
        configuration: CodebergConfiguration,
        apiClient: CodebergAPIClient,
        fileRepository: FileSongRepository
    ) {
        self.configuration = configuration
        self.apiClient = apiClient
        self.fileRepository = fileRepository
        self.manager = CodebergSyncManager(
            apiClient: apiClient,
            fileRepository: fileRepository,
            configuration: configuration
        )
    }

    /// Create a sync instance with sensible defaults for the FreeSong app.
    /// - Parameters:
    ///   - owner: Codeberg username or organisation.
    ///   - repo: Repository name.
    ///   - branch: Git branch (default: `"main"`).
    ///   - songsPath: Subdirectory for song files (default: `"songs"`).
    ///   - fileRepository: Optional custom repository (defaults to ``FileSongRepository/shared``).
    public init(
        owner: String,
        repo: String,
        branch: String = "main",
        songsPath: String = "songs",
        fileRepository: FileSongRepository = FileSongRepository.shared
    ) {
        let config = CodebergConfiguration(
            owner: owner,
            repo: repo,
            branch: branch,
            songsPath: songsPath
        )
        let client = CodebergAPIClient(configuration: config)
        self.init(configuration: config, apiClient: client, fileRepository: fileRepository)
    }

    // MARK: - Token Management

    /// Store a Personal Access Token in the system Keychain.
    /// - Parameter token: The Codeberg PAT.
    public static func storeToken(_ token: String) throws {
        try KeychainStorage.store(token: token)
    }

    /// Retrieve the stored PAT from the Keychain.
    public static func retrieveToken() throws -> String? {
        try KeychainStorage.retrieve()
    }

    /// Delete the stored PAT from the Keychain.
    public static func deleteToken() throws {
        try KeychainStorage.delete()
    }

    /// Whether a token is currently stored.
    public static var hasToken: Bool {
        KeychainStorage.hasToken
    }

    // MARK: - Sync Operations

    /// Push local songs to Codeberg.
    public func pushSongs(
        progress: @Sendable @escaping (SyncProgress) -> Void = { _ in }
    ) async throws -> SyncResult {
        try await manager.pushSongs(progress: progress)
    }

    /// Pull songs from Codeberg to local library.
    public func pullSongs(
        progress: @Sendable @escaping (SyncProgress) -> Void = { _ in },
        autoResolveConflicts: ConflictResolution? = nil
    ) async throws -> SyncResult {
        try await manager.pullSongs(
            progress: progress,
            autoResolveConflicts: autoResolveConflicts
        )
    }

    /// Resolve a specific sync conflict.
    public func resolveConflict(
        _ conflict: SyncConflict,
        resolution: ConflictResolution
    ) async throws {
        try await manager.resolveConflict(conflict, resolution: resolution)
    }

    /// Validate that the current token and configuration allow accessing the repo.
    public func validateAccess() async throws -> Bool {
        try await apiClient.validateAccess()
    }
}
