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
- **Song Editor**: Edit song files directly within the app
- **Swipe Navigation**: Navigate between songs in a setlist with swipe gestures or edge taps
- **OnSong Backup Import**: Import songs directly from OnSong backup files (.backup, .zip)
- **Screen Always On**: Prevents screen from dimming during song viewing

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

### Viewing Songs
- Tap a song in the library to open it
- Long-press for song info and options to add to setlist
- Use the control bar to transpose, adjust font size, or enable auto-scroll
- Double-tap to toggle auto-scroll
- Use the ▼/▲ button to show/hide the speed control bar

### Setlists
- Tap **Sets** to manage your setlists
- Create new setlists with the **+** button
- Add songs from the library using long-press > "Add to Setlist"
- Reorder songs by dragging
- When viewing songs from a setlist, swipe left/right or tap screen edges to navigate

### Editing Songs
- Tap **Edit** while viewing a song to open the editor
- Make changes and tap **Save**
- Press **Cancel** or back to discard changes

### Theme
- Tap the sun/moon button in the main screen to toggle dark/light mode

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
