import SwiftUI
import FreeSongCore

@MainActor
final class SongViewerViewModel: ObservableObject {
    private var pageTurnerObserver: NSObjectProtocol?
    private var pageTurnerPrevObserver: NSObjectProtocol?
    @Published var transposeOffset = 0
    @Published var useFlats = false
    @Published var useNashville = false
    @Published var isAutoScrolling = false
    @Published var autoScrollInterval: Double = 4  // seconds per section
    @Published var autoScrollSectionIndex = 0
    @Published var showScrollSpeedSlider = false
    /// Session-only key picked by the user for Nashville display when the song has none
    /// of its own. Not persisted to the file.
    @Published var manualNashvilleKey: String?
    /// Set to true to prompt the user for a key before turning Nashville mode on.
    @Published var showNashvilleKeyPicker = false

    @AppStorage("songViewerFontSize") var fontSize: Double = 18

    private let originalSong: Song
    private var autoScrollTask: Task<Void, Never>?

    init(song: Song, initialTranspose: Int? = nil) {
        self.originalSong = song
        self.transposeOffset = initialTranspose ?? song.transpose
        // Seed the spelling preference from the song's own chords (Android's
        // toggleAccidentals auto-detects the current style the same way), so
        // opening a song never respells it until the user toggles.
        // ponytail: majority-vote heuristic over chord accidentals; ties/no accidentals default to sharps.
        let allChords = song.sections.flatMap(\.lines).flatMap(\.chords).map(\.chord).joined(separator: " ")
        self.useFlats = !AccidentalConverter.isSharpsFormat(allChords)
        self.useNashville = song.useNashville

        // Observe BLE page turner events
        pageTurnerObserver = NotificationCenter.default.addObserver(
            forName: .pageTurnerDidAdvance, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.advanceToNextSection() }
        }
        pageTurnerPrevObserver = NotificationCenter.default.addObserver(
            forName: .pageTurnerDidReverse, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.goToPreviousSection() }
        }
    }

    var transposedSong: Song {
        SongRenderer.render(
            originalSong, transpose: transposeOffset, useFlats: useFlats, useNashville: useNashville,
            nashvilleKey: manualNashvilleKey
        )
    }

    /// True when the song has no key of its own to derive Nashville numbers from.
    private var songHasNoKey: Bool {
        (originalSong.key ?? originalSong.originalKey ?? "").isEmpty
    }

    /// Unique label for the current auto-scroll target section.
    var autoScrollTargetLabel: String? {
        let sections = transposedSong.sections
        guard !sections.isEmpty else { return nil }
        let idx = min(autoScrollSectionIndex, sections.count - 1)
        return sections[idx].label.isEmpty ? "section-\(idx)" : sections[idx].label
    }

    deinit {
        autoScrollTask?.cancel()
        if let obs = pageTurnerObserver { NotificationCenter.default.removeObserver(obs) }
        if let obs = pageTurnerPrevObserver { NotificationCenter.default.removeObserver(obs) }
    }

    func transpose(by semitones: Int) {
        transposeOffset += semitones
    }

    func resetTranspose() {
        transposeOffset = 0
    }

    func toggleFlats() {
        useFlats.toggle()
    }

    /// Toggles Nashville mode. If the song has no key and none has been picked yet this
    /// session, asks the user for one first instead of silently defaulting to C.
    func toggleNashville() {
        if useNashville {
            useNashville = false
            return
        }
        if songHasNoKey && manualNashvilleKey == nil {
            showNashvilleKeyPicker = true
            return
        }
        useNashville = true
    }

    /// Called when the user picks a key from the Nashville key-selection dialog.
    func selectNashvilleKey(_ key: String) {
        manualNashvilleKey = key
        useNashville = true
        showNashvilleKeyPicker = false
    }

    func toggleAutoScroll() {
        if isAutoScrolling {
            stopAutoScroll()
        } else {
            startAutoScroll()
        }
    }

    func startAutoScroll() {
        autoScrollSectionIndex = 0
        isAutoScrolling = true
        autoScrollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(autoScrollInterval * 1_000_000_000))
                if !Task.isCancelled {
                    await MainActor.run {
                        let maxIndex = self.transposedSong.sections.count - 1
                        if self.autoScrollSectionIndex < maxIndex {
                            self.autoScrollSectionIndex += 1
                        } else {
                            // Reached end — stop or loop
                            self.stopAutoScroll()
                        }
                    }
                }
            }
        }
    }

    func stopAutoScroll() {
        isAutoScrolling = false
        autoScrollTask?.cancel()
        autoScrollTask = nil
    }

    /// Advance to next section (triggered by page turner or manual scroll).
    func advanceToNextSection() {
        let maxIndex = transposedSong.sections.count - 1
        guard maxIndex >= 0 else { return }
        if autoScrollSectionIndex < maxIndex {
            autoScrollSectionIndex += 1
        }
    }

    /// Go back to previous section (triggered by page turner or manual scroll).
    func goToPreviousSection() {
        guard autoScrollSectionIndex > 0 else { return }
        autoScrollSectionIndex -= 1
    }

}
