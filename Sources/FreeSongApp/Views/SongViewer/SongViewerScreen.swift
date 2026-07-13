import SwiftUI
import FreeSongCore
import FreeSongStorage

/// Screenshot-only view that loads a song by title from UserDefaults (key: FREESONG_SONG_TITLE)
/// and displays it using SongViewer. Not shown in the sidebar.
struct SongViewerScreen: View {
    @State private var song: Song?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var didAttemptLoad = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading song\u{2026}")
            } else if let song {
                SongViewer(song: song)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "questionmark.square.dashed")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text(errorMessage ?? "Song not found")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            guard !didAttemptLoad else { return }
            didAttemptLoad = true

            let title = UserDefaults.standard.string(forKey: "FREESONG_SONG_TITLE") ?? ""
            UserDefaults.standard.removeObject(forKey: "FREESONG_SONG_TITLE")

            let repo = FileSongRepository.shared
            do {
                let songs = try await repo.getAllSongs()
                song = songs.first(where: { $0.title == title })
                if song == nil {
                    errorMessage = "Song \"\(title)\" not found"
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
