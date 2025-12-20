# FreeSong

[![GitHub Release](https://img.shields.io/github/v/release/doobidoo/FreeSong)](https://github.com/doobidoo/FreeSong/releases)
[![Build Status](https://github.com/doobidoo/FreeSong/actions/workflows/release.yml/badge.svg)](https://github.com/doobidoo/FreeSong/actions)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Android](https://img.shields.io/badge/Android-4.4%2B-green.svg)](https://developer.android.com)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/doobidoo/FreeSong)
[![GitHub Discussions](https://img.shields.io/github/discussions/doobidoo/FreeSong)](https://github.com/doobidoo/FreeSong/discussions)

A free, open-source chord sheet and lyrics viewer for Android, designed as an alternative to OnSong. Built specifically for older Android devices (Android 4.4+) like the Samsung Galaxy Tab 2.

## Features

- **Song Library**: Browse and search your collection of chord sheets
- **OnSong/ChordPro Support**: Import and view songs in OnSong (.onsong) and ChordPro (.cho, .chordpro, .crd, .pro) formats, as well as plain text (.txt)
- **Chord Transposition**: Transpose songs up or down by semitones
- **Auto-Scroll**: Hands-free scrolling with adjustable speed
- **Font Size Control**: Increase or decrease text size for readability
- **Dark/Light Theme**: Toggle between dark and light modes for different lighting conditions
- **Setlist Management**: Create and organize setlists for performances
- **Setlist Backup**: Auto-backup to FreeSong folder, survives app reinstall
- **Song Editor**: Edit song files directly within the app
- **Chord Format Converter**: Toggle between inline chords `[G]lyrics` and chords-above-lyrics format while editing
- **Flat/Sharp Converter**: Toggle between sharp (#) and flat (b) chord notation with intelligent enharmonic conversion
- **Nashville Number System**: Toggle between standard chords and Nashville notation (1-7) in the song viewer
- **Chord Reference**: Help button in editor showing all supported chord notations
- **Chord Move Toolbar**: Floating toolbar to move chords character-by-character or word-by-word in the editor
- **Delete from Editor**: Quick delete button in editor, or auto-delete when saving empty songs
- **Swipe Navigation**: Navigate between songs with swipe gestures or edge taps (works in library and setlists)
- **Bluetooth Page Turner**: Support for CubeTurner and similar Bluetooth HID page turners with configurable modes
- **OnSong Backup Import**: Import songs directly from OnSong backup files (.backup, .zip)
- **GitHub Sync**: Backup songs and setlists to a GitHub repository for cloud backup and multi-device sync
- **Screen Always On**: Prevents screen from dimming during song viewing
- **Fast Startup**: Song metadata caching for ~26x faster app startup after first load

## Requirements

- Android 4.4 (KitKat) or higher
- Storage permission for accessing song files

## Installation

### From APK
1. Download the latest APK from the [Releases](https://github.com/doobidoo/FreeSong/releases) page
2. Enable "Unknown sources" in your device settings if needed
3. Install the APK

### Building from Source
1. Clone the repository:
   ```bash
   git clone https://github.com/doobidoo/FreeSong.git
   ```
2. Open in Android Studio or build with Gradle:
   ```bash
   ./gradlew assembleDebug
   ```
3. Install the APK from `app/build/outputs/apk/debug/`

## Usage

### Adding Songs
1. Place your song files in the `FreeSong` folder on your device's external storage
2. Supported locations: `/sdcard/FreeSong/`, `/sdcard/OnSong/`, `/sdcard/Download/`
3. Or use the **Import** button to import from OnSong backup files

### Importing from OnSong

FreeSong can import songs and setlists from OnSong backup files (`.backup`, `.zip`):
- **Songs**: Extracts all songs from the OnSong SQLite database (not just loose files)
- **Setlists**: Automatically imports your setlists and matches songs by title
- **Binary Detection**: PDF and image files are automatically skipped with a warning

**Important for Android 4.4 users:** OnSong creates backups using ZIP format version 4.5, which is not fully compatible with Android 4.4. If you get an error like "cannot read local header", you need to repack the backup on a PC:

```bash
# On Linux/Mac:
mkdir onsong_temp && cd onsong_temp
unzip /path/to/OnSong.backup "*.txt" "*.onsong" "*.chordpro" "*.cho" "OnSong.sqlite3"
zip -1 ../OnSong_compat.backup *

# Then transfer OnSong_compat.backup to your device
```

This creates a compatible ZIP (version 2.0) that works on older Android devices.

### Viewing Songs
- Tap a song in the library to open it
- Long-press for options: **Open**, **Add to Setlist**, or **Delete**
- **Swipe left/right** or tap screen edges to navigate between songs
- Use the control bar to transpose, adjust font size, or enable auto-scroll
- Double-tap to toggle auto-scroll
- Use the ▼/▲ button to show/hide the speed control bar
- Search finds songs by **title** or **artist name**

### Setlists
- Tap **Sets** to manage your setlists
- Create new setlists with the **+** button
- Add songs from the library using long-press > "Add to Setlist"
- Reorder songs by dragging
- When viewing songs from a setlist, swipe left/right or tap screen edges to navigate
- **Import setlists from OnSong**: Setlists are automatically imported from OnSong backups

### Editing Songs
- Tap **Edit** while viewing a song to open the editor
- Use the **Above/Inline** button to convert between chord formats:
  - **Inline**: `[G]Amazing [D]grace` (ChordPro style)
  - **Above**: Chords on separate line above lyrics (OnSong style)
- Use the **-> b / -> #** button to convert chord notation:
  - Converts between sharp and flat notation (C# ↔ Db, F# ↔ Gb, etc.)
  - Useful when you prefer reading flats over sharps
- Use the **Delete** button to remove the song (also removes from all setlists)
- Make changes and tap **Save**
- Saving an empty song offers to delete it automatically
- Press **Cancel** or back to discard changes

### Nashville Number System
Toggle Nashville notation in the song viewer with the "1-7" button:
- Converts standard chords to Nashville numbers based on the song's key
- In key of C: C→1, Dm→2m, Em→3m, F→4, G→5, Am→6m, B°→7°
- In key of G: G→1, Am→2m, Bm→3m, C→4, D→5, Em→6m, F#°→7°
- Chord qualities are preserved: Am7 → 6m7, G7 → 5⁷
- If no key is in the song metadata, a key selection dialog appears
- Tap "A-G" to switch back to standard chord notation

### Chord Reference
Tap the "?" button in the song editor to see all supported chord notations:
- Basic: C, Am, G7, Dm7, Cmaj7
- Extended: Cm7#5, CmMaj7, Cm(maj7), C7alt
- Unicode: C♯, D♭, C△7, C°, Cø
- And many more combinations

### Moving Chords (Editor)
When editing a song in **inline mode** (ChordPro format), a floating toolbar appears when your cursor is inside a chord:
- **◀◀**: Move chord one word to the left
- **◀**: Move chord one character to the left
- **▶**: Move chord one character to the right
- **▶▶**: Move chord one word to the right

This makes it easy to align chords precisely above the correct syllables on touch devices.

### Bluetooth Page Turner
FreeSong supports Bluetooth page turners like the CubeTurner:
- Tap **Pedal** button in song view to configure
- Three modes available:
  - **Scroll**: Page up/down (scroll one screen)
  - **Navigate**: Next/previous song (jump between songs)
  - **Smart**: Scrolls to end, then shows warning, then navigates on second press
- Works with touch-based page turners (CubeTurner sends touch/swipe events)

### Theme
- Tap the sun/moon button in the main screen to toggle dark/light mode

### GitHub Sync
Sync your songs and setlists to a GitHub repository for cloud backup and multi-device synchronization:

1. **Create a GitHub repository** for your songs (e.g., `my-songs-backup`)
2. **Generate a Personal Access Token**:
   - Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Generate a new token with `repo` scope
3. **Configure FreeSong**:
   - Long-press the sync button (↻) in the header bar
   - Enter your token and repository (format: `username/repo-name`)
   - Tap "Test Connection" to verify
   - Tap "Save"
4. **Sync your songs**:
   - Tap the sync button (↻) to start syncing
   - New songs are uploaded to GitHub
   - Songs only on GitHub are downloaded to your device
   - Conflicts create a `_conflict` file so you can choose which version to keep

**Note**: Sync is manual only - tap the button when you want to sync.

## Supported File Formats

### OnSong Format (.onsong)
```
Song Title
Artist Name

[Verse]
   G        C
Lyrics with chords above
   D        G
More lyrics here

[Chorus]
...
```

### ChordPro Format (.cho, .chordpro, .crd, .pro)
```
{title: Song Title}
{artist: Artist Name}

[Verse]
[G]Lyrics with [C]inline chords
[D]More lyrics [G]here

[Chorus]
...
```

### Plain Text (.txt)
Songs in OnSong or ChordPro format saved as .txt files are also supported.

## Encoding

FreeSong automatically handles character encoding:
- Files are read as UTF-8
- OnSong backup imports convert from Mac Roman to UTF-8
- Special characters (umlauts, accents, etc.) are preserved

## Disclaimer

**USE AT YOUR OWN RISK.** This software is provided "as is", without warranty of any kind, express or implied. The authors and contributors are not responsible for any damages or data loss that may result from using this application.

- **No Support**: There is no entitlement to support of any kind. While community discussions are welcome, responses are not guaranteed.
- **No Warranty**: This software is provided without any warranty. See the LICENSE file for details.
- **Data Responsibility**: You are responsible for backing up your own song files and data.

## License

This project is licensed under the Apache License, Version 2.0. See the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## Acknowledgments

- Inspired by [OnSong](https://onsongapp.com/) for iOS/Android
- Built for musicians who need a simple, reliable chord sheet viewer
