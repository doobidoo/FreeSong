import Foundation

// MARK: - ChordPosition

/// Represents a chord at a specific position in the lyrics.
/// Position is the character index in the lyrics string where the chord should appear above.
public struct ChordPosition: Codable, Equatable, Hashable, Sendable {
    public var chord: String
    public var position: Int

    public init(chord: String, position: Int) {
        self.chord = chord
        self.position = position
    }
}

// MARK:}