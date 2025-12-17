# Changelog

All notable changes to FreeSong will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
