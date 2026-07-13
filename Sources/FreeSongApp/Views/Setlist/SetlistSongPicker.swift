import SwiftUI
import FreeSongCore
import FreeSongStorage

struct SetlistSongPicker: View {
    @ObservedObject var viewModel: SetlistEditorViewModel
    let setlistId: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery = ""
    @State private var allSongs: [Song] = []
    @State private var addedTitles = Set<String>()
    @State private var isLoading = true

    private let songRepo = FileSongRepository.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading songs…")
                } else {
                    List(filteredSongs, id: \.title) { song in
                        Button {
                            addSong(song)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(song.title)
                                        .font(.body)
                                    if let artist = song.artist {
                                        Text(artist)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if addedTitles.contains(song.title) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.accent)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .searchable(text: $searchQuery, prompt: "Search songs")
                }
            }
            .navigationTitle("Add Songs")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            allSongs = (try? await songRepo.getAllSongs()) ?? []
            isLoading = false
        }
    }

    /// Song paths already in the target setlist, keyed by last path component so a
    /// bare "Title.onsong" entry (from before sourcePath tracking) still matches a
    /// full resolved path for the same file.
    private var existingSongPaths: Set<String> {
        guard let setlist = viewModel.setlists.first(where: { $0.id == setlistId }) else { return [] }
        return Set(setlist.items.map { pathKey($0.songPath) })
    }

    private func pathKey(_ path: String) -> String {
        (path as NSString).lastPathComponent
    }

    private var filteredSongs: [Song] {
        let notAdded = allSongs.filter { !existingSongPaths.contains(pathKey(songPath(for: $0))) }
        guard !searchQuery.isEmpty else { return notAdded }
        let q = searchQuery.lowercased()
        return notAdded.filter {
            $0.title.lowercased().contains(q) ||
            ($0.artist ?? "").lowercased().contains(q)
        }
    }

    private func songPath(for song: Song) -> String {
        song.sourcePath ?? "\(song.title).onsong"
    }

    private func addSong(_ song: Song) {
        guard !addedTitles.contains(song.title) else { return }
        addedTitles.insert(song.title)
        let path = songPath(for: song)
        Task {
            await viewModel.addSongToSetlist(
                setlistId: setlistId,
                songPath: path,
                title: song.title,
                artist: song.artist
            )
        }
    }
}
