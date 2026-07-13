# SongViewer Chord-Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make chords sit exactly above their syllable at any font size and keep them attached to that syllable when lines wrap, via a segment-based flow layout; also persist transpose per song and show the transposed key in the header.

**Architecture:** Extract the alignment logic into two pure, unit-testable functions in `FreeSongCore` — `ChordSegmenter` (splits a lyric line into chord+text segments) and `FlowLayoutSolver` (greedy row-packing math). A thin SwiftUI `FlowLayout` (iOS 16 `Layout`) in `FreeSongApp` calls the solver; the rewritten `ChordLineView` renders one `VStack{chord,text}` per segment inside it. `SongViewer` gains a per-song transpose map and a corrected header key.

**Tech Stack:** Swift 5.9+ / SwiftPM, SwiftUI (iOS 16 `Layout` protocol), XCTest.

## Global Constraints

- Deployment target: iOS 16.0 (SwiftUI `Layout` protocol requires it) — copied from `project.yml`/`Package.swift`.
- `FreeSongCore` is pure Swift, no platform UI dependencies — new Core files use only `Foundation`.
- Tests use XCTest: `final class XxxTests: XCTestCase`, `@testable import FreeSongCore`, `XCTAssertEqual`.
- Run Core tests with: `swift test --filter FreeSongCoreTests`.
- Positions in `ChordPosition.position` are `Character` indices into the lyric string (not UTF-16).
- Commit after every task. End commit messages with:
  `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- Branch: `feat/songviewer-chord-layout` (already checked out).

**Note vs spec:** the spec put `FlowLayout` in `FreeSongApp` and mentioned a "sizeThatFits test". `FreeSongApp` has no test target, so the pure geometry is extracted to `FreeSongCore/Layout/FlowLayoutSolver.swift` (unit-tested there) and the SwiftUI `FlowLayout` wrapper stays a thin, build-verified shell in `FreeSongApp`. `ChordSegmenter` stays in `FreeSongCore/Parsing` per spec.

---

## File Structure

New:
- `Sources/FreeSongCore/Parsing/ChordSegmenter.swift` — `ChordSegment`, `ChordSegmenter.segments(lyrics:chords:)`
- `Sources/FreeSongCore/Layout/FlowLayoutSolver.swift` — `FlowLayoutSolver.layout(...)`
- `Sources/FreeSongApp/Components/FlowLayout.swift` — SwiftUI `Layout` wrapper
- `Tests/FreeSongCoreTests/ChordSegmenterTests.swift`
- `Tests/FreeSongCoreTests/FlowLayoutSolverTests.swift`

Modified:
- `Sources/FreeSongApp/Views/SongViewer/ChordLineView.swift` — rewrite the has-chords path
- `Sources/FreeSongApp/Views/SongViewer/SongViewer.swift` — per-song transpose map, header key
- `Sources/FreeSongApp/ViewModels/SongViewerViewModel.swift` — optional `initialTranspose` seed

---

## Task 1: ChordSegmenter (pure segmentation in FreeSongCore)

**Files:**
- Create: `Sources/FreeSongCore/Parsing/ChordSegmenter.swift`
- Test: `Tests/FreeSongCoreTests/ChordSegmenterTests.swift`

**Interfaces:**
- Consumes: `ChordPosition` (`chord: String`, `position: Int`) from `FreeSongCore/Models/ChordPosition.swift`.
- Produces:
  - `struct ChordSegment: Equatable { var chord: String?; var text: String }` (public init)
  - `enum ChordSegmenter { static func segments(lyrics: String, chords: [ChordPosition]) -> [ChordSegment] }`

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/FreeSongCoreTests/ChordSegmenterTests.swift
import XCTest
@testable import FreeSongCore

final class ChordSegmenterTests: XCTestCase {

    func testChordAtStart() {
        let segs = ChordSegmenter.segments(
            lyrics: "Amazing", chords: [ChordPosition(chord: "G", position: 0)])
        XCTAssertEqual(segs, [ChordSegment(chord: "G", text: "Amazing")])
    }

    func testLeadingLyricRunBeforeFirstChord() {
        let segs = ChordSegmenter.segments(
            lyrics: "Amazing grace", chords: [ChordPosition(chord: "C", position: 8)])
        XCTAssertEqual(segs, [
            ChordSegment(chord: nil, text: "Amazing "),
            ChordSegment(chord: "C", text: "grace"),
        ])
    }

    func testMultipleChordsUnsortedInput() {
        let segs = ChordSegmenter.segments(
            lyrics: "Amazing grace how",
            chords: [ChordPosition(chord: "D", position: 14),
                     ChordPosition(chord: "G", position: 0)])
        XCTAssertEqual(segs, [
            ChordSegment(chord: "G", text: "Amazing grace "),
            ChordSegment(chord: "D", text: "how"),
        ])
    }

    func testChordMidWord() {
        let segs = ChordSegmenter.segments(
            lyrics: "Amazing",
            chords: [ChordPosition(chord: "G", position: 0),
                     ChordPosition(chord: "C", position: 4)])
        XCTAssertEqual(segs, [
            ChordSegment(chord: "G", text: "Amaz"),
            ChordSegment(chord: "C", text: "ing"),
        ])
    }

    func testChordAtExactEndGetsEmptyText() {
        let segs = ChordSegmenter.segments(
            lyrics: "Amazing", chords: [ChordPosition(chord: "G", position: 7)])
        XCTAssertEqual(segs, [
            ChordSegment(chord: nil, text: "Amazing"),
            ChordSegment(chord: "G", text: ""),
        ])
    }

    func testChordBeyondEndClampsToEmptyText() {
        let segs = ChordSegmenter.segments(
            lyrics: "Am", chords: [ChordPosition(chord: "G", position: 10)])
        XCTAssertEqual(segs, [
            ChordSegment(chord: nil, text: "Am"),
            ChordSegment(chord: "G", text: ""),
        ])
    }

    func testEmptyLyricsWithMultipleChords() {
        let segs = ChordSegmenter.segments(
            lyrics: "",
            chords: [ChordPosition(chord: "G", position: 0),
                     ChordPosition(chord: "C", position: 4)])
        XCTAssertEqual(segs, [
            ChordSegment(chord: "G", text: ""),
            ChordSegment(chord: "C", text: ""),
        ])
    }

    func testRoundTripConcatenationPreservesLyrics() {
        let lyrics = "When we've been there ten thousand years"
        let chords = [ChordPosition(chord: "G", position: 0),
                      ChordPosition(chord: "C", position: 20),
                      ChordPosition(chord: "D", position: 30)]
        let joined = ChordSegmenter.segments(lyrics: lyrics, chords: chords)
            .map(\.text).joined()
        XCTAssertEqual(joined, lyrics)
    }

    func testUnicodeUsesCharacterIndexing() {
        // "Café " is 5 Characters (é is one grapheme); position 5 is 's'.
        let segs = ChordSegmenter.segments(
            lyrics: "Café song",
            chords: [ChordPosition(chord: "G", position: 0),
                     ChordPosition(chord: "C", position: 5)])
        XCTAssertEqual(segs, [
            ChordSegment(chord: "G", text: "Café "),
            ChordSegment(chord: "C", text: "song"),
        ])
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ChordSegmenterTests`
Expected: FAIL — `cannot find 'ChordSegmenter' in scope` / `ChordSegment`.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/FreeSongCore/Parsing/ChordSegmenter.swift
import Foundation

/// A run of lyric text with an optional chord anchored above its first character.
public struct ChordSegment: Equatable, Sendable {
    public var chord: String?
    public var text: String

    public init(chord: String?, text: String) {
        self.chord = chord
        self.text = text
    }
}

/// Splits a lyric line into segments for geometric chord-over-syllable layout.
///
/// Each chord starts a new segment that runs until the next chord (or end of
/// line). A leading run before the first chord becomes a chord-less segment.
/// Positions are clamped into `0...lyrics.count`; a chord at or past the end
/// gets an empty-text segment. Concatenating all segment texts reproduces the
/// original lyrics.
public enum ChordSegmenter {
    public static func segments(lyrics: String, chords: [ChordPosition]) -> [ChordSegment] {
        let chars = Array(lyrics)
        let n = chars.count
        let sorted = chords.sorted { $0.position < $1.position }

        guard let first = sorted.first else {
            return lyrics.isEmpty ? [] : [ChordSegment(chord: nil, text: lyrics)]
        }

        var result: [ChordSegment] = []
        let firstPos = min(max(first.position, 0), n)
        if firstPos > 0 {
            result.append(ChordSegment(chord: nil, text: String(chars[0..<firstPos])))
        }

        for (i, cp) in sorted.enumerated() {
            let start = min(max(cp.position, 0), n)
            let end = (i + 1 < sorted.count)
                ? min(max(sorted[i + 1].position, start), n)
                : n
            let text = start < end ? String(chars[start..<end]) : ""
            result.append(ChordSegment(chord: cp.chord, text: text))
        }
        return result
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ChordSegmenterTests`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/FreeSongCore/Parsing/ChordSegmenter.swift Tests/FreeSongCoreTests/ChordSegmenterTests.swift
git commit -m "Add ChordSegmenter: split lyric line into chord+text segments

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Task 2: FlowLayoutSolver (pure row-packing math in FreeSongCore)

**Files:**
- Create: `Sources/FreeSongCore/Layout/FlowLayoutSolver.swift`
- Test: `Tests/FreeSongCoreTests/FlowLayoutSolverTests.swift`

**Interfaces:**
- Consumes: nothing (Foundation only).
- Produces:
  - `struct FlowLayoutSolver.Size: Equatable { var width: Double; var height: Double }`
  - `struct FlowLayoutSolver.Result: Equatable { var rows: [[Int]]; var total: Size }`
  - `static func layout(itemSizes: [Size], spacing: Double, lineSpacing: Double, maxWidth: Double) -> Result`
  - Behaviour: greedy left-to-right packing; an item that doesn't fit the current
    (non-empty) row starts a new row; `total.width` = widest row, `total.height` =
    sum of row heights + `lineSpacing × (rowCount − 1)`.

- [ ] **Step 1: Write the failing tests**

```swift
// Tests/FreeSongCoreTests/FlowLayoutSolverTests.swift
import XCTest
@testable import FreeSongCore

final class FlowLayoutSolverTests: XCTestCase {
    typealias Size = FlowLayoutSolver.Size

    func testSingleRowWhenItemsFit() {
        let r = FlowLayoutSolver.layout(
            itemSizes: [Size(width: 20, height: 10), Size(width: 30, height: 12)],
            spacing: 5, lineSpacing: 4, maxWidth: 100)
        XCTAssertEqual(r.rows, [[0, 1]])
        XCTAssertEqual(r.total, Size(width: 55, height: 12))   // 20+5+30 ; tallest 12
    }

    func testWrapsToSecondRow() {
        let r = FlowLayoutSolver.layout(
            itemSizes: [Size(width: 60, height: 10), Size(width: 60, height: 10)],
            spacing: 5, lineSpacing: 4, maxWidth: 100)
        XCTAssertEqual(r.rows, [[0], [1]])
        XCTAssertEqual(r.total, Size(width: 60, height: 24)) // 10+4+10
    }

    func testOversizeItemGetsItsOwnRow() {
        let r = FlowLayoutSolver.layout(
            itemSizes: [Size(width: 150, height: 10), Size(width: 20, height: 10)],
            spacing: 5, lineSpacing: 4, maxWidth: 100)
        XCTAssertEqual(r.rows, [[0], [1]])
    }

    func testEmptyInput() {
        let r = FlowLayoutSolver.layout(
            itemSizes: [], spacing: 5, lineSpacing: 4, maxWidth: 100)
        XCTAssertEqual(r.rows, [])
        XCTAssertEqual(r.total, Size(width: 0, height: 0))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter FlowLayoutSolverTests`
Expected: FAIL — `cannot find 'FlowLayoutSolver' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// Sources/FreeSongCore/Layout/FlowLayoutSolver.swift
import Foundation

/// Pure greedy row-packing used by the SwiftUI `FlowLayout`. Kept UI-free so the
/// wrapping geometry is unit-testable without a view host.
public enum FlowLayoutSolver {
    public struct Size: Equatable, Sendable {
        public var width: Double
        public var height: Double
        public init(width: Double, height: Double) {
            self.width = width
            self.height = height
        }
    }

    public struct Result: Equatable, Sendable {
        public var rows: [[Int]]
        public var total: Size
        public init(rows: [[Int]], total: Size) {
            self.rows = rows
            self.total = total
        }
    }

    public static func layout(itemSizes: [Size], spacing: Double, lineSpacing: Double, maxWidth: Double) -> Result {
        var rows: [[Int]] = []
        var current: [Int] = []
        var currentWidth = 0.0

        for (i, size) in itemSizes.enumerated() {
            if current.isEmpty {
                current = [i]
                currentWidth = size.width
            } else if currentWidth + spacing + size.width <= maxWidth {
                current.append(i)
                currentWidth += spacing + size.width
            } else {
                rows.append(current)
                current = [i]
                currentWidth = size.width
            }
        }
        if !current.isEmpty { rows.append(current) }

        let totalWidth = rows.map { row in
            row.reduce(0.0) { $0 + itemSizes[$1].width }
                + spacing * Double(max(row.count - 1, 0))
        }.max() ?? 0
        let rowHeights = rows.map { row in row.map { itemSizes[$0].height }.max() ?? 0 }
        let totalHeight = rowHeights.reduce(0, +)
            + lineSpacing * Double(max(rows.count - 1, 0))

        return Result(rows: rows, total: Size(width: totalWidth, height: totalHeight))
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter FlowLayoutSolverTests`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add Sources/FreeSongCore/Layout/FlowLayoutSolver.swift Tests/FreeSongCoreTests/FlowLayoutSolverTests.swift
git commit -m "Add FlowLayoutSolver: pure greedy row-packing for flow layout

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Task 3: FlowLayout SwiftUI wrapper (FreeSongApp)

**Files:**
- Create: `Sources/FreeSongApp/Components/FlowLayout.swift`

**Interfaces:**
- Consumes: `FlowLayoutSolver` from Task 2.
- Produces: `struct FlowLayout: Layout` with `init(spacing:lineSpacing:)` (defaults `spacing: 0`, `lineSpacing: 6`), usable as `FlowLayout { ...subviews... }`.

No unit test (FreeSongApp has no test target); verified by compile gate here and visually in Task 6.

- [ ] **Step 1: Write the implementation**

```swift
// Sources/FreeSongApp/Components/FlowLayout.swift
import SwiftUI
import FreeSongCore

/// Wrapping horizontal layout: places subviews left-to-right and moves to the
/// next row when the next subview would overflow the proposed width. Row-packing
/// math lives in `FlowLayoutSolver` (FreeSongCore) so it can be unit-tested.
struct FlowLayout: Layout {
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let result = solve(sizes: sizes, maxWidth: proposal.width ?? .infinity)
        return CGSize(width: result.total.width, height: result.total.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let result = solve(sizes: sizes, maxWidth: bounds.width)
        var y = bounds.minY
        for row in result.rows {
            var x = bounds.minX
            let rowHeight = row.map { sizes[$0].height }.max() ?? 0
            for idx in row {
                subviews[idx].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(sizes[idx]))
                x += sizes[idx].width + spacing
            }
            y += rowHeight + lineSpacing
        }
    }

    private func solve(sizes: [CGSize], maxWidth: CGFloat) -> FlowLayoutSolver.Result {
        let width = (maxWidth.isFinite ? maxWidth : 100_000)
        return FlowLayoutSolver.layout(
            itemSizes: sizes.map { .init(width: $0.width, height: $0.height) },
            spacing: Double(spacing),
            lineSpacing: Double(lineSpacing),
            maxWidth: Double(width))
    }
}
```

- [ ] **Step 2: Compile gate**

Run: `swift build --target FreeSongApp 2>&1 | tail -20`
Expected: build succeeds (no errors). If SwiftPM cannot build the SwiftUI target on this macOS host, fall back to:
`xcodegen generate && xcodebuild -scheme FreeSongiOS -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -20`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add Sources/FreeSongApp/Components/FlowLayout.swift
git commit -m "Add FlowLayout: wrapping SwiftUI Layout backed by FlowLayoutSolver

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Task 4: Rewrite ChordLineView to use segments + FlowLayout

**Files:**
- Modify: `Sources/FreeSongApp/Views/SongViewer/ChordLineView.swift`

**Interfaces:**
- Consumes: `ChordSegmenter` (Task 1), `FlowLayout` (Task 3).
- Produces: unchanged `ChordLineView(line:fontSize:)` API; only the has-chords rendering path changes.

Replace the whole file with the version below. The key-change branch and the
no-chords branch are unchanged; the `chordLine`/`lyricsLine` space-padding pair is
removed and replaced by `chordFlow`.

- [ ] **Step 1: Write the implementation**

```swift
// Sources/FreeSongApp/Views/SongViewer/ChordLineView.swift
import SwiftUI
import FreeSongCore

/// Renders a single line of lyrics with chords positioned above the text.
/// Chords are aligned geometrically (one segment per chord) so alignment holds
/// at any font size and survives line wrapping.
struct ChordLineView: View {
    let line: SongLine
    var fontSize: Double = 18

    var body: some View {
        if line.isKeyChange, let keyChange = line.keyChange {
            HStack {
                Image(systemName: "arrow.triangle.swap")
                    .foregroundStyle(.accent)
                Text("Key Change: \(keyChange.newKey)")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.accent)
            }
            .padding(.vertical, 4)
        } else if !line.chords.isEmpty {
            chordFlow
                .padding(.vertical, 2)
        } else {
            Text(line.lyrics)
                .font(.system(size: fontSize))
                .lineLimit(nil)
                .padding(.vertical, 2)
        }
    }

    private var segments: [ChordSegment] {
        ChordSegmenter.segments(lyrics: line.lyrics, chords: line.chords)
    }

    /// One column per segment: chord (smaller, bold, accent) stacked over its
    /// lyric run. Horizontal spacing is 0 because segment texts already carry the
    /// inter-word spaces; the flow only decides where rows wrap.
    private var chordFlow: some View {
        FlowLayout(spacing: 0, lineSpacing: 6) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                VStack(alignment: .leading, spacing: 1) {
                    Text(seg.chord ?? " ")
                        .font(.system(size: fontSize * 0.8, weight: .semibold))
                        .foregroundStyle(.accent)
                        .fixedSize()
                    Text(seg.text.isEmpty ? "\u{00A0}" : seg.text)
                        .font(.system(size: fontSize))
                        .fixedSize()
                }
            }
        }
    }
}

#Preview("ChordLineView") {
    VStack(alignment: .leading, spacing: 12) {
        ChordLineView(line: SongLine(
            lyrics: "Amazing grace how sweet the sound",
            chords: [ChordPosition(chord: "G", position: 0),
                     ChordPosition(chord: "C", position: 8),
                     ChordPosition(chord: "D", position: 24)]))
        ChordLineView(line: SongLine(lyrics: "That saved a wretch like me"))
    }
    .padding()
}
```

- [ ] **Step 2: Compile gate**

Run: `swift build --target FreeSongApp 2>&1 | tail -20`
Expected: build succeeds. (Fallback to the `xcodebuild` command from Task 3 Step 2 if needed.)

- [ ] **Step 3: Commit**

```bash
git add Sources/FreeSongApp/Views/SongViewer/ChordLineView.swift
git commit -m "Rewrite ChordLineView: geometric chord-over-syllable via FlowLayout

Fixes chord left-drift (was caused by the 0.75x chord-row font under a
space-padding scheme) and keeps chords with their syllable on wrap.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Task 5: Per-song transpose persistence + header key fix

**Files:**
- Modify: `Sources/FreeSongApp/ViewModels/SongViewerViewModel.swift` (add `initialTranspose` seed)
- Modify: `Sources/FreeSongApp/Views/SongViewer/SongViewer.swift` (transpose map, callback, header key)

**Interfaces:**
- `SongViewerViewModel.init(song:initialTranspose:)` — `initialTranspose: Int?`
  defaults to `nil`; when `nil`, falls back to `song.transpose` (current behaviour).
- `SongViewerContent` gains `initialTranspose: Int` and `onTransposeChanged: (Int) -> Void`.
- `SongViewer` holds `transposeBySong: [String: Int]`, keyed by `song.sourcePath ?? song.title`.

- [ ] **Step 1: Add the `initialTranspose` seed to the view model**

In `SongViewerViewModel.swift`, change the initializer signature and the
`transposeOffset` seed. Replace:

```swift
    init(song: Song) {
        self.originalSong = song
        self.transposeOffset = song.transpose
```

with:

```swift
    init(song: Song, initialTranspose: Int? = nil) {
        self.originalSong = song
        self.transposeOffset = initialTranspose ?? song.transpose
```

(Leave the rest of `init` unchanged.)

- [ ] **Step 2: Thread the offset through `SongViewerContent`**

In `SongViewer.swift`, in `private struct SongViewerContent`, add two stored
properties and update the initializer. Replace the property block:

```swift
    let song: Song
    var position: (index: Int, total: Int)?
    var onNavigate: ((Int) -> Void)?
    let onSaved: (Song) -> Void
    @StateObject private var viewModel: SongViewerViewModel
```

with:

```swift
    let song: Song
    var position: (index: Int, total: Int)?
    var onNavigate: ((Int) -> Void)?
    let onSaved: (Song) -> Void
    let onTransposeChanged: (Int) -> Void
    @StateObject private var viewModel: SongViewerViewModel
```

Replace the initializer:

```swift
    init(
        song: Song,
        position: (index: Int, total: Int)? = nil,
        onNavigate: ((Int) -> Void)? = nil,
        onSaved: @escaping (Song) -> Void
    ) {
        self.song = song
        self.position = position
        self.onNavigate = onNavigate
        self.onSaved = onSaved
        _viewModel = StateObject(wrappedValue: SongViewerViewModel(song: song))
    }
```

with:

```swift
    init(
        song: Song,
        position: (index: Int, total: Int)? = nil,
        onNavigate: ((Int) -> Void)? = nil,
        initialTranspose: Int = 0,
        onSaved: @escaping (Song) -> Void,
        onTransposeChanged: @escaping (Int) -> Void
    ) {
        self.song = song
        self.position = position
        self.onNavigate = onNavigate
        self.onSaved = onSaved
        self.onTransposeChanged = onTransposeChanged
        _viewModel = StateObject(
            wrappedValue: SongViewerViewModel(song: song, initialTranspose: initialTranspose))
    }
```

- [ ] **Step 3: Report offset changes and fix the header key**

In `SongViewerContent.body`, attach an `onChange` for the offset. Add this
modifier right after the existing `.onChange(of: viewModel.autoScrollTargetLabel)`
block inside the `ScrollViewReader`:

```swift
            .onChange(of: viewModel.transposeOffset) { newValue in
                onTransposeChanged(newValue)
            }
```

Then fix the header key. In `private var header`, replace:

```swift
            if let key = song.key {
                Text("Key: \(key)")
```

with:

```swift
            if let key = viewModel.transposedSong.key, !key.isEmpty {
                Text("Key: \(key)")
```

- [ ] **Step 4: Wire the map in the outer `SongViewer`**

In `struct SongViewer`, add the state and a key helper. After
`@State private var index: Int` add:

```swift
    @State private var transposeBySong: [String: Int] = [:]

    private func key(for song: Song) -> String { song.sourcePath ?? song.title }
```

Replace the `body`'s `SongViewerContent(...)` call:

```swift
        SongViewerContent(
            song: activeSong,
            position: hasNavigation ? (index + 1, songs.count) : nil,
            onNavigate: hasNavigation ? navigate : nil,
            onSaved: { updated in
                currentSong = updated
                reloadCount += 1
            }
        )
```

with:

```swift
        SongViewerContent(
            song: activeSong,
            position: hasNavigation ? (index + 1, songs.count) : nil,
            onNavigate: hasNavigation ? navigate : nil,
            initialTranspose: transposeBySong[key(for: activeSong)] ?? activeSong.transpose,
            onSaved: { updated in
                currentSong = updated
                reloadCount += 1
            },
            onTransposeChanged: { offset in
                transposeBySong[key(for: activeSong)] = offset
            }
        )
```

(The `.id(reloadCount)` on the same view stays; on navigate the content rebuilds
and reseeds `initialTranspose` from the map, so the offset survives.)

- [ ] **Step 5: Compile gate**

Run: `swift build --target FreeSongApp 2>&1 | tail -20`
Expected: build succeeds. (Fallback to `xcodebuild` per Task 3 Step 2.)

- [ ] **Step 6: Commit**

```bash
git add Sources/FreeSongApp/ViewModels/SongViewerViewModel.swift Sources/FreeSongApp/Views/SongViewer/SongViewer.swift
git commit -m "Persist transpose per song across setlist navigation; header shows transposed key

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Task 6: Full verification

**Files:** none (verification only).

- [ ] **Step 1: Run the full Core test suite**

Run: `swift test --filter FreeSongCoreTests 2>&1 | tail -20`
Expected: all tests pass, including the pre-existing Transposer/Parser/Model tests
and the 13 new segmenter + solver tests.

- [ ] **Step 2: Build and launch on the simulator**

Run: `xcodegen generate && xcodebuild -scheme FreeSongiOS -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -20`
Expected: `BUILD SUCCEEDED`. Then run the app (via `build_and_run.sh` or Xcode)
and open a song with chords.

- [ ] **Step 3: Visual/behavioural checklist** (record pass/fail for each)

- [ ] Amazing Grace: each chord sits directly over the correct syllable at font size 14.
- [ ] Same song at font size 28: chords still aligned (no drift growth with column).
- [ ] A long line that wraps: the chord stays above its syllable on the wrapped row.
- [ ] A trailing/instrumental chord past the lyrics renders without clipping.
- [ ] Transpose +2, tap next in a setlist, tap previous back: the +2 offset is restored (not reset to 0).
- [ ] Header "Key:" reflects the transposed key while transposed.

- [ ] **Step 4: Update the CHANGELOG**

Add an entry under the iOS section noting the chord-alignment fix, per-song
transpose persistence, and header transposed-key display. Then commit:

```bash
git add CHANGELOG.md
git commit -m "Update CHANGELOG for SongViewer chord-layout fixes

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Self-Review Notes

- **Spec coverage:** segment layout (Tasks 1,3,4), pure segmentation with all
  edge cases (Task 1), flow wrapping (Tasks 2,3), proportional chord styling
  (Task 4), transpose persistence (Task 5), header key fix (Task 5), tests
  (Tasks 1,2,6). Auto-scroll and font-cap intentionally untouched (spec Non-Goals).
- **Placeholders:** none — every code and test step is complete.
- **Type consistency:** `ChordSegment`/`ChordSegmenter.segments`, `FlowLayoutSolver.Size/Result/layout`, `SongViewerViewModel.init(song:initialTranspose:)`, `SongViewerContent(initialTranspose:onTransposeChanged:)`, and `transposeBySong`/`key(for:)` are used identically across the tasks that define and consume them.
