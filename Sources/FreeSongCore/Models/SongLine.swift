import Foundation

// MARK: - SongLine

/// Represents a line with lyrics and chord positions.
public struct SongLine: Codable, Equatable, Hashable, Sendable {
    public var lyrics: String
    public var chords: [ChordPosition]
    public var keyChange: KeyChange?

    public init(lyrics: String = "", chords: [ChordPosition] = [], keyChange: KeyChange? = nil) {
        self.lyrics = lyrics
        self.chords = chords
        self.keyChange = keyChange
    }

    public var isKeyChange: Bool {
        return keyChange != nil
    }

    public mutating func addChord(_ chord: ChordPosition) {
        chords.append(chord)
    }
}