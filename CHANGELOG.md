# Changelog

All notable changes to FreeSong will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.16.1] - 2025-12-21

### Fixed
- **Key Change Detection**: Key changes are now correctly detected even when they appear after song content (sections, chords, lyrics)
  - Previously, first key directive was always treated as base key
  - Now properly recognizes mid-song key changes in songs without explicit base key

## [1.16.0] - 2025-12-21

### Added
- **Key Change Support**: Automatic transposition when key changes mid-song
  - Supports `Key: D` (OnSong) and `{key: D}` (ChordPro) notation
  - Visual key change indicator: `── Key: D ──────────────`
  - Chords after key change are automatically transposed
  - Global transposition (+/-) also applies to key changes
  - Nashville mode works correctly with key changes

## [1.15.0] - 2025-12-20

### Added
- **Standalone Bass Notation**: Support for bass movement notation without explicit chord
  - Recognizes `/G`, `/Bb`, `/F#` etc. as valid chord symbols
  - Common notation meaning "keep previous chord, move bass to this note"
  - Enables proper parsing of songs with walking bass lines

## [1.14.0] - 2025-12-20

### Added
- **Editor Font Size**: Adjustable font size in the song editor
  - A- / A+ buttons in the editor header bar
  - Font size range: 10sp to 32sp
  - Setting is saved and restored between sessions

## [1.13.1] - 2025-12-20

### Fixed
- **Chord Position Bug**: Fixed inline chords appearing at wrong position in viewer
  - Chords like `[G]Amazing [D]grace` now correctly display D above "grace" instead of at the start
  - Position calculation in SongParser.parseLine() was computing position before adding preceding text

## [1.13.0] - 2025-12-20

### Added
- **Chord Move Toolbar**: Floating toolbar for moving inline chords in the editor
  - Appears automatically when cursor is inside a chord `[Am]`
  - Four buttons: Word left (◀◀), Char left (◀), Char right (▶), Word right (▶▶)
  - Moves chord along the line without affecting lyrics
  - Word-wise movement jumps to next/previous word boundary
  - Chords can be moved to the end of the line
  - Only available in inline chord mode (ChordPro format)
  - Shows hint toast when trying to use in "Above" format mode

### Technical
- New chord_move_toolbar.xml layout for floating toolbar
- PopupWindow-based toolbar that follows cursor position
- Chord detection using bracket parsing `[` and `]`
- Word boundary detection for smart movement
- Position calculation works on "base text" (without chord) for accurate movement

## [1.12.0] - 2025-12-20

### Added
- **Extended Chord Recognition**: Comprehensive support for all common chord notations
  - Minor-Major: CmM7, CmMaj7, Cm(maj7), Cm△7
  - Minor #5: Cm7#5, Am7#5, Em7#5
  - Alterations: C7#5, C7b9, C7#9, C7alt, C7#5#9
  - Half-diminished: Cø, Cø7, Cm7b5
  - Unicode symbols: C♯, D♭, C△7, C°, Cø
  - Complex combinations: Cmaj7#11, Am9sus4, F#m7b5/E
- **Nashville Number System**: Live toggle between standard chords and Nashville notation
  - Button "1-7" / "A-G" in song viewer
  - Automatic key detection from song metadata
  - Manual key selection dialog when key is unknown
  - Converts all chords on-the-fly: Am → 6m, G7 → 5⁷ (in key C)
- **Chord Reference**: Help button "?" in the song editor
  - Shows all supported chord notations
  - Includes minor combinations (m7#5, mMaj7)
  - Lists alterations, extensions, and slash chords

### Technical
- New `NashvilleConverter.java` class for Nashville notation conversion
- Updated chord regex in ChordFormatConverter and SongParser
- Added Unicode accidental support (♯, ♭) in Transposer

## [1.11.0] - 2025-12-18

### Added
- **GitHub Sync**: Sync songs and setlists to a GitHub repository for backup and multi-device sync
  - Manual sync via button in header bar (↻)
  - Long-press sync button to configure GitHub token and repository
  - Batch upload: uploads up to 25 songs per commit for efficiency
  - Bidirectional sync: downloads new songs from repo, uploads local songs
  - Conflict handling: keeps both versions when files differ
- **GitHub Settings Activity**: Configure Personal Access Token and repository (owner/repo format)
- **TLS 1.2 Support**: Enables TLS 1.2 on Android 4.4 devices for secure GitHub API connections

### Technical
- Uses GitHub REST API with Git Trees API for efficient batch uploads
- Blob-based upload approach for reliable large file handling
- PATCH method workaround with X-HTTP-Method-Override header for Android 4.4 compatibility
- Detailed error reporting in sync result dialog

## [1.10.0] - 2025-12-17

### Added
- **Song Metadata Cache**: SQLite cache stores title/artist metadata for ~26x faster app startup
- **Header-Only Parsing**: Only reads first 30 lines of song files when extracting metadata (~4x faster initial load)
- **SongPicker AsyncTask**: Song picker now loads songs in background thread with progress dialog

### Fixed
- **Setlist Import ANR**: Import now runs in background thread, preventing ANR/freeze
- **SongPicker ANR**: Song loading in picker now runs in background thread

### Performance
- First app startup: ~8s → ~2s (4x faster)
- Subsequent startups: ~8s → ~0.3s (26x faster)
- Song picker opening: ANR risk → ~0.3s

## [1.9.0] - 2025-12-17

### Added
- **Bluetooth Page Turner**: Support for CubeTurner and similar Bluetooth HID page turners
  - Three modes: "Scroll" (page up/down), "Navigate" (next/prev song), "Smart" (scroll then navigate)
  - Pedal button in song view to configure mode
  - Works with touch-based page turners (CubeTurner sends touch events, not key events)
- **Smart Page Turner Mode**: Scrolls to end of song, shows warning, then navigates to next song on second press

## [1.8.0] - 2025-12-17

### Added
- **Setlist Auto-Backup**: Setlists are automatically saved to `FreeSong/setlists-backup.json` after every change
- **Setlist Export/Import**: Manual export and import buttons in Setlists screen
- **Auto-Restore**: When app is reinstalled and DB is empty, offers to restore from backup
- **Backup survives reinstall**: Setlist backup file is stored in FreeSong folder, not app data

### Fixed
- Setlists no longer lost when app is uninstalled and reinstalled

## [1.7.0] - 2025-12-17

### Added
- **Delete from Editor**: Delete button in song editor for quick song removal
- **Auto-Delete Empty Songs**: When saving an empty song, option to delete it automatically
- **Flat/Sharp Toggle**: Convert all chords between sharp (#) and flat (b) notation
  - Intelligent enharmonic conversion (C# ↔ Db, F# ↔ Gb, etc.)
  - Works with both inline and chords-above formats
  - Auto-detects current notation style
- **Binary File Detection**: Import now skips PDF and image files with warning
  - Detects PDF, PNG, JPEG, GIF, BMP formats
  - Shows count of skipped files and warnings

### Fixed
- **Setlist Position Persistence**: Theme toggle and editing no longer resets position in setlist
  - Scroll position, font size, and transposition are preserved
- **Song Deletion Cleanup**: Deleted songs are automatically removed from all setlists
- **Song List Refresh**: Main library updates immediately after deleting a song

## [1.6.0] - 2025-12-16

### Added
- **Swipe Navigation in Library**: Swipe left/right to navigate between songs when viewing from the main library (not just setlists)
- **Chord Format Toggle in Editor**: New "Above"/"Inline" button converts between chord formats:
  - Inline chords: `[G]Amazing [D]grace` (ChordPro style)
  - Chords above lyrics: Chords on separate line above lyrics (OnSong style)
  - Auto-detects current format when opening a song

### Fixed
- **Theme Toggle Performance**: Switching dark/light mode no longer resets song loading - library state is preserved
- **Chord Alignment**: Fixed chord positioning when long chords (e.g., "Am7/B") overlap with subsequent chord positions

## [1.5.0] - 2025-12-16

### Added
- **Loading Progress**: Shows progress while loading songs (e.g., "Loading songs... 500/996")

### Fixed
- **Performance**: Songs are now cached - no reload when returning from setlists
- **Delete**: Deleting a song no longer triggers full library reload

## [1.4.0] - 2025-12-16

### Fixed
- **Performance**: Song loading now runs in background thread (fixes ANR/freeze with large libraries)

## [1.3.0] - 2025-12-16

### Added
- **Delete Songs**: Long-press a song to delete it from the library
- **Setlist Import**: Import setlists from OnSong backup (automatically matches songs by title)

## [1.2.0] - 2025-12-16

### Added
- **Artist Search**: Search now finds songs by artist name, not just title
- **Artist Display**: Song list shows "Title - Artist" format when artist is available
- **ZIP Compatibility Docs**: Added documentation for OnSong backup conversion on Android 4.4

### Fixed
- **Import Screen**: Screen now stays on during long imports (prevents timeout)

## [1.1.0] - 2025-12-16

### Added
- **OnSong Database Import**: Extract songs directly from OnSong SQLite database in backup files
  - Imports all songs stored in the database (not just loose files)
  - Creates properly named files (Title-Key.onsong) instead of UUIDs
  - Dramatically increases import coverage (996 songs vs ~45 in test backup)

### Fixed
- **File Browser**: Now shows all supported file formats (.crd, .pro, .txt were missing)

## [1.0.0] - 2025-12-15

### Added
- **Song Library**: Browse and search songs from FreeSong, OnSong, and Download folders
- **Song Viewer**: Display lyrics with chord highlighting and section labels
- **Transposition**: Transpose songs up/down by semitones with chord detection
- **Auto-scroll**: Adjustable speed auto-scroll for hands-free performance
- **Font sizing**: Increase/decrease font size for readability
- **Song Editor**: Edit song content with save functionality
- **Setlist Management**: Create, rename, and delete setlists
- **Setlist Playback**: Navigate through setlist songs with swipe gestures
- **Import**: Import OnSong backups (.backup, .zip) and individual song files
- **Dark/Light Theme**: Toggle between dark and light mode across all screens
- **Speed Bar Toggle**: Show/hide the scroll speed control bar
- **About Dialog**: View app version, author, and license information
- **File Format Support**: OnSong (.onsong), ChordPro (.chordpro, .cho, .crd, .pro), and plain text (.txt)
- **Encoding Detection**: Automatic detection of file encoding (UTF-8, Latin-1, etc.)

### Technical
- Minimum SDK: Android 4.4 (API 19)
- Target SDK: Android 4.4 (API 19)
- No external dependencies - pure Android SDK
