# SongViewer Chord-Layout Redesign — Design Spec

Date: 2026-07-12
Branch: feat/songviewer-chord-layout
Status: Approved, ready for implementation plan

## Problem

Chords in the iOS SongViewer do not sit above the correct syllable. They drift
left, and the error grows with the chord's column position.

Root cause: `Sources/FreeSongApp/Views/SongViewer/ChordLineView.swift:43`. The
chord row is rendered at `fontSize * 0.75` while the lyric row is rendered at
`fontSize`. Chords are positioned by padding the chord row with spaces up to the
chord's character index (`ChordLineView.swift:33-46`). Two monospaced rows at
different sizes have different character advance widths, so N spaces on the chord
row are narrower than N characters on the lyric row. Every chord shifts left by
`columnIndex × (1 − 0.75) × charWidth`.

Measured drift (SF Mono, fontSize 18): column 17 → 4.3 chars left, column 33 →
8.3 chars, column 50 → 12.5 chars.

Secondary defect: the chord row and lyric row are two independent `Text` views.
On narrow iPhone widths an 18pt monospaced lyric line wraps, and the chord row
wraps independently, so chords detach from their syllables entirely. There is no
horizontal-scroll fallback.

The Android reference (`app/src/main/java/org/freesong/SongViewActivity.java:445-492`)
uses a single monospaced `TextView` at one size for both rows, which is the only
condition under which space-padding aligns. The port broke that condition.

The render core (`SongRenderer`, `Transposer`, Nashville, accidentals,
key-changes) is correct and out of scope. The defect is purely in presentation.

## Goals

- Chords render exactly above their syllable at any font size, with no drift.
- Wrapping keeps each chord together with the syllable it sits above.
- Modern typography: proportional lyric font, chord smaller/bold/accent-coloured.
- Transposition persists per song when navigating a setlist.
- Header shows the transposed key, consistent with the toolbar.

## Non-Goals

- Auto-scroll behaviour is unchanged (still section-jump on a timer).
- Font-size cap unchanged.
- No changes to parsing, transposition math, storage, or sync.

## Approach: segment-based flow layout

Replace the two-independent-`Text` scheme with a segment model laid out
geometrically.

### 1. Pure segmentation function (in FreeSongCore, unit-testable)

Extract a pure function so alignment logic is testable without UI:

```
struct ChordSegment: Equatable {
    var chord: String?   // nil = lyric run with no chord above it
    var text: String     // lyric run for this segment (may be empty)
}

enum ChordSegmenter {
    static func segments(lyrics: String, chords: [ChordPosition]) -> [ChordSegment]
}
```

Rules:
- Sort chords by position.
- Positions are character indices (Swift `Character` count) into `lyrics`.
- A segment runs from one chord's position to the next chord's position (or to
  end of lyrics).
- If the first chord's position > 0, emit a leading segment `(chord: nil,
  text: <chars 0..<firstPos>)`.
- For each chord, emit `(chord: c.chord, text: <chars pos..<nextPos>)`.
- Clamp positions into `0...lyrics.count`; a chord positioned at or beyond the
  end of the lyrics gets `text: ""` (rendered with a non-breaking-space
  placeholder so it has something to sit above).
- Empty lyrics with chords (instrumental line): each chord becomes a segment with
  empty text.
- No chords: caller does not use the segmenter (plain lyric line path stays).

### 2. FlowLayout (in FreeSongApp, iOS 16 Layout protocol)

A wrapping horizontal layout that places subviews left-to-right and moves to the
next row when the next subview would exceed the proposed width. Left-aligned,
configurable vertical spacing between wrapped rows. Rows are sized to the tallest
subview in the row.

### 3. ChordLineView rewrite

- Key-change line: unchanged (existing pill rendering).
- No chords: unchanged (single proportional lyric `Text`).
- Has chords: `FlowLayout` of one view per segment. Each segment renders:
  ```
  VStack(alignment: .leading, spacing: 1) {
      Text(chord ?? " ")            // fontSize*0.8, .semibold, .accent; empty-string chord → reserve height
      Text(text.isEmpty ? "\u{00A0}" : text)  // fontSize, proportional
  }
  ```
- A segment whose chord is wider than its text stretches to the chord's width
  (natural VStack sizing), pushing following segments right — replaces the old
  `cursor` overlap hack.
- Fonts: lyric = `.system(size: fontSize)`; chord = `.system(size: fontSize*0.8,
  weight: .semibold)`, `.foregroundStyle(.accent)`. Monospace is no longer
  required for alignment.

### 4. Transpose persistence per song (SongViewer.swift)

The outer `SongViewer` currently forces a full rebuild on navigation via
`.id(reloadCount)`, resetting transpose to 0. Instead:
- Hold `@State private var transposeBySong: [String: Int]` keyed by a stable song
  identity (`song.sourcePath ?? song.title`).
- On navigate, save the current song's offset before switching; seed the new
  song's `SongViewerViewModel` with its stored offset (falling back to
  `song.transpose`).
- Keep the reload-via-`.id` mechanism for editor-save reloads, but seed the
  offset from the map on rebuild so navigation no longer loses it.

### 5. Header key fix (SongViewer.swift:289)

Show `viewModel.transposedSong.key` instead of the untransposed `song.key`. The
separate "Transposed +N" line stays as the offset indicator.

## Testing

Unit tests (FreeSongCore, `ChordSegmenterTests`):
- Chord at position 0.
- Leading lyric run before first chord.
- Chord mid-word (segment starts mid-word).
- Multiple chords, unsorted input.
- Chord at exactly lyrics.count and beyond → empty-text segment.
- Empty lyrics with one and multiple chords.
- Round-trip sanity: concatenating segment texts reproduces the original lyrics.
- Unicode/multibyte lyrics use Character indexing, not UTF-16.

FlowLayout: a sizeThatFits test (given fixed subview sizes and a width, wraps at
the expected row count).

Visual/behavioural (manual on Simulator, recorded in the plan's verification step):
- Amazing Grace sample: chords sit over the correct syllables at fontSize 14 and 28.
- Long line wraps and chords stay with their syllables.
- Transpose +2, navigate next/prev in a setlist, return: offset preserved.
- Header key reflects transpose.

## Files

New:
- `Sources/FreeSongCore/Parsing/ChordSegmenter.swift`
- `Sources/FreeSongApp/Components/FlowLayout.swift`
- `Tests/FreeSongCoreTests/ChordSegmenterTests.swift`

Modified:
- `Sources/FreeSongApp/Views/SongViewer/ChordLineView.swift` (rewrite chord path)
- `Sources/FreeSongApp/Views/SongViewer/SongViewer.swift` (transpose map, header key)

Unchanged: SongViewerViewModel auto-scroll, SongRenderer, Transposer, parsing,
storage, sync.
