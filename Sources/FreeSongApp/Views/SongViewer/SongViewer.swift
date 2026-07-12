import SwiftUI
import FreeSongCore
import FreeSongStorage

/// Thin wrapper that swaps in freshly-saved content after editing. The inner
/// content owns the view model, so bumping `reloadCount` (via `.id`) rebuilds it
/// against the reloaded song rather than the stale initial snapshot.
///
/// When opened from the (filtered) library, `songs`/`startIndex` give it the sibling
/// list so the user can swipe or tap the screen edges to move to the next/previous
/// song — mirrors `SetlistPlayerView`'s navigation, and reuses the same reload-via-`.id`
/// mechanism so transposition/Nashville state resets on every song change.
struct SongViewer: View {
    let song: Song
    var songs: [Song] = []
    var startIndex: Int = 0

    @State private var currentSong: Song?
    @State private var reloadCount = 0
    @State private var index: Int

    init(song: Song, songs: [Song] = [], startIndex: Int = 0) {
        self.song = song
        self.songs = songs
        self.startIndex = startIndex
        _index = State(initialValue: startIndex)
    }

    private var hasNavigation: Bool { songs.count > 1 }

    private var activeSong: Song {
        if let currentSong { return currentSong }
        if hasNavigation, songs.indices.contains(index) { return songs[index] }
        return song
    }

    private func navigate(by direction: Int) {
        let newIndex = index + direction
        guard songs.indices.contains(newIndex) else { return }
        index = newIndex
        currentSong = nil
        reloadCount += 1
    }

    var body: some View {
        SongViewerContent(
            song: activeSong,
            position: hasNavigation ? (index + 1, songs.count) : nil,
            onNavigate: hasNavigation ? navigate : nil,
            onSaved: { updated in
                currentSong = updated
                reloadCount += 1
            }
        )
        // simultaneousGesture + horizontal-dominance check so the swipe never
        // fights the vertical ScrollView pan.
        .simultaneousGesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    guard hasNavigation else { return }
                    let w = value.translation.width
                    let h = value.translation.height
                    guard abs(w) > abs(h), abs(w) > 50 else { return }
                    navigate(by: w < 0 ? 1 : -1)
                }
        )
        .id(reloadCount)
    }
}

private struct SongViewerContent: View {
    let song: Song
    var position: (index: Int, total: Int)?
    var onNavigate: ((Int) -> Void)?
    let onSaved: (Song) -> Void
    @StateObject private var viewModel: SongViewerViewModel
    @State private var showEditor = false
    @State private var showChordReference = false
    @Environment(\.dismiss) private var dismiss
    private let repository = FileSongRepository.shared

    init(
        song: Song,
        position: (index: Int, total: Int)? = nil,
        onNavigate: ((Int) -> Void)? = nil,
        onSaved: @escaping (Song) -> Void
    ) {
        self.song = song
        self.position = position
        self.onNavigate = onNavigate
        self.onSaved = onSaved
        _viewModel = StateObject(wrappedValue: SongViewerViewModel(song: song))
    }

    private func reloadSong() {
        let path = song.sourcePath ?? "\(song.title).onsong"
        Task {
            if let updated = try? await repository.getSong(at: path) {
                onSaved(updated)
            }
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header

                    Divider()

                    songContent
                        .padding()
                }
            }
            .onChange(of: viewModel.autoScrollTargetLabel) { target in
                if let id = target {
                    withAnimation(.smooth) {
                        proxy.scrollTo(id, anchor: .top)
                    }
                }
            }
        }
        .navigationTitle(position.map { "\($0.index) / \($0.total)" } ?? song.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }

                Button {
                    showChordReference = true
                } label: {
                    Label("Chords", systemImage: "questionmark.circle")
                }
            }
            #endif
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showEditor) {
            SongEditorView(song: song, onSave: { reloadSong() }, onDelete: { dismiss() })
        }
        #else
        .sheet(isPresented: $showEditor) {
            SongEditorView(song: song, onSave: { reloadSong() }, onDelete: { dismiss() })
        }
        #endif
        .sheet(isPresented: $showChordReference) {
            ChordReferenceView()
        }
        .confirmationDialog("Select a Key", isPresented: $viewModel.showNashvilleKeyPicker, titleVisibility: .visible) {
            ForEach(NashvilleConverter.getCommonKeys(), id: \.self) { key in
                Button(key) { viewModel.selectNashvilleKey(key) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This song has no key set. Pick one to display Nashville numbers.")
        }
        #if os(iOS)
        .safeAreaInset(edge: .top) {
            if viewModel.showScrollSpeedSlider {
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "tortoise")
                        Slider(value: $viewModel.autoScrollInterval, in: 1...15, step: 0.5)
                        Image(systemName: "hare")
                        Text("\(Int(viewModel.autoScrollInterval))s")
                            .font(.caption.monospacedDigit())
                            .frame(width: 28)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 6)
                .background(.bar)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                Button(viewModel.isAutoScrolling ? "Stop" : "Auto-Scroll") {
                    viewModel.toggleAutoScroll()
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(viewModel.isAutoScrolling ? .accentColor : nil)

                Button {
                    viewModel.showScrollSpeedSlider.toggle()
                } label: {
                    Image(systemName: "timer")
                }
                .font(.caption)
            }

            ToolbarItemGroup(placement: .bottomBar) {
                // [−] key [+] — Android-style up/down transpose; tapping the key resets.
                Button {
                    viewModel.transpose(by: -1)
                } label: {
                    Image(systemName: "minus")
                }
                Button(transposeKeyLabel) {
                    viewModel.resetTranspose()
                }
                .font(.subheadline.weight(.semibold).monospacedDigit())
                Button {
                    viewModel.transpose(by: 1)
                } label: {
                    Image(systemName: "plus")
                }
                Spacer()
                Button(viewModel.useFlats ? "♭" : "♯") {
                    viewModel.toggleFlats()
                }
                Spacer()
                Button(viewModel.useNashville ? "1-7" : "A-G") {
                    viewModel.toggleNashville()
                }
                Spacer()
                menuFontSize
            }
        }
        #else
        .toolbar {
            ToolbarItemGroup {
                Button {
                    viewModel.transpose(by: -1)
                } label: {
                    Image(systemName: "minus")
                }
                Button(transposeKeyLabel) {
                    viewModel.resetTranspose()
                }
                Button {
                    viewModel.transpose(by: 1)
                } label: {
                    Image(systemName: "plus")
                }
                Spacer()
                Button(viewModel.useFlats ? "Flats" : "Sharps") {
                    viewModel.toggleFlats()
                }
                Spacer()
                Button(viewModel.useNashville ? "Nashville" : "Chords") {
                    viewModel.toggleNashville()
                }
            }
        }
        #endif
    }

    /// Current (transposed) key shown between the −/+ buttons; annotated with the
    /// offset ("G +2") when transposed so the tap-to-reset affordance is discoverable.
    private var transposeKeyLabel: String {
        let offset = viewModel.transposeOffset
        let suffix = offset == 0 ? "" : (offset > 0 ? "+\(offset)" : "\(offset)")
        if let key = viewModel.transposedSong.key, !key.isEmpty {
            return suffix.isEmpty ? key : "\(key) \(suffix)"
        }
        return suffix.isEmpty ? "Key" : suffix
    }

    private var menuFontSize: some View {
        Menu {
            ForEach([14, 16, 18, 20, 22, 24, 28], id: \.self) { size in
                Button("\(size)") { viewModel.fontSize = Double(size) }
            }
        } label: {
            Label("\(Int(viewModel.fontSize))", systemImage: "textformat.size")
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text(song.title)
                .font(.title2.weight(.bold))

            if let artist = song.artist {
                Text(artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let key = song.key {
                Text("Key: \(key)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.accent.opacity(0.1)))
            }

            if viewModel.transposeOffset != 0 {
                Text("Transposed \(viewModel.transposeOffset > 0 ? "+" : "")\(viewModel.transposeOffset)")
                    .font(.caption)
                    .foregroundStyle(.accent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var songContent: some View {
        let sections = viewModel.transposedSong.sections
        return VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                VStack(alignment: .leading, spacing: 4) {
                    if !section.label.isEmpty {
                        Text("[\(section.label)]")
                            .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 4)
                    }

                    ForEach(Array(section.lines.enumerated()), id: \.offset) { _, line in
                        ChordLineView(line: line, fontSize: viewModel.fontSize)
                    }
                }
                .id(section.label.isEmpty ? "section-\(index)" : section.label)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(navigationEdgeTaps)
    }

    /// Left/right 15%-wide tap zones over the song content for prev/next navigation,
    /// mirroring the Android edge-tap gesture. Scoped to the content area (not the
    /// header/controls above it) so it never shadows a button.
    @ViewBuilder
    private var navigationEdgeTaps: some View {
        if let onNavigate {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onNavigate(-1) }
                        .frame(width: geo.size.width * 0.15)
                    Spacer()
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onNavigate(1) }
                        .frame(width: geo.size.width * 0.15)
                }
            }
        }
    }
}

#Preview("SongViewer") {
    NavigationStack {
        SongViewer(song: Song(
            title: "Amazing Grace",
            artist: "John Newton",
            key: "G",
            sections: [
                SongSection(label: "Verse", lines: [
                    SongLine(lyrics: "Amazing grace how sweet the sound", chords: [
                        ChordPosition(chord: "G", position: 0),
                        ChordPosition(chord: "D", position: 17),
                    ]),
                    SongLine(lyrics: "That saved a wretch like me"),
                ])
            ]
        ))
    }
}
