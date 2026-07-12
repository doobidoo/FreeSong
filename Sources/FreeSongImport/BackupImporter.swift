import Foundation
import ZIPFoundation
import FreeSongCore
import FreeSongStorage

// MARK: - Backup Importer

/// Main orchestrator for importing OnSong backup files (.backup, .zip).
///
/// Flow:
/// 1. Open ZIP archive via ZIPFoundation
/// 2. Iterate entries: extract song files, detect OnSong.sqlite3
/// 3. If OnSong DB found: import songs and setlists from SQLite
/// 4. Write imported songs to Documents/FreeSong/, create setlists in Core Data
public actor BackupImporter {

    private let fileRepository: FileSongRepository
    private let setlistRepository: SetlistRepository

    /// Supported song file extensions (lowercased).
    private static let songExtensions: Set<String> = ["onsong", "chordpro", "cho", "crd", "pro", "txt"]

    public typealias ProgressHandler = @Sendable (ImportProgress) -> Void

    public init(
        fileRepository: FileSongRepository = FileSongRepository.shared,
        setlistRepository: SetlistRepository = CoreDataSetlistRepository()
    ) {
        self.fileRepository = fileRepository
        self.setlistRepository = setlistRepository
    }

    // MARK: - Public API

    /// Import songs and setlists from a backup file (.backup or .zip).
    /// - Parameters:
    ///   - url: URL of the backup file.
    ///   - progress: Optional closure called with progress updates during import.
    /// - Returns: ImportResult with counts, warnings, and errors.
    public func importBackup(from url: URL, progress: ProgressHandler? = nil) async -> ImportResult {
        var result = ImportResult()

        progress?(.openingArchive)

        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            result.errors.append("Cannot open ZIP archive: \(url.lastPathComponent) — \(error.localizedDescription)")
            progress?(.completed(result))
            return result
        }

        // Collect entries first so we know the total count for progress reporting
        let entries = Array(archive).filter { $0.type != .directory }
        let totalEntries = entries.count
        var currentEntry = 0

        var tempDbURL: URL?

        for entry in entries {
            currentEntry += 1
            let entryName = entry.path
            progress?(.extractingEntries(current: currentEntry, total: totalEntries))

            let lowerName = entryName.lowercased()
            if lowerName.hasSuffix("onsong.sqlite3") || lowerName.contains("/onsong.sqlite3") {
                let tempDir = FileManager.default.temporaryDirectory
                tempDbURL = tempDir.appendingPathComponent(".onsong_temp_\(UUID().uuidString).sqlite3")
                do {
                    _ = try archive.extract(entry, to: tempDbURL!)
                } catch {
                    result.errors.append("Failed to extract OnSong database: \(error.localizedDescription)")
                    tempDbURL = nil
                }
                continue
            }

            guard isSongFile(entryName) else { continue }

            result.totalFiles += 1

            guard let rawFileName = entryName.components(separatedBy: "/").last, !rawFileName.isEmpty else {
                continue
            }

            if rawFileName.hasPrefix(".") {
                result.skippedFiles += 1
                continue
            }

            // NFC-normalize filename so Hangul/CJK characters are stored consistently
            let fileName = (rawFileName as NSString).precomposedStringWithCanonicalMapping
            let destURL = fileRepository.libraryRoot.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: destURL.path) {
                result.skippedFiles += 1
                continue
            }

            do {
                try await extractSongEntry(archive, entry: entry, to: destURL, result: &result)
            } catch {
                result.errors.append("\(fileName): \(error.localizedDescription)")
            }
        }

        if let dbURL = tempDbURL {
            defer { try? FileManager.default.removeItem(at: dbURL) }

            progress?(.readingDatabase)

            do {
                try await importSongsFromDatabase(at: dbURL, result: &result, progress: progress)
                try await importSetlistsFromDatabase(at: dbURL, result: &result, progress: progress)
            } catch {
                result.errors.append("Database import: \(error.localizedDescription)")
            }
        }

        progress?(.completed(result))
        return result
    }

    /// Import a single song file (outside of a backup archive).
    /// - Parameters:
    ///   - url: URL of the song file to import.
    ///   - progress: Optional closure called with progress updates during import.
    /// - Returns: ImportSingleResult indicating success or failure.
    public func importSingleFile(from url: URL, progress: ProgressHandler? = nil) async -> ImportSingleResult {
        var result = ImportSingleResult()

        guard isSongFile(url.lastPathComponent) else {
            result.success = false
            result.message = "Not a supported song file"
            return result
        }

        do {
            let data = try Data(contentsOf: url)
            if let binaryType = BinaryDetector.detectBinaryContent(data) {
                result.success = false
                result.message = "Cannot import \(binaryType)"
                return result
            }
        } catch {
            result.success = false
            result.message = "Cannot read file: \(error.localizedDescription)"
            return result
        }

        let destURL = fileRepository.libraryRoot.appendingPathComponent(url.lastPathComponent)

        guard !FileManager.default.fileExists(atPath: destURL.path) else {
            result.success = false
            result.message = "File already exists"
            return result
        }

        progress?(.openingArchive)

        do {
            let data = try Data(contentsOf: url)
            try writeSongFile(data: data, to: destURL)
            result.success = true
            result.message = "Imported successfully"
        } catch {
            result.success = false
            result.message = error.localizedDescription
        }

        return result
    }

    /// Validate a backup file without importing any data.
    /// Checks that the file is a valid ZIP archive and reports what it contains.
    /// - Parameter url: URL of the backup file to validate.
    /// - Returns: A BackupValidation describing the archive contents.
    public static func validateBackup(at url: URL) -> BackupValidation {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return BackupValidation(
                isValid: false,
                totalEntries: 0,
                songFileCount: 0,
                hasDatabase: false,
                warnings: ["File not found: \(url.lastPathComponent)"]
            )
        }

        guard isBackupFile(url.lastPathComponent) else {
            return BackupValidation(
                isValid: false,
                totalEntries: 0,
                songFileCount: 0,
                hasDatabase: false,
                warnings: ["Not a supported backup file format: \(url.lastPathComponent)"]
            )
        }

        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            return BackupValidation(
                isValid: false,
                totalEntries: 0,
                songFileCount: 0,
                hasDatabase: false,
                warnings: ["Cannot open as ZIP archive: \(error.localizedDescription)"]
            )
        }

        var warnings: [String] = []
        var songFileCount = 0
        var hasDatabase = false
        var totalEntries = 0

        for entry in archive {
            guard entry.type != .directory else { continue }
            totalEntries += 1

            let lowerName = entry.path.lowercased()
            if lowerName.hasSuffix("onsong.sqlite3") || lowerName.contains("/onsong.sqlite3") {
                hasDatabase = true
                continue
            }

            if isSongFile(entry.path) {
                songFileCount += 1
            }
        }

        if songFileCount == 0 && !hasDatabase {
            warnings.append("No song files or database found in archive")
        } else if songFileCount == 0 && hasDatabase {
            warnings.append("No song files found outside the database; importing from database only")
        }

        let isValid = hasDatabase || songFileCount > 0

        return BackupValidation(
            isValid: isValid,
            totalEntries: totalEntries,
            songFileCount: songFileCount,
            hasDatabase: hasDatabase,
            warnings: warnings
        )
    }

    public static func isBackupFile(_ fileName: String) -> Bool {
        let lower = fileName.lowercased()
        return lower.hasSuffix(".backup") || lower.hasSuffix(".zip") || lower.hasSuffix(".onsong-backup")
    }

    // MARK: - Private: ZIP Entry Extraction

    private func extractSongEntry(
        _ archive: Archive,
        entry: Entry,
        to destURL: URL,
        result: inout ImportResult
    ) async throws {
        var rawData = Data()
        _ = try archive.extract(entry) { chunk in
            rawData.append(chunk)
        }

        guard !rawData.isEmpty else {
            result.skippedFiles += 1
            return
        }

        if let binaryType = BinaryDetector.detectBinaryContent(rawData) {
            result.skippedBinary += 1
            result.warnings.append("\(destURL.lastPathComponent): Skipped (\(binaryType))")
            return
        }

        try writeSongFile(data: rawData, to: destURL)

        result.importedFiles += 1
        result.importedNames.append(displayName(from: destURL.lastPathComponent))
    }

    private func writeSongFile(data: Data, to destURL: URL) throws {
        if let utf8String = String(data: data, encoding: .utf8), !utf8String.isEmpty {
            try utf8String.write(to: destURL, atomically: true, encoding: .utf8)
            return
        }

        // Try common legacy encodings but always write as UTF-8
        let legacyEncodings: [String.Encoding] = [.isoLatin1, .windowsCP1252]
        for encoding in legacyEncodings {
            if let converted = String(data: data, encoding: encoding), !converted.isEmpty {
                try converted.write(to: destURL, atomically: true, encoding: .utf8)
                return
            }
        }

        // Last resort: replace undecodable bytes with replacement character
        let lossy = String(data: data, encoding: .utf8) ?? String(bytes: data, encoding: .ascii) ?? ""
        if !lossy.isEmpty {
            try lossy.write(to: destURL, atomically: true, encoding: .utf8)
            return
        }

        throw BackupImportError.encodingError(
            "Cannot decode \(destURL.lastPathComponent)"
        )
    }

    // MARK: - Private: SQLite Database Import

    private func importSongsFromDatabase(at dbURL: URL, result: inout ImportResult, progress: ProgressHandler?) async throws {
        let reader = try OnSongDatabaseReader(databasePath: dbURL.path)
        let songs = try await reader.importSongs()

        for onSong in songs {
            result.totalFiles += 1
            progress?(.convertingSong(title: onSong.title))

            // Convert OnSong record to FreeSong domain Song
            let song: Song
            do {
                song = try OnSongConverter.convertToSong(onSong)
            } catch OnSongConverter.ConversionError.emptyTitle {
                result.warnings.append("Skipped song: empty title")
                result.skippedFiles += 1
                continue
            } catch OnSongConverter.ConversionError.emptyContent {
                result.warnings.append("Skipped '\(onSong.title)': empty content")
                result.skippedFiles += 1
                continue
            } catch {
                result.errors.append("Failed to convert '\(onSong.title)': \(error.localizedDescription)")
                result.skippedFiles += 1
                continue
            }

            let safeTitle = sanitizeFileName(song.title)
            guard !safeTitle.isEmpty else { continue }

            let fileName: String
            if let key = song.key, !key.trimmingCharacters(in: .whitespaces).isEmpty {
                fileName = "\(safeTitle)-\(key.trimmingCharacters(in: .whitespaces)).onsong"
            } else {
                fileName = "\(safeTitle).onsong"
            }

            let destURL = fileRepository.libraryRoot.appendingPathComponent(fileName)

            if FileManager.default.fileExists(atPath: destURL.path) {
                result.skippedFiles += 1
                continue
            }

            progress?(.savingSong(title: song.title))

            do {
                try await fileRepository.saveSong(song, at: destURL.path)
                result.importedFiles += 1
                result.importedNames.append(song.title)
            } catch {
                result.errors.append("\(fileName): \(error.localizedDescription)")
            }
        }
    }

    private func importSetlistsFromDatabase(at dbURL: URL, result: inout ImportResult, progress: ProgressHandler?) async throws {
        let reader = try OnSongDatabaseReader(databasePath: dbURL.path)
        let setlists = try await reader.importSetlists()

        let existingSetlists = try await setlistRepository.getAllSetlists()
        let existingNames = Set(existingSetlists.map { $0.name.lowercased() })

        for setlist in setlists {
            let setlistTitle = setlist.title.trimmingCharacters(in: .whitespaces)
            guard !setlistTitle.isEmpty else { continue }

            guard !existingNames.contains(setlistTitle.lowercased()) else {
                result.skippedSetlists += 1
                continue
            }

            progress?(.importingSetlist(name: setlistTitle))

            var items: [SetListItem] = []
            var songsAdded = 0

            for item in setlist.items {
                if let songPath = findSongFile(title: item.title, artist: item.artist, key: item.key) {
                    let setItem = SetListItem(
                        songPath: songPath,
                        songTitle: item.title,
                        songArtist: item.artist ?? "",
                        position: item.orderIndex,
                        notes: nil
                    )
                    items.append(setItem)
                    songsAdded += 1
                }
            }

            guard songsAdded > 0 else { continue }

            let newSetlist = SetList(name: setlistTitle, items: items)
            try await setlistRepository.saveSetlist(newSetlist)

            result.importedSetlists += 1
            result.importedSetlistNames.append("\(setlistTitle) (\(songsAdded) songs)")
        }
    }

    private func findSongFile(title: String, artist: String?, key: String?) -> String? {
        let safeTitle = sanitizeFileName(title)
        guard !safeTitle.isEmpty else { return nil }

        let libraryRoot = fileRepository.libraryRoot

        let keyPart: String
        if let k = key, !k.trimmingCharacters(in: .whitespaces).isEmpty {
            keyPart = k.trimmingCharacters(in: .whitespaces)
        } else {
            keyPart = ""
        }

        var patterns: [String]
        if !keyPart.isEmpty {
            patterns = [
                "\(safeTitle)-\(keyPart).onsong",
                "\(safeTitle)-\(keyPart).txt",
                "\(safeTitle)-\(keyPart).chordpro",
                "\(safeTitle)-\(keyPart).cho",
                "\(safeTitle)-\(keyPart).crd",
                "\(safeTitle)-\(keyPart).pro",
                "\(safeTitle).onsong",
                "\(safeTitle).txt",
                "\(safeTitle).chordpro",
                "\(safeTitle).cho",
                "\(safeTitle).crd",
                "\(safeTitle).pro",
            ]
        } else {
            patterns = [
                "\(safeTitle).onsong",
                "\(safeTitle).txt",
                "\(safeTitle).chordpro",
                "\(safeTitle).cho",
                "\(safeTitle).crd",
                "\(safeTitle).pro",
            ]
        }

        for pattern in patterns {
            let fileURL = libraryRoot.appendingPathComponent(pattern)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL.path
            }
        }

        guard let enumerator = FileManager.default.enumerator(
            at: libraryRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return nil }

        let lowerTitle = safeTitle.lowercased()
        for case let fileURL as URL in enumerator {
            let name = fileURL.lastPathComponent.lowercased()
            if name.hasPrefix(lowerTitle) && Self.isSongFile(name) {
                return fileURL.path
            }
        }

        return nil
    }

    // MARK: - Private: Helpers

    private static func isSongFile(_ name: String) -> Bool {
        let lower = name.lowercased()
        guard let dotIndex = lower.lastIndex(of: ".") else { return false }
        let ext = String(lower[dotIndex...].dropFirst())
        return songExtensions.contains(ext)
    }

    private func isSongFile(_ name: String) -> Bool {
        Self.isSongFile(name)
    }

    private func sanitizeFileName(_ name: String) -> String {
        guard !name.isEmpty else { return "" }

        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|")
        var safe = name.components(separatedBy: illegal).joined(separator: "_")

        safe = safe.trimmingCharacters(in: .whitespacesAndNewlines)
        while safe.hasSuffix(".") {
            safe = String(safe.dropLast())
        }

        if safe.count > 100 {
            safe = String(safe.prefix(100))
        }

        return safe
    }

    private func displayName(from fileName: String) -> String {
        guard let dotIndex = fileName.lastIndex(of: ".") else { return fileName }
        return String(fileName[..<dotIndex])
    }
}
