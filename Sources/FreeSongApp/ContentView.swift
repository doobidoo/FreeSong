import SwiftUI
import FreeSongCore
import FreeSongStorage

// MARK: - Navigation Sections

/// Navigation sections of the app.
enum AppSection: String, CaseIterable, Identifiable {
    case library
    case setlists
    case importBackup
    case settings
    /// Screenshot-only: shows a song viewer for a song title from UserDefaults (FREESONG_SONG_TITLE).
    case songViewer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library: return "Songs"
        case .setlists: return "Setlists"
        case .importBackup: return "Import"
        case .settings: return "Settings"
        case .songViewer: return "Song"
        }
    }

    var icon: String {
        switch self {
        case .library: return "music.note.list"
        case .setlists: return "list.star"
        case .importBackup: return "square.and.arrow.down"
        case .settings: return "gearshape"
        case .songViewer: return "music.note"
        }
    }
}

// MARK: - Navigation Destination



enum NavigationDestination: Hashable {
    /// `songs`/`index` give the viewer the sibling list for next/prev navigation when
    /// opened from the (filtered) library; omit for single-song entry points.
    case song(Song, songs: [Song] = [], index: Int = 0)

    static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.song(let a, _, _), .song(let b, _, _)):
            return a.title == b.title && a.artist == b.artist
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .song(let s, _, _):
            hasher.combine(s.title)
            hasher.combine(s.artist)
        }
    }
}

// MARK: - Root Content View

/// Root view with adaptive navigation:
/// - Regular width (iPad/Mac): NavigationSplitView with sidebar + detail
/// - Compact width (iPhone): TabView with per-tab NavigationStack
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("darkMode") private var darkMode = false
    @State private var selectedSection: AppSection?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var navigationPath: [NavigationDestination] = []

    /// Create ContentView with optional initial section override.
    /// Used for screenshot automation — pass via `simctl launch` arguments:
    ///   `xcrun simctl launch <device> <bundle> -FREESONG_VIEW library`
    init(initialSection: AppSection? = nil) {
        let section = initialSection
            ?? UserDefaults.standard.string(forKey: "FREESONG_VIEW")
            .flatMap { AppSection(rawValue: $0) }
            ?? ProcessInfo.processInfo.environment["FREESONG_VIEW"]
            .flatMap { AppSection(rawValue: $0) }
            ?? .library
        _selectedSection = State(initialValue: section)
    }

    var body: some View {
        Group {
            if sizeClass == .compact {
                compactBody
            } else {
                regularBody
            }
        }
        .preferredColorScheme(darkMode ? .dark : nil)
    }

    // MARK: - Compact (iPhone)

    private var compactBody: some View {
        TabView(selection: $selectedSection) {
            NavigationStack(path: $navigationPath) {
                SongLibraryView(
                    autoplaySongTitle: UserDefaults.standard.string(forKey: "FREESONG_SONG_TITLE"),
                    navigationPath: $navigationPath
                )
                .navigationDestination(for: NavigationDestination.self) { dest in
                    switch dest {
                    case .song(let song, let songs, let index):
                        SongViewer(song: song, songs: songs, startIndex: index)
                    }
                }
            }
            .tabItem { Label("Songs", systemImage: "music.note.list") }
            .tag(AppSection.library)

            NavigationStack {
                SetlistListView()
            }
            .tabItem { Label("Setlists", systemImage: "list.star") }
            .tag(AppSection.setlists)

            NavigationStack {
                ImportView()
            }
            .tabItem { Label("Import", systemImage: "square.and.arrow.down") }
            .tag(AppSection.importBackup)

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(AppSection.settings)
        }
    }

    // MARK: - Regular (iPad / Mac)

    private var regularBody: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
        } detail: {
            NavigationStack(path: $navigationPath) {
                detailContent(for: selectedSection)
                    .navigationDestination(for: NavigationDestination.self) { dest in
                        switch dest {
                        case .song(let song, let songs, let index):
                            SongViewer(song: song, songs: songs, startIndex: index)
                        }
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: $selectedSection) {
            ForEach(AppSection.allCases.filter { $0 != .songViewer }) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.icon)
                }
            }
        }
        .navigationTitle("FreeSong")
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        #endif
    }

    // MARK: Detail

    @ViewBuilder
    private func detailContent(for section: AppSection?) -> some View {
        switch section {
        case .library:
            SongLibraryView(
                autoplaySongTitle: UserDefaults.standard.string(forKey: "FREESONG_SONG_TITLE"),
                navigationPath: $navigationPath
            )
        case .setlists:
            SetlistListView()
        case .importBackup:
            ImportView()
        case .settings:
            SettingsView()
        case .songViewer:
            SongViewerScreen()
        case nil:
            placeholder
        }
    }

    private var placeholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.quarternote.3")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("FreeSong")
                .font(.largeTitle.bold())
            Text("Your chord sheet library")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("ContentView") {
    ContentView()
}
