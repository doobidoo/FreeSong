import Foundation
import ZIPFoundation
import SQLite
import FreeSongCore
import FreeSongStorage

// MARK: - Import Result Types

/// Result of importing a backup file.
public struct ImportResult: Sendable {
    public var totalFiles: Int = 0
    public var importedFiles: Int = 0
    public var skippedFiles: Int = 0
    public var skippedBinary: Int = 0
    public var importedSetlists: Int = 0
    public var skippedSetlists: Int = 0
    public var importedNames: [String] = []
    public var importedSetlistNames: [String] = []
    public var warnings: [String] = []
    public var errors: [String] = []

    public init() {}
}

/// Result of importing a single song file.
public struct ImportSingleResult: Sendable {
    public var success: Bool = false
    public var message: String = ""

    public init() {}
}

/// Progress updates during backup import.
/// Returned via callback to drive UI progress indicators.
public enum ImportProgress: Sendable {
    /// Opening and validating the archive file.
    case openingArchive
    /// Extracting entries from the ZIP archive (current, total).
    case extractingEntries(current: Int, total: Int)
    /// Reading the OnSong SQLite database.
    case readingDatabase
    /// Converting a song from OnSong format to FreeSong domain model.
    case convertingSong(title: String)
    /// Saving a song to the library.
    case savingSong(title: String)
    /// Importing a setlist.
    case importingSetlist(name: String)
    /// Import completed with the given result.
    case completed(ImportResult)
}

/// Result of validating a backup file before importing.
/// Used to give the user early feedback about what a backup contains
/// without actually extracting or converting anything.
public struct BackupValidation: Sendable {
    /// Whether the file appears to be a valid backup with importable content.
    public let isValid: Bool
    /// Total number of entries in the archive (excluding directories).
    public let totalEntries: Int
    /// Number of song files found in the archive.
    public let songFileCount: Int
    /// Whether the archive contains an OnSong SQLite database.
    public let hasDatabase: Bool
    /// Warnings about the backup content.
    public let warnings: [String]
}

/// Error types for backup import.
public enum BackupImportError: Error, LocalizedError {
    case notAZipFile
    case invalidZipFile
    case databaseError(String)
    case ioError(String)
    case encodingError(String)

    public var errorDescription: String? {
        switch self {
        case .notAZipFile: return "File is not a valid ZIP archive"
        case .invalidZipFile: return "ZIP file is corrupted or invalid"
        case .databaseError(let msg): return "Database error: \(msg)"
        case .ioError(let msg): return "IO error: \(msg)"
        case .encodingError(let msg): return "Encoding error: \(msg)"
        }
    }
}