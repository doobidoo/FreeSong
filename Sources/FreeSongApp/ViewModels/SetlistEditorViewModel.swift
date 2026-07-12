import SwiftUI
import FreeSongCore
import FreeSongStorage

@MainActor
final class SetlistEditorViewModel: ObservableObject {
    @Published var setlists: [SetList] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingNewSetlistAlert = false
    @Published var newSetlistName = ""
    @Published var showingBackupRestorePrompt = false

    private let storage: SetlistRepository
    private let songRepo: SongRepository
    private let backupManager = SetlistBackupManager()

    init(
        setlistRepository: SetlistRepository = CoreDataSetlistRepository(),
        songRepository: SongRepository = FileSongRepository.shared
    ) {
        self.storage = setlistRepository
        self.songRepo = songRepository
    }

    func loadSetlists() async {
        isLoading = true
        errorMessage = nil
        do {
            setlists = try await storage.getAllSetlists()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createSetlist(name: String) async {
        let setlist = SetList(
            name: name,
            createdAt: Date(),
            modifiedAt: Date()
        )
        do {
            try await storage.saveSetlist(setlist)
            await loadSetlists()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSetlist(id: UUID) async {
        do {
            try await storage.deleteSetlist(id: id)
            await loadSetlists()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameSetlist(id: UUID, name: String) async {
        guard var setlist = setlists.first(where: { $0.id == id }) else { return }
        setlist.updateName(name)
        do {
            try await storage.saveSetlist(setlist)
            await loadSetlists()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addSongToSetlist(setlistId: UUID, songPath: String, title: String, artist: String? = nil) async {
        guard var setlist = setlists.first(where: { $0.id == setlistId }) else { return }
        let item = SetListItem(
            songPath: songPath,
            songTitle: title,
            songArtist: artist,
            position: setlist.items.count
        )
        setlist.addItem(item)
        do {
            try await storage.saveSetlist(setlist)
            await loadSetlists()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeSongFromSetlist(setlistId: UUID, itemId: UUID) async {
        guard var setlist = setlists.first(where: { $0.id == setlistId }) else { return }
        if let index = setlist.items.firstIndex(where: { $0.id == itemId }) {
            setlist.removeItem(at: index)
            do {
                try await storage.saveSetlist(setlist)
                await loadSetlists()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Backup / Restore

    /// Shows the restore prompt if the setlist library is empty but a backup file exists.
    /// Call after `loadSetlists()`.
    func checkForAutoRestore() async {
        guard setlists.isEmpty else { return }
        if await backupManager.backupExists() {
            showingBackupRestorePrompt = true
        }
    }

    func exportSetlists() async {
        let success = await backupManager.exportSetlists(setlists)
        if !success {
            errorMessage = "Failed to export setlists backup."
        }
    }

    func importSetlistsFromBackup() async {
        guard let backedUp = await backupManager.readBackupSetlists() else {
            errorMessage = "No setlist backup file found."
            return
        }
        do {
            for setlist in backedUp {
                try await storage.saveSetlist(setlist)
            }
            await loadSetlists()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reorderSongs(setlistId: UUID, from source: IndexSet, to destination: Int) async {
        guard var setlist = setlists.first(where: { $0.id == setlistId }) else { return }
        if let fromIndex = source.first {
            setlist.moveItem(from: fromIndex, to: destination)
            do {
                try await storage.saveSetlist(setlist)
                await loadSetlists()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
