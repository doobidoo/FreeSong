import SwiftUI
import FreeSongCore
import FreeSongStorage

struct SongLibraryView: View {
    @StateObject private var viewModel = SongLibraryViewModel()
    @Binding var navigationPath: [NavigationDestination]

    /// Optional song title to auto-navigate to (used for screenshot automation).
    let autoplaySongTitle: String?
    /// Prevents re-triggering autoplay after the first appearance (e.g. on back navigation).
    @State private var didAttemptAutoplay = false
    @State private var showingSetlistPicker = false
    @State private var selectedSongForSetlist: Song?
    @State private var setlists: [SetList] = []
    private let setlistRepo = CoreDataSetlistRepository()

    init(autoplaySongTitle: String? = nil, navigationPath: Binding<[NavigationDestination]> = .constant([])) {
        self.autoplaySongTitle = autoplaySongTitle
            ?? UserDefaults.standard.string(forKey: "FREESONG_SONG_TITLE")
            ?? ProcessInfo.processInfo.environment["FREESONG_SONG_TITLE"]
        _navigationPath = navigationPath
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.songs.isEmpty {
                ProgressView("Loading songs…")
            } else if let error = viewModel.errorMessage, viewModel.songs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                    Text("Could not load songs")
                        .font(.headline)
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Try Again") { Task { await viewModel.loadSongs() } }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if viewModel.songs.isEmpty {
                EmptyStateView(
                    icon: "music.note.list",
                    title: "No Songs Yet",
                    message: "Import a backup or add songs to get started."
                )
            } else {
                songList
            }
        }
        .searchable(text: $viewModel.searchQuery, prompt: "Search songs")
        .navigationTitle("Songs")
        .task {
            guard !didAttemptAutoplay else { return }
            didAttemptAutoplay = true

            await viewModel.loadSongs()
            if let title = autoplaySongTitle,
               let index = viewModel.songs.firstIndex(where: { $0.title == title }) {
                try? await Task.sleep(nanoseconds: 500_000_000)
                navigationPath = [.song(viewModel.songs[index], songs: viewModel.songs, index: index)]
                UserDefaults.standard.removeObject(forKey: "FREESONG_SONG_TITLE")
            }
        }
        .refreshable { await viewModel.refresh() }
        .alert("Delete Song?", isPresented: Binding(
            get: { viewModel.songToDelete != nil },
            set: { if !$0 { viewModel.songToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { viewModel.songToDelete = nil }
            Button("Delete", role: .destructive) {
                Task { await viewModel.executeDelete() }
            }
        } message: {
            if let (song, _) = viewModel.songToDelete {
                Text("Delete \"\(song.title)\"? This cannot be undone.")
            }
        }
        .sheet(isPresented: $showingSetlistPicker) {
            setlistPickerSheet
        }
    }

    private var songList: some View {
        List {
            Section {
                let total = viewModel.songs.count
                let filtered = viewModel.filteredSongs.count
                Text(viewModel.searchQuery.isEmpty ? "\(total) songs" : "\(filtered) of \(total) songs")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 16))
            }
            ForEach(Array(viewModel.filteredSongs.enumerated()), id: \.element.title) { index, song in
                NavigationLink(value: NavigationDestination.song(song, songs: viewModel.filteredSongs, index: index)) {
                    SongRow(song: song)
                }
                .contextMenu {
                    Button {
                        navigationPath.append(.song(song, songs: viewModel.filteredSongs, index: index))
                    } label: {
                        Label("Open", systemImage: "music.note")
                    }

                    Button {
                        selectedSongForSetlist = song
                        Task {
                            setlists = (try? await setlistRepo.getAllSetlists()) ?? []
                            showingSetlistPicker = true
                        }
                    } label: {
                        Label("Add to Setlist", systemImage: "list.star")
                    }

                    Divider()

                    Button(role: .destructive) {
                        viewModel.confirmDelete(song)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }


    private var setlistPickerSheet: some View {
        NavigationStack {
            Group {
                if setlists.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "list.star")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("No Setlists")
                            .font(.headline)
                        Text("Create a setlist first, then add songs to it.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    List(setlists) { setlist in
                        Button {
                            if let song = selectedSongForSetlist {
                                Task {
                                    let repo = SetlistEditorViewModel()
                                    await repo.addSongToSetlist(
                                        setlistId: setlist.id,
                                        songPath: song.sourcePath ?? "\(song.title).onsong",
                                        title: song.title,
                                        artist: song.artist
                                    )
                                    showingSetlistPicker = false
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(setlist.name)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text("\(setlist.items.count) songs")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Setlist")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingSetlistPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview("With Songs") {
    NavigationStack {
        SongLibraryView()
    }
}
