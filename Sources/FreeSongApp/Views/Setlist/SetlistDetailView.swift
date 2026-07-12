import SwiftUI
import FreeSongCore
import FreeSongStorage

struct SetlistDetailView: View {
    let setlist: SetList
    @ObservedObject var viewModel: SetlistEditorViewModel
    @State private var showingSongPicker = false
    @State private var showingRenameAlert = false
    @State private var renameText = ""
    @State private var isPlayingSetlist = false

    var body: some View {
        List {
            ForEach(currentItems) { item in
                HStack {
                    Image(systemName: "music.note")
                        .foregroundStyle(.accent)
                    VStack(alignment: .leading) {
                        Text(item.songTitle)
                            .font(.body)
                        if let artist = item.songArtist, !artist.isEmpty {
                            Text(artist)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await viewModel.removeSongFromSetlist(setlistId: setlist.id, itemId: item.id) }
                    } label: {
                        Label("Remove", systemImage: "minus.circle")
                    }
                }
            }
            .onMove { source, destination in
                Task { await viewModel.reorderSongs(setlistId: setlist.id, from: source, to: destination) }
            }
        }
        .listStyle(.plain)
        .navigationTitle(setlist.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if !currentItems.isEmpty {
                    Button {
                        isPlayingSetlist = true
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                }
                Button("Add Songs") { showingSongPicker = true }
                Button("Rename") {
                    renameText = setlist.name
                    showingRenameAlert = true
                }
            }
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            #endif
        }
        .sheet(isPresented: $showingSongPicker) {
            SetlistSongPicker(viewModel: viewModel, setlistId: setlist.id)
        }
        .fullScreenCover(isPresented: $isPlayingSetlist) {
            SetlistPlayerView(items: currentItems)
        }
        .alert("Rename Setlist", isPresented: $showingRenameAlert) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { }
            Button("Save") {
                Task { await viewModel.renameSetlist(id: setlist.id, name: renameText) }
            }
        }
    }

    private var currentItems: [SetListItem] {
        viewModel.setlists.first(where: { $0.id == setlist.id })?.items ?? setlist.items
    }
}

// MARK: - Setlist Player

struct SetlistPlayerView: View {
    let items: [SetListItem]
    @State private var currentIndex = 0
    @State private var songs: [String: Song] = [:]
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    private let repo = FileSongRepository.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading songs…")
                } else if let song = songs[items[currentIndex].songPath] {
                    SongViewer(song: song)
                        .gesture(
                            DragGesture(minimumDistance: 50)
                                .onEnded { value in
                                    if value.translation.width < -50, currentIndex < items.count - 1 {
                                        currentIndex += 1
                                    } else if value.translation.width > 50, currentIndex > 0 {
                                        currentIndex -= 1
                                    }
                                }
                        )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "questionmark.square.dashed")
                            .font(.system(size: 40)).foregroundStyle(.secondary)
                        Text("Song not found: \(items[currentIndex].songTitle)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("\(currentIndex + 1) / \(items.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        if currentIndex > 0 { currentIndex -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentIndex == 0)

                    Spacer()
                    Text(items[currentIndex].songTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()

                    Button {
                        if currentIndex < items.count - 1 { currentIndex += 1 }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(currentIndex == items.count - 1)
                }
            }
        }
        .task {
            await loadSongs()
        }
    }

    private func loadSongs() async {
        guard let allSongs = try? await repo.getAllSongs() else {
            isLoading = false
            return
        }
        let byTitle = Dictionary(allSongs.map { ($0.title, $0) }, uniquingKeysWith: { first, _ in first })
        for item in items {
            if let song = byTitle[item.songTitle] {
                songs[item.songPath] = song
            }
        }
        isLoading = false
    }
}
