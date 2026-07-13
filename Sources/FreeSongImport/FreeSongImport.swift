import Foundation
import FreeSongCore
import FreeSongStorage

/// Main entry point for importing OnSong backup files.
///
/// Provides a clean API for:
/// - Validating backup files before importing
/// - Importing with progress reporting
/// - Importing single song files
///
/// Usage:
/// ```swift
/// let importer = FreeSongImport()
/// let result = await importer.importBackup(from: backupURL) { progress in
///     // update UI
/// }
/// ```
public struct FreeSongImport {
    public static let version = "0.2.0"

    private let backupImporter: BackupImporter

    public init(
        fileRepository: FileSongRepository = FileSongRepository.shared,
        setlistRepository: SetlistRepository = CoreDataSetlistRepository()
    ) {
        self.backupImporter = BackupImporter(
            fileRepository: fileRepository,
            setlistRepository: setlistRepository
        )
    }

    /// Validate a backup file without importing any data.
    /// Checks the file is a valid ZIP, reports song count, database presence.
    public func validateBackup(at url: URL) -> BackupValidation {
        BackupImporter.validateBackup(at: url)
    }

    /// Import songs and setlists from a backup file with progress reporting.
    /// - Parameters:
    ///   - url: URL of the backup file (.backup, .zip, or .onsong-backup).
    ///   - progress: Optional closure called with progress updates.
    /// - Returns: ImportResult with counts, warnings, and errors.
    public func importBackup(
        from url: URL,
        progress: BackupImporter.ProgressHandler? = nil
    ) async -> ImportResult {
        await backupImporter.importBackup(from: url, progress: progress)
    }

    /// Import a single song file.
    /// - Parameter url: URL of the song file (.onsong, .chordpro, .txt, etc.).
    /// - Returns: ImportSingleResult indicating success or failure.
    public func importSingleFile(from url: URL) async -> ImportSingleResult {
        await backupImporter.importSingleFile(from: url)
    }
}
