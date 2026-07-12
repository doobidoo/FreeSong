import SwiftUI
import FreeSongCore
import FreeSongStorage

@MainActor
final class SongLibraryViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var searchQuery = ""

    private let repository: SongRepository
    private let setlistRepo: SetlistRepository
    /// Path of the song to delete (set triggers confirmation alert).
    @Published var songToDelete: (Song, String)?
    var showingDeleteConfirmation: Bool {
        get { songToDelete != nil }
        set { if !newValue { songToDelete = nil } }
    }

    init(
        repository: SongRepository = FileSongRepository.shared,
        setlistRepo: SetlistRepository = CoreDataSetlistRepository()
    ) {
        self.repository = repository
        self.setlistRepo = setlistRepo
    }

    var filteredSongs: [Song] {
        guard !searchQuery.isEmpty else { return songs }
        let query = searchQuery.lowercased()
        return songs.filter {
            $0.title.lowercased().contains(query) ||
            ($0.artist ?? "").lowercased().contains(query)
        }
    }

    func loadSongs() async {
        isLoading = true
        errorMessage = nil
        do {
            songs = try await repository.getAllSongs()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func refresh() async {
        await loadSongs()
    }

    /// Confirm deletion of a song (shows alert).
    func confirmDelete(_ song: Song) {
        let path = song.sourcePath ?? "\(song.title).onsong"
        songToDelete = (song, path)
    }

    /// Execute the deletion after confirmation.
    func executeDelete() async {
        guard let (_, path) = songToDelete else { return }
        songToDelete = nil
        do {
            // Remove from filesystem
            try await repository.deleteSong(at: path)
            // Remove from all setlists
            let containing = try await setlistRepo.getSetlistsContaining(songPath: path)
            for var setlist in containing {
                setlist.items.removeAll { $0.songPath == path }
                try await setlistRepo.saveSetlist(setlist)
            }
            await loadSongs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
