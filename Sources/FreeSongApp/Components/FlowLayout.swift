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