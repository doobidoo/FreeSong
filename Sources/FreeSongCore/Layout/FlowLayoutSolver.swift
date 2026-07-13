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