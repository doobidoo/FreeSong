import Foundation
import FreeSongCore

// MARK: - Setlist Backup Manager

/// Manages setlist backup and restore to/from JSON file.
/// Backs up to both local Documents/FreeSong/ and iCloud Drive.
public actor SetlistBackupManager {

    public static let backupFilename = "setlists-backup.json"
    public static let iCloudContainerIdentifier = "iCloud.com.yourdomain.FreeSong" // Configure in entitlements

    private let fileManager = FileManager.default

    public init() {}

    /// Get the local backup file location (~/Documents/FreeSong/)
    public var localBackupFile: URL {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let freeSongDir = documents.appendingPathComponent("FreeSong", isDirectory: true)
        try? fileManager.createDirectory(at: freeSongDir, withIntermediateDirectories: true)
        return freeSongDir.appendingPathComponent(Self.backupFilename)
    }

    /// Get the iCloud backup file location (if available)
    public var iCloudBackupFile: URL? {
        guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: Self.iCloudContainerIdentifier) else {
            return nil
        }
        let freeSongDir = iCloudURL.appendingPathComponent("FreeSong", isDirectory: true)
        try? fileManager.createDirectory(at: freeSongDir, withIntermediateDirectories: true)
        return freeSongDir.appendingPathComponent(Self.backupFilename)
    }

    /// Export all setlists to JSON backup file.
    /// Writes to both local and iCloud locations.
    /// - Parameter setlists: Array of setlists to back up
    /// - Returns: True if successful
    public func exportSetlists(_ setlists: [SetList]) async -> Bool {
        let backup = BackupFile(
            version: 1,
            exportedAt: Date(),
            setlists: setlists
        )

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(backup)

            // Write to local
            try data.write(to: localBackupFile, options: .atomic)

            // Write to iCloud if available
            if let iCloudFile = iCloudBackupFile {
                try data.write(to: iCloudFile, options: .atomic)
            }

            return true
        } catch {
            print("Failed to export setlists: \(error)")
            return false
        }
    }

    /// Import setlists from JSON backup file.
    /// - Parameter merge: If true, merge with existing setlists. If false, only import non-existing.
    /// - Returns: Tuple of (imported count, skipped count, errors)
    public func importSetlists(merge: Bool = true) async -> (imported: Int, skipped: Int, errors: [String]) {
        // Try local first, then iCloud
        let backupFile = getBackupFile()

        guard let backupFile = backupFile,
              fileManager.fileExists(atPath: backupFile.path),
              let data = try? Data(contentsOf: backupFile),
              let backup = try? JSONDecoder().decode(BackupFile.self, from: data) else {
            return (0, 0, ["No backup file found"])
        }

        return (backup.setlists.count, 0, [])
    }

    /// Check if a backup file exists (local or iCloud).
    public func backupExists() -> Bool {
        getBackupFile() != nil
    }

    /// Get backup file info for display.
    public func getBackupInfo() async -> String? {
        guard let backupFile = getBackupFile(),
              fileManager.fileExists(atPath: backupFile.path),
              let data = try? Data(contentsOf: backupFile),
              let backup = try? JSONDecoder().decode(BackupFile.self, from: data) else {
            return nil
        }

        let count = backup.setlists.count
        let date = backup.exportedAt.formatted(date: .abbreviated, time: .shortened)
        return "\(count) setlists (\(date))"
    }

    /// Get the backup file URL (prefers iCloud if available, falls back to local).
    private func getBackupFile() -> URL? {
        if let iCloudFile = iCloudBackupFile,
           fileManager.fileExists(atPath: iCloudFile.path) {
            return iCloudFile
        }
        if fileManager.fileExists(atPath: localBackupFile.path) {
            return localBackupFile
        }
        return nil
    }

    /// Read backup file and return parsed setlists (for use with SetlistRepository).
    public func readBackupSetlists() async -> [SetList]? {
        guard let backupFile = getBackupFile(),
              fileManager.fileExists(atPath: backupFile.path),
              let data = try? Data(contentsOf: backupFile),
              let backup = try? JSONDecoder().decode(BackupFile.self, from: data) else {
            return nil
        }
        return backup.setlists
    }
}

// MARK: - Backup File Structure

private struct BackupFile: Codable {
    let version: Int
    let exportedAt: Date
    let setlists: [SetList]
}