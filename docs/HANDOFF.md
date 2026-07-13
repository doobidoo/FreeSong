# FreeSong iOS — Session Handoff

**Stand:** 2026-06-29  
**Branch:** master

---

## Was wurde in dieser Session gemacht

### Song Viewer (SongViewer.swift)
- BottomBar (♭/♯, Reset, 1-7/A-G) mit `.safeAreaInset(edge: .bottom)` — sichtbar
- Nashville-Bug behoben: `transposedSong` ruft jetzt die vollständige Kette auf
- Editor öffnet als `fullScreenCover` auf iOS (statt Sheet)
- Inline-Toggle entfernt (Viewer zeigt immer above-line)

### ChordLineView.swift
- Chord-Positionierungsalgorithmus korrigiert: sortierte Chords mit Space-Cursor

### SongEditorView.swift
- Inline-Modus mit Chord-Shift-Popup (`◀◀ ◀ ChordName ▶ ▶▶`)
- Popup bleibt offen bis anderswo getippt wird
- `FlowLayout` für Zeilenumbruch bei langen Zeilen
- Freeze-Fix: `lineData` als O(n)-Vorberechnung, `VStack` statt `LazyVStack`
- Popup als `.overlay(alignment: .top)` am Button

### ChordFormatConverter.swift
- `shiftChordInLine` neu geschrieben: alle Tags rausstreifen → Position in reinem Text verschieben → Tags zurückeinbauen. Alter Bug (doppelte Positionskorrektur) behoben.

---

## Offene Punkte (Priorität hoch → niedrig)

### 1. Inline-Editor visuelle Qualität (HOCH)
User-Feedback: "grottenschlecht". Konkret zu prüfen:
- Chord-Token und Text-Token auf gleicher Baseline?
- `FlowLayout` bricht mitten im Wort? → Wortgrenzen einbauen
- Popup-Position bei Chords am rechten Rand (clippt aus dem Screen)?
- Vergleich mit Android-Screenshot machen: `ssh imac27 'adb shell screencap -p /sdcard/screen.png && adb pull /sdcard/screen.png /tmp/screen.png'`

### 2. Chord-Shift Richtung verifizieren (HOCH)
Fix wurde implementiert aber nicht live auf Gerät getestet. Bestätigen dass ◀ = links, ▶ = rechts.

### 3. Viewer → Editor → Viewer Sync (MITTEL)
Nach Save im Editor zeigt Viewer noch alten Song (initialisiert aus `let song: Song`).
Fix-Ansatz: `SongViewer` bekommt `@Binding<Song>` oder nutzt ein `@StateObject` Repository.

### 4. Format-Konvertierung Round-trip Test (MITTEL)
Inline → Above → Inline sollte verlustfrei sein. Mit echten Songs testen.

### 5. Auto-Save nach Chord-Shift (NIEDRIG)
Android macht Auto-Save. iOS braucht expliziten Save-Button — ok für jetzt, aber Feature-Parität fehlt.

---

## Wichtige Architektur-Fakten

```
Song.transposed()          // NUR Metadata, keine Chord-Transformation!
Transposer.transposedSong()      // ← das ist der echte Transposer
AccidentalConverter.convertToFlats()  // ← auf jedem einzelnen Chord-String
NashvilleConverter.convertSongToNashville()  // ← auf dem ganzen Song
```

**Simulator:** iPhone 17 Pro `id=C232C8F8-9F39-4DBF-97D3-D2B6C688C785`  
**Build:** `xcodebuild -scheme FreeSongApp -destination 'id=C232C8F8-...' build`  
**Android Ref:** `ssh imac27 'adb -s c16071a07e365af shell screencap ...'`
