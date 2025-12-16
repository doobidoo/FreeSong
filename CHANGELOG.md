# Changelog

All notable changes to FreeSong will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
