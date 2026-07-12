# FreeSong iOS Port Plan

## Overview
Port FreeSong from Android (Java) to iOS (Swift/SwiftUI) as a clean native app.
- **Target**: iOS 16+, iPadOS 16+, macOS 13+ (Mac Catalyst)
- **Language**: Swift 5.9+ with strict concurrency
- **UI**: SwiftUI (primary), minimal UIKit (song viewer canvas if needed)
- **Architecture**: MVVM + Repository pattern, pure Swift business logic first

---

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                        SwiftUI Views                          │
│  LibraryView • SongViewer • SetlistEditor • Settings • Sync   │
├─────────────────────────────────────────────────────────────┤
│                      ViewModels (Observable)                  │
│  LibraryVM • SongViewerVM • SetlistVM • SyncVM • SettingsVM   │
├─────────────────────────────────────────────────────────────┤
│                    Repository Interfaces                      │
│  SongRepository • SetlistRepository • SyncRepository          │
├─────────────────────────────────────────────────────────────┤
│                    Repository Implementations                 │
│  FileSongRepo • CoreDataSetlistRepo • GitHubSyncRepo          │
├─────────────────────────────────────────────────────────────┤
│                      Core Domain (Pure Swift)                 │
│  Song • SongParser • Transposer • NashvilleConverter          │
│  ChordFormatConverter • AccidentalConverter • Models          │
├─────────────────────────────────────────────────────────────┤
│                     Platform Services                         │
│  FileManager • ZipFoundation • SQLite.swift • URLSession      │
└─────────────────────────────────────────────────────────────┘
```

### Module Structure (SPM Package)
```
FreeSong/
├── Package.swift
├── Sources/
│   ├── FreeSongCore/           # Pure Swift domain (no platform deps)
│   │   ├── Models/
│   │   │   ├── Song.swift
│   │   │   ├── SongSection.swift
│   │   │   ├── SongLine.swift
│   │   │   ├── ChordPosition.swift
│   │   │   ├── KeyChange.swift
│   │   │   └── SetList.swift
│   │   ├── Parsing/
│   │   │   ├── SongParser.swift
│   │   │   ├── Transposer.swift
│   │   │   ├── NashvilleConverter.swift
│   │   │   ├── ChordFormatConverter.swift
│   │   │   └── AccidentalConverter.swift
│   │   └── FreeSongCore.swift
│   ├── FreeSongStorage/        # Persistence (Core Data + File)
│   │   ├── SongRepository.swift (protocol)
│   │   ├── FileSongRepository.swift
│   │   ├── SetlistRepository.swift (protocol)
│   │   ├── CoreDataSetlistRepository.swift
│   │   ├── MetadataCache.swift (JSON file-based)
│   │   └── FreeSongStorage.swift
│   ├── FreeSongImport/         # OnSong backup import
│   │   ├── BackupImporter.swift
│   │   ├── OnSongDatabaseReader.swift
│   │   └── FreeSongImport.swift
│   ├── FreeSongSync/           # GitHub sync
│   │   ├── GitHubAPIClient.swift
│   │   ├── GitHubSyncManager.swift
│   │   ├── SyncRepository.swift (protocol)
│   │   └── FreeSongSync.swift
│   └── FreeSongApp/            # SwiftUI App + Views
│       ├── FreeSongApp.swift
│       ├── Views/
│       │   ├── LibraryView.swift
│       │   ├── SongViewerView.swift
│       │   ├── SetlistView.swift
│       │   ├── EditorView.swift
│       │   ├── ImportView.swift
│       │   ├── SyncView.swift
│       │   └── SettingsView.swift
│       ├── ViewModels/
│       │   ├── LibraryViewModel.swift
│       │   ├── SongViewerViewModel.swift
│       │   ├── SetlistViewModel.swift
│       │   ├── EditorViewModel.swift
│       │   ├── ImportViewModel.swift
│       │   ├── SyncViewModel.swift
│       │   └── SettingsViewModel.swift
│       └── Components/
│           ├── ChordTextView.swift
│           ├── AutoScrollView.swift
│           └── KeyCommandHandler.swift
└── Tests/
    ├── FreeSongCoreTests/
    ├── FreeSongStorageTests/
    ├── FreeSongImportTests/
    ├── FreeSongSyncTests/
    └── FreeSongAppUITests/
```

---

## Dependencies (Swift Package Manager)

```swift
// Package.swift
dependencies: [
    // Core Data is built-in (no SPM needed)
    
    // ZIP handling for OnSong .backup import
    .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
    
    // SQLite for reading OnSong database (read-only)
    .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.0"),
    
    // Optional: GitHub API (can use native URLSession instead)
    // .package(url: "https://github.com/nerdishbynature/octokit.swift.git", from: "0.10.0"),
    
    // Testing
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.15.0"),
]
```

**Platform Frameworks** (no SPM):
- `Foundation`, `SwiftUI`, `CoreData`, `UniformTypeIdentifiers`, `Combine`

---

## Build Order & Implementation Phases

### Phase 0: Project Setup (Day 1)
- [ ] Create Xcode project / SPM package structure
- [ ] Configure `Package.swift` with dependencies
- [ ] Set up Core Data model (`FreeSong.xcdatamodeld`)
- [ ] Configure build settings (iOS 16+, Swift 6 language mode)
- [ ] Add `.swiftlint.yml`, `.github/workflows/ci.yml`

### Phase 1: Core Domain — Pure Swift (Days 2–5)
**Zero platform dependencies. Fully unit-testable.**

| Order | File | Est. Lines | Tests |
|-------|------|------------|-------|
| 1.1 | `Models/Song.swift` + related | ~200 | ✅ |
| 1.2 | `Parsing/Transposer.swift` | ~150 | ✅ |
| 1.3 | `Parsing/AccidentalConverter.swift` | ~100 | ✅ |
| 1.4 | `Parsing/NashvilleConverter.swift` | ~200 | ✅ |
| 1.5 | `Parsing/ChordFormatConverter.swift` | ~250 | ✅ |
| 1.6 | `Parsing/SongParser.swift` | ~500 | ✅ |

**Test Strategy**: Port Android test cases + add property-based tests (chord parsing round-trips, transposition inverses).

### Phase 2: Storage Layer (Days 6–9)

| Order | Component | Technology | Notes |
|-------|-----------|------------|-------|
| 2.1 | `MetadataCache` | JSON file (`~/Library/Application Support/FreeSong/metadata.json`) | Replaces SQLite cache; ~instant load |
| 2.2 | `FileSongRepository` | FileManager + MetadataCache | Scan `~/Documents/FreeSong/` (Files app) |
| 2.3 | Core Data Model | `SetList`, `SetListItem` entities | Auto-migration enabled |
| 2.4 | `CoreDataSetlistRepository` | Core Data + NSFetchedResultsController | SwiftUI `@FetchRequest` integration |
| 2.5 | `SetlistBackupManager` | JSON (iCloud Drive + local) | `UIDocument` for iCloud sync |

**File Locations**:
- Songs: `~/Documents/FreeSong/` (user-visible in Files app)
- Metadata cache: `~/Library/Application Support/FreeSong/metadata.json`
- Setlist backup: `~/Documents/FreeSong/setlists-backup.json` + iCloud Drive

### Phase 3: OnSong Import (Days 10–12)

| Component | Implementation |
|-----------|----------------|
| `BackupImporter` | `ZIPFoundation` for `.zip`/`.backup` extraction |
| `OnSongDatabaseReader` | `SQLite.swift` read-only: `SELECT title, byline, key, content FROM Song` |
| Setlist import | `SongSet` + `SongSetItem` joins → Core Data |
| Encoding | Mac Roman (`x-mac-roman`) → UTF-8 via `String(data:encoding:)` |
| Binary detection | Port `detectBinaryContent()` logic (PDF, PNG, JPEG, etc.) |

### Phase 4: GitHub Sync (Days 13–16)

| Component | Implementation |
|-----------|----------------|
| `GitHubAPIClient` | `URLSession` + `async/await`, `Codable` request/response |
| Auth | Personal Access Token (Classic) + Keychain (`GenericPassword`) |
| Batch upload | Git Trees API: `createBlob` → `createTree` → `createCommit` → `updateRef` |
| `GitHubSyncManager` | Actor-based, `async` sync with `Progress` reporting |
| Conflict resolution | MD5 hash compare → `*_conflict` suffix for local version |

**Endpoints Used**:
- `GET /repos/{owner}/{repo}/contents/{path}`
- `PUT /repos/{owner}/{repo}/contents/{path}`
- `POST /repos/{owner}/{repo}/git/blobs`
- `POST /repos/{owner}/{repo}/git/trees`
- `POST /repos/{owner}/{repo}/git/commits`
- `PATCH /repos/{owner}/{repo}/git/refs/heads/{branch}`

### Phase 5: SwiftUI App & Views (Days 17–25)

| View | Key Features |
|------|--------------|
| `LibraryView` | File browser (Documents/FreeSong), search, pull-to-refresh, swipe actions |
| `SongViewerView` | **Chords above lyrics** (monospace), pinch zoom, auto-scroll (Timer + ScrollViewProxy), Bluetooth page turner (UIKeyCommand / .onKeyPress), transpose ±12, Nashville toggle, sharp/flat toggle |
| `SetlistView` | Reorder (drag-drop), rename, delete, notes per song, export JSON |
| `EditorView` | Syntax-highlighted text editor (OnSong/ChordPro), live preview split, validation |
| `ImportView` | DocumentPicker for `.backup`/`.zip`, progress, result summary |
| `SyncView` | GitHub auth, repo picker, sync status, conflict review |
| `SettingsView` | Theme, font size, auto-scroll speed, default transpose, iCloud toggle |

**Custom Components**:
- `ChordTextView`: `AttributedString` with chord coloring, monospace alignment
- `AutoScrollView`: `Timer.publish(every:)` + `ScrollViewProxy.scrollTo()`
- `KeyCommandHandler`: `.onKeyPress(.pageDown)` / `.pageUp` + `UIKeyCommand` for external keyboards

### Phase 6: Polish & QA (Days 26–30)
- [ ] Accessibility (VoiceOver, Dynamic Type, contrast)
- [ ] iPad multitasking (split view, slide over)
- [ ] macOS Catalyst tweaks (toolbar, menu bar)
- [ ] Performance: Large song sets (1000+), 100+ setlists
- [ ] TestFlight beta → App Store

---

## Testing Strategy

### Unit Tests (Target: >90% coverage on Core Domain)
```swift
// FreeSongCoreTests/
// - SongParserTests: OnSong, ChordPro, plain text, edge cases
// - TransposerTests: All intervals, slash chords, unicode, round-trip
// - NashvilleConverterTests: Major/minor keys, qualities preserved
// - ChordFormatConverterTests: Inline↔Above round-trip, overlap handling
// - AccidentalConverterTests: Sharp↔Flat, detection, slash chords
// - ModelTests: Codable, equality, KeyChange positioning
```

### Integration Tests
```swift
// FreeSongStorageTests/
// - FileSongRepository: scan, cache invalidation, metadata persistence
// - CoreDataSetlistRepository: CRUD, reorder, cascade delete
// - MetadataCache: hit/miss, stale removal, concurrent access

// FreeSongImportTests/
// - BackupImporter: ZIP with/without DB, binary skip, encoding
// - OnSongDatabaseReader: schema changes, empty fields

// FreeSongSyncTests/ (mocked GitHub API)
// - GitHubAPIClient: request signing, pagination, error mapping
// - GitHubSyncManager: download/upload/conflict flows, batching
```

### UI Tests (Snapshot + Interaction)
```swift
// FreeSongAppUITests/
// - LibraryView: empty state, loaded, search, import flow
// - SongViewerView: chord rendering, transpose, scroll, page turner
// - SetlistView: drag reorder, notes, export
// - Snapshot tests: light/dark, iPhone/iPad, Dynamic Type sizes
```

### Property-Based Tests (SwiftCheck / custom)
- Transposition: `transpose(transpose(song, n), -n) == song`
- Format conversion: `aboveToInline(inlineToAbove(s)) == s` (modulo whitespace)
- Nashville: `toNashville(toChord(n, key)) == n` (for diatonic chords)

---

## Key Technical Decisions

| Area | Decision | Rationale |
|------|----------|-----------|
| **Song storage** | Files in `~/Documents/FreeSong/` | User-accessible via Files app, iCloud Drive sync, survives app deletion |
| **Metadata cache** | JSON file (not SQLite) | Simpler, fast enough (<100ms for 1000 songs), no migration |
| **Setlists** | Core Data | Native SwiftUI `@FetchRequest`, relationships, undo manager, CloudKit ready |
| **OnSong import** | ZipFoundation + SQLite.swift | Mature Swift packages, read-only DB access |
| **GitHub sync** | Native URLSession + Git Trees API | Zero dependencies, batch commits = fast, reliable |
| **Auto-scroll** | Timer + ScrollViewProxy | Simple, precise, works with variable line heights |
| **Bluetooth page turner** | `UIKeyCommand` + `.onKeyPress` | Handles both external keyboards and HID page-turners |
| **Chord rendering** | `AttributedString` (iOS 15+) | Native, accessible, performant, no custom drawing |

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| OnSong SQLite schema changes | Read-only, defensive column checks, graceful degradation |
| GitHub API rate limits | Batch upload (25/blobs), exponential backoff, `If-None-Match` |
| Large song files (>1MB) | Streaming read, chunked upload via blob API |
| iCloud Drive conflicts | `NSFileCoordinator`, conflict resolution UI |
| macOS Catalyst quirks | Separate `if targetEnvironment(macCatalyst)` code paths |

---

## Deliverables Checklist

- [ ] `FreeSongCore` package (pure Swift, 100% tested)
- [ ] `FreeSongStorage` package (Core Data + File)
- [ ] `FreeSongImport` package (OnSong backup)
- [ ] `FreeSongSync` package (GitHub)
- [ ] `FreeSongApp` (SwiftUI, iPhone + iPad + Mac)
- [ ] CI: lint, test, build on every PR
- [ ] TestFlight build with release notes
- [ ] App Store metadata (screenshots, description, privacy policy)

---

## Estimated Timeline

| Phase | Duration | Cumulative |
|-------|----------|------------|
| 0: Setup | 1 day | 1 |
| 1: Core Domain | 4 days | 5 |
| 2: Storage | 4 days | 9 |
| 3: Import | 3 days | 12 |
| 4: Sync | 4 days | 16 |
| 5: UI | 9 days | 25 |
| 6: Polish/QA | 5 days | 30 |
| **Total** | **~30 working days** | **6 weeks** |

---

## Next Action
Start **Phase 1.1**: Create `FreeSongCore/Models/Song.swift` with all related models (`SongSection`, `SongLine`, `ChordPosition`, `KeyChange`, `SetList`, `SetListItem`). Port directly from `Song.java` with Swift `Codable` and value semantics.