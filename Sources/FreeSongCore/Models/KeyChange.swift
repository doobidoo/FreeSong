import Foundation

// MARK: - KeyChange

/// Represents a key change within a song.
/// Used to transpose subsequent chords to a new key.
public struct KeyChange: Codable, Equatable, Hashable, Sendable {
    public var newKey: String

    public init(newKey: String) {
        self.newKey = newKey
    }
}