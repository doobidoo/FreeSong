# FreeSong iOS Port — Agent Handoff

## Mission

Port FreeSong from Android (Java) to iOS (Swift/SwiftUI). FreeSong is a chord sheet and lyrics viewer for musicians — an open-source alternative to OnSong. The Android app is complete, stable, and well-understood. Your job is a clean iOS native port, not a cross-platform wrapper.

## Source of Truth

- Android source: `app/src/main/java/org/freesong/`
- Full feature list: `README.md`
- Version history: `CHANGELOG.md`

---

## What FreeSong Does

A musician puts `.onsong` / `.chordpro` / `.txt` chord sheet files on their device. FreeSong reads them, displays chords above lyrics with correct alignment, and provides live tools during performance:

- Transpose up/down by semitone
- Auto-scroll (hands-free, adjustable speed)
- Key changes mid-song (automatic transposition)
- Nashville Number System toggle (chords → 1-7 notation)
- Setlists (create, reorder, navigate during performance)
- Flat/Sharp toggle, chord format toggle (inline ↔ above)
- Dark/Light theme
- Swipe + edge-tap navigation between songs
- Bluetooth page turner support (CubeTurner HID)
- GitHub sync (manual backup to a GitHub repo)
- Song editor with chord-move toolbar
- OnSong backup import (.backup/.zip with embedded SQLite)
- Fast startup via metadata cache

---

## Android Codebase Map

| File | Purpose | iOS equivalent |
|------|---------|----------------|
| `Song.java` | Data model: Song → SongSection → SongLine → ChordPosition + KeyChange | Swift struct, port as-is |
| `SongParser.java` (506 lines) | Parses OnSong + ChordPro + plain text into Song model | Pure logic, port to Swift |
| `Transposer.java` (152 lines) | Semitone transposition, handles sharps/flats/unicode accidentals | Pure logic, port to Swift |
| `NashvilleConverter.java` | Chord → Nashville number conversion | Pure logic, port to Swift |
| `ChordFormatConverter.java` | Inline ↔ above chord format conversion | Pure logic, port to Swift |
| `AccidentalConverter.java` | Sharp ↔ flat enharmonic conversion | Pure logic, port to Swift |
| `SongMetadataCache.java` | SQLite cache for title/artist (26x faster startup) | Use Core Data or SQLite directly |
| `SetListDbHelper.java` | SQLite setlist storage | Use Core Data |
| `SetlistBackupManager.java` | JSON export/import of setlists | Port logic, use Files app / iCloud |
| `BackupImporter.java` | OnSong .backup/.zip import (unzips, reads SQLite, extracts songs) | Port using ZipFoundation + SQLite |
| `GitHubApiClient.java` + `GitHubSyncManager.java` | GitHub REST API sync | Port using URLSession |
| `ThemeManager.java` | Dark/light theme preference | Use `@AppStorage` + SwiftUI `.preferredColorScheme` |
| `TLSSocketFactory.java` | TLS 1.2 shim for Android 4.4 | **Skip** — iOS has had TLS 1.2+ since iOS 9 |
| All `*Activity.java` files | UI screens | SwiftUI views |

---

## Business Logic to Port Exactly (Pure Swift)

These files contain no Android-specific APIs. Port them first — they are the heart of the app and can be tested in isolation:

1. **`SongParser`** — most critical. Two formats:
   - **OnSong**: title on line 1, artist on line 2, then sections with chords-above-lyrics
   - **ChordPro**: `{title:}`, `{artist:}`, `{key:}` directives; inline chords as `[G]lyrics`
   - Key change detection: `Key: D` (OnSong) or `{key: D}` (ChordPro) mid-song
   - Bass notation: `/G` standalone means "keep previous chord, move bass"

2. **`Transposer`** — semitone math. Handles: `C C# Db D D# Eb E F F# Gb G G# Ab A A# Bb B` + unicode `♯ ♭`. Slash chords (`Am/G`) transpose both parts. Key changes interact with global transposition.

3. **`NashvilleConverter`** — given a key, maps each chord to its scale degree (1–7) with quality preserved: `Am7` → `6m7` in key of C.

4. **`ChordFormatConverter`** — converts between `[G]Amazing [D]grace` and chords-on-separate-line format.

5. **`AccidentalConverter`** — `C# ↔ Db`, `F# ↔ Gb`, etc. with full enharmonic table.

---

## iOS-Specific Decisions

### File Access
Android reads from `/sdcard/FreeSong/`. On iOS use:
- **iCloud Drive** (`FileManager` + `NSUbiquitousItemDownloadingStatusCurrent`) as primary location
- **Local Documents** folder as fallback
- **Files app integration** via `UIDocumentPickerViewController` / `fileImporter` in SwiftUI
- No need to support `/sdcard/OnSong/` or `/sdcard/Download/` — omit those paths

### Song Viewer Layout
The core display challenge: chords must appear **above the correct syllable**, monospaced alignment.
- Use `AttributedString` or a custom `Canvas`-based renderer
- Android uses a custom `View` that draws chord+lyric pairs. In SwiftUI, a `Canvas` or `HStack` of `VStack(chord, lyric)` tuples works well.
- Font must be monospaced for chord alignment to work correctly.

### Auto-Scroll
Android uses `Handler.postDelayed` loop. iOS: use `Timer` or `Task { try await Task.sleep(...) }` with a `ScrollViewProxy`.

### Bluetooth Page Turner
Android intercepts `KeyEvent.KEYCODE_PAGE_UP/DOWN`. iOS: use `UIKeyCommand` (UIKit) or `.onKeyPress` (SwiftUI iOS 17+) to catch Bluetooth HID keyboard events.

### Setlist Storage
Replace Android SQLite `SetListDbHelper` with Core Data or plain JSON in the app's Documents directory. JSON is simpler and the backup format is already JSON.

### GitHub Sync
Port `GitHubApiClient` + `GitHubSyncManager` using `URLSession` async/await. The API calls are standard REST — no Android-specific quirks except the TLS shim (skip it on iOS).

### OnSong Backup Import
`BackupImporter.java` unzips a `.backup`/`.zip` file, finds `OnSong.sqlite3` inside, and queries it. On iOS:
- Use `ZipFoundation` (or `libz` directly) for unzipping
- Use `SQLite.swift` or raw `libsqlite3` for the embedded database query
- The SQLite schema query is in `BackupImporter.java` — port it directly

---

## Features to Skip (Android-specific, not relevant on iOS)

- `TLSSocketFactory.java` — TLS 1.2 workaround for Android 4.4. iOS doesn't need it.
- Storage permission dialogs — iOS handles this via the Files picker
- Android 4.4 ZIP compatibility workaround (ZIP v4.5 → v2.0 repack)
- `PATCH` method override header (`X-HTTP-Method-Override`) — this was an Android 4.4 bug. iOS `URLSession` handles `PATCH` natively.

---

## Recommended Build Order

1. **Data layer first** (no UI): `Song`, `SongParser`, `Transposer`, `NashvilleConverter`, `ChordFormatConverter`, `AccidentalConverter` — all pure Swift, all unit-testable
2. **Song viewer** — the core performance screen: chord+lyric rendering, transpose controls, auto-scroll, font size, dark/light theme
3. **Song library** — file browsing, search, metadata cache
4. **Setlists** — CRUD, reorder, navigation
5. **Editor** — text editing, chord-move toolbar, format/accidental toggle
6. **Import** — OnSong backup import
7. **GitHub sync** — last, it's additive

---

## Test Files

The Android app's core parser logic can be validated against the file formats documented in `README.md`. Minimal test cases to implement:

```
// OnSong format
"Amazing Grace\nTraditional\n\n[Verse]\n   G        C\nAmazing grace\n"

// ChordPro format  
"{title: Amazing Grace}\n{artist: Traditional}\n\n[Verse]\n[G]Amazing [C]grace\n"

// Key change
"{key: C}\n[C]line one\nKey: D\n[C]line two"  // second [C] should display as D

// Bass notation
"/G"  // standalone bass, not a chord
"Am/G"  // slash chord, both parts transpose
```

---

## Not Defined Here (Your Decisions)

- Minimum iOS version (suggest iOS 16 for full SwiftUI support)
- App icon and name (FreeSong, or a new name for the App Store)
- Whether to publish to App Store or keep as open-source sideload only
- iPad layout (the Android app runs on tablets — consider split-view for iPad)
- Whether to use SwiftUI throughout or UIKit for the song viewer canvas

---

## Repo

Codeberg (private): `https://codeberg.org/doobidoo/FreeSong`  
License: Apache 2.0
