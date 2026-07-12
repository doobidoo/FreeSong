import SwiftUI
import FreeSongCore
import FreeSongImport

@MainActor
final class ImportViewModel: ObservableObject {
    @Published var selectedFileURL: URL?
    @Published var validation: BackupValidation?
    @Published var isImporting = false
    @Published var importProgressMessage = ""
    @Published var importResult: ImportResult?
    @Published var errorMessage: String?

    private let importer = FreeSongImport()

    func validateFile(url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        selectedFileURL = url
        let v = importer.validateBackup(at: url)
        validation = v
        errorMessage = v.isValid ? nil : v.warnings.first
    }

    func startImport() async {
        guard let url = selectedFileURL else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        isImporting = true
        importResult = nil
        errorMessage = nil

        let result = await importer.importBackup(from: url) { progress in
            Task { @MainActor in
                self.importProgressMessage = self.progressText(progress)
            }
        }
        importResult = result
        if !result.errors.isEmpty {
            errorMessage = result.errors.joined(separator: "\n")
        }
        isImporting = false
    }

    /// Import one or more individual song files (not a backup archive).
    /// Reuses `FreeSongImport.importSingleFile`, which already knows how to
    /// validate and copy a song file into the library.
    func importSingleFiles(urls: [URL]) async {
        isImporting = true
        importResult = nil
        errorMessage = nil

        var result = ImportResult()
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            let single = await importer.importSingleFile(from: url)
            if accessed { url.stopAccessingSecurityScopedResource() }

            if single.success {
                result.importedFiles += 1
                result.importedNames.append(url.deletingPathExtension().lastPathComponent)
            } else {
                result.warnings.append("\(url.lastPathComponent): \(single.message)")
            }
        }
        importResult = result
        isImporting = false
    }

    func reset() {
        selectedFileURL = nil
        validation = nil
        isImporting = false
        importProgressMessage = ""
        importResult = nil
        errorMessage = nil
    }

    private func progressText(_ progress: ImportProgress) -> String {
        switch progress {
        case .openingArchive:
            return "Opening archive…"
        case .extractingEntries(let current, let total):
            return "Extracting \(current)/\(total)…"
        case .readingDatabase:
            return "Reading database…"
        case .convertingSong(let title):
            return "Converting \(title)…"
        case .savingSong(let title):
            return "Saving \(title)…"
        case .importingSetlist(let name):
            return "Importing setlist \(name)…"
        case .completed:
            return "Import complete!"
        }
    }
}
