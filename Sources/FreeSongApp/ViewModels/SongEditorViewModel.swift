import SwiftUI
import FreeSongCore
import FreeSongStorage

/// Owns the editor's mutable state: raw text, cursor, dirty tracking, format
/// toggle, chord shifting driven by the cursor, and save/delete persistence.
@MainActor
final class SongEditorViewModel: ObservableObject {
    @Published var editedContent: String
    /// Cursor / selection in the text view, as a UTF-16 NSRange (UITextView units).
    @Published var selectedRange = NSRange(location: 0, length: 0)
    @Published var errorMessage: String?
    @Published var showDeleteConfirmation = false
    @Published var showDiscardConfirmation = false
    /// Set true once a save/delete completes so the view can dismiss itself.
    @Published var isFinished = false

    let song: Song
    private let onSave: () -> Void
    private let onDelete: () -> Void
    private let originalContent: String
    private let repository: SongRepository
    private let setlistRepo: SetlistRepository

    private var filePath: String { song.sourcePath ?? "\(song.title).onsong" }

    init(
        song: Song,
        onSave: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        repository: SongRepository = FileSongRepository.shared,
        setlistRepo: SetlistRepository = CoreDataSetlistRepository()
    ) {
        self.song = song
        self.onSave = onSave
        self.onDelete = onDelete
        self.originalContent = song.rawContent
        self.editedContent = song.rawContent
        self.repository = repository
        self.setlistRepo = setlistRepo
    }

    // MARK: - Derived state

    var isDirty: Bool { editedContent != originalContent }

    /// True when the content is primarily inline (`[G]lyrics`) format.
    var isInlineFormat: Bool { ChordFormatConverter.isInlineFormat(editedContent) }

    /// The inline chord tag the cursor currently sits inside, if any.
    struct ChordCursor: Equatable {
        let occurrence: Int   // global 0-based index matching ChordFormatConverter
        let range: NSRange    // UTF-16 range of the whole `[...]` tag
        let name: String      // chord text without brackets
    }

    var chordAtCursor: ChordCursor? {
        guard let (occurrence, range) = chordPair(atUTF16: selectedRange.location, in: editedContent) else { return nil }
        let ns = editedContent as NSString
        let inner = ns.substring(with: NSRange(location: range.location + 1, length: max(0, range.length - 2)))
        return ChordCursor(occurrence: occurrence, range: range, name: inner)
    }

    // MARK: - Actions

    /// Shift the chord under the cursor. The occurrence index is derived fresh
    /// from the cursor each call, then the cursor is moved to follow the chord's
    /// new position — so repeated taps keep shifting the SAME chord even when it
    /// crosses a neighbor and its occurrence index changes.
    func shift(delta: Int, wordwise: Bool) {
        guard let chord = chordAtCursor else { return }
        let old = editedContent
        let new = ChordFormatConverter.shiftChord(
            in: old, globalChordOccurrence: chord.occurrence, delta: delta, wordwise: wordwise
        )
        guard new != old else { return }   // hit a line boundary, nothing moved
        editedContent = new
        selectedRange = NSRange(location: followLocation(old: old, new: new, movingRight: delta > 0), length: 0)
    }

    func toggleFormat() {
        editedContent = isInlineFormat
            ? ChordFormatConverter.inlineToAbove(editedContent)
            : ChordFormatConverter.aboveToInline(editedContent)
        let len = (editedContent as NSString).length
        if selectedRange.location > len {
            selectedRange = NSRange(location: len, length: 0)
        }
    }

    func requestCancel(dismiss: () -> Void) {
        if isDirty { showDiscardConfirmation = true } else { dismiss() }
    }

    func save() {
        var updated = song
        updated.rawContent = editedContent
        let parsed = SongParser.parse(editedContent)
        updated.title = parsed.title
        updated.artist = parsed.artist
        updated.key = parsed.key
        updated.sections = parsed.sections
        Task {
            do {
                try await repository.saveSong(updated, at: filePath)
                onSave()
                isFinished = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Delete the file and, like the library delete, strip it from every setlist.
    func delete() {
        Task {
            do {
                try await repository.deleteSong(at: filePath)
                let containing = try await setlistRepo.getSetlistsContaining(songPath: filePath)
                for var setlist in containing {
                    setlist.items.removeAll { $0.songPath == filePath }
                    try await setlistRepo.saveSetlist(setlist)
                }
                onDelete()
                isFinished = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Cursor -> chord resolution

    /// Find the `[...]` chord tag containing (or immediately after) the given
    /// UTF-16 offset, enumerating pairs the same way `ChordFormatConverter`
    /// does (per line, `[` then next `]`) so the occurrence index matches.
    private func chordPair(atUTF16 loc: Int, in text: String) -> (occurrence: Int, range: NSRange)? {
        let ns = text as NSString
        let open = UInt16(UnicodeScalar("[").value)
        let close = UInt16(UnicodeScalar("]").value)
        let newline = UInt16(UnicodeScalar("\n").value)
        var occurrence = 0
        var i = 0
        let len = ns.length
        while i < len {
            if ns.character(at: i) == open {
                var j = i + 1
                var closeIdx = -1
                while j < len {
                    let c = ns.character(at: j)
                    if c == close { closeIdx = j; break }
                    if c == newline { break }
                    j += 1
                }
                if closeIdx >= 0 {
                    if loc >= i && loc <= closeIdx + 1 {
                        return (occurrence, NSRange(location: i, length: closeIdx - i + 1))
                    }
                    occurrence += 1
                    i = closeIdx + 1
                    continue
                }
            }
            i += 1
        }
        return nil
    }

    /// After a shift, locate the moved chord via the common prefix/suffix of the
    /// old and new text. Moving right lands the cursor just past the chord's `]`,
    /// moving left just past its `[`; either way `chordPair` re-resolves to the
    /// same chord on the next tap.
    private func followLocation(old: String, new: String, movingRight: Bool) -> Int {
        let o = old as NSString, n = new as NSString
        let minLen = min(o.length, n.length)
        var p = 0
        while p < minLen && o.character(at: p) == n.character(at: p) { p += 1 }
        var s = 0
        while s < (minLen - p) && o.character(at: o.length - 1 - s) == n.character(at: n.length - 1 - s) { s += 1 }
        return movingRight ? (n.length - s) : p
    }
}
