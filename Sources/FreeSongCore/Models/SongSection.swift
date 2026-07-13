import Foundation

// MARK: - SongSection

/// Represents a section of a song (Verse, Chorus, Bridge, etc.)
public struct SongSection: Codable, Equatable, Hashable, Sendable {
    public var label: String
    public var lines: [SongLine]

    public init(label: String = "", lines: [SongLine] = []) {
        self.label = label
        self.lines = lines
    }

    public mutating func addLine(_ line: SongLine) {
        lines.append(line)
    }
}