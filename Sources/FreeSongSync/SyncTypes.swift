import Foundation
import FreeSongCore

// MARK: - Sync Progress

/// Progress updates during sync operations.
public enum SyncProgress: Sendable {
    case authenticating
    case fetchingRemoteSongs
    case comparingSongs(current: Int, total: Int)
    case uploadingSong(title: String, current: Int, total: Int)
    case downloadingSong(title: String, current: Int, total: Int)
    case resolvingConflicts(current: Int, total: Int)
    case completed(SyncResult)
}

// MARK: - Sync Result

/// Result of a sync operation.
public struct SyncResult: Sendable {
    public var uploaded: [String] = []
    public var downloaded: [String] = []
    public var conflicts: [SyncConflict] = []
    public var errors: [String] = []

    public init() {}
}

// MARK: - Sync Conflict

/// A sync conflict between local and remote versions of a song.
public struct SyncConflict: Sendable, Identifiable {
    public let id: String
    public let title: String
    public let localSHA: String
    public let remoteSHA: String

    public init(id: String, title: String, localSHA: String, remoteSHA: String) {
        self.id = id
        self.title = title
        self.localSHA = localSHA
        self.remoteSHA = remoteSHA
    }
}

/// Resolution strategy for sync conflicts.
public enum ConflictResolution: Sendable {
    case useLocal
    case useRemote
    case keepBoth
}

// MARK: - Sync Configuration

/// Configuration for connecting to a Codeberg repository.
public struct CodebergConfiguration: Sendable {
    public let baseURL: String
    public let owner: String
    public let repo: String
    public let branch: String
    public let songsPath: String

    public init(
        baseURL: String = "https://codeberg.org/api/v1",
        owner: String,
        repo: String,
        branch: String = "main",
        songsPath: String = "songs"
    ) {
        self.baseURL = baseURL
        self.owner = owner
        self.repo = repo
        self.branch = branch
        self.songsPath = songsPath
    }
}

// MARK: - API Types (Codable)

/// Represents a file or directory in a Codeberg repository.
public struct CodebergContentItem: Codable, Sendable {
    public let name: String
    public let path: String
    public let sha: String
    public let type: String   // "file", "dir", "symlink"
    public let content: String?  // base64 encoded
    public let encoding: String?
    public let size: Int?
    public let downloadURL: String?

    public init(name: String, path: String, sha: String, type: String, content: String?, encoding: String?, size: Int?, downloadURL: String?) {
        self.name = name
        self.path = path
        self.sha = sha
        self.type = type
        self.content = content
        self.encoding = encoding
        self.size = size
        self.downloadURL = downloadURL
    }

    private enum CodingKeys: String, CodingKey {
        case name, path, sha, type, content, encoding, size
        case downloadURL = "download_url"
    }
}

/// Response from creating or updating a file.
public struct CodebergCreateUpdateResponse: Codable, Sendable {
    public let content: CodebergContentItem?
    public let commit: CodebergCommitInfo
}

/// Commit information returned by the API.
public struct CodebergCommitInfo: Codable, Sendable {
    public let sha: String
    public let commit: CommitMessage
}

/// Commit message details.
public struct CommitMessage: Codable, Sendable {
    public let message: String
}

/// Request body for creating or updating a file.
public struct CodebergCreateUpdateRequest: Codable, Sendable {
    public let message: String
    public let content: String  // base64 encoded
    public let sha: String?     // required for updates
    public let branch: String

    public init(message: String, content: String, sha: String? = nil, branch: String = "main") {
        self.message = message
        self.content = content
        self.sha = sha
        self.branch = branch
    }
}

// MARK: - Sync Errors

/// Error types for sync operations.
public enum SyncError: Error, LocalizedError {
    case notAuthenticated
    case authenticationFailed(String)
    case networkError(String)
    case notFound(String)
    case conflict(String)
    case ioError(String)
    case invalidResponse
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Set a Personal Access Token in Settings."
        case .authenticationFailed(let msg):
            return "Authentication failed: \(msg)"
        case .networkError(let msg):
            return "Network error: \(msg)"
        case .notFound(let msg):
            return "Not found: \(msg)"
        case .conflict(let msg):
            return "Conflict: \(msg)"
        case .ioError(let msg):
            return "IO error: \(msg)"
        case .invalidResponse:
            return "Invalid response from server"
        case .cancelled:
            return "Sync was cancelled"
        }
    }
}
