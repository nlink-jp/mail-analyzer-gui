import SwiftUI

/// Pure line-breaking arithmetic for FlowLayout, kept free of the Layout
/// protocol so the wrapping decisions are unit-testable.
enum FlowLayoutMath {
    struct Placement: Equatable {
        var x: CGFloat
        var y: CGFloat
    }

    /// Greedy left-to-right flow: items keep their measured size, wrap to a
    /// new line when the next item would cross `maxWidth` (an item wider
    /// than the line gets a line of its own), lines are as tall as their
    /// tallest item.
    static func layout(
        sizes: [CGSize],
        maxWidth: CGFloat,
        spacing: CGFloat
    ) -> (placements: [Placement], size: CGSize) {
        var placements: [Placement] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for size in sizes {
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            placements.append(Placement(x: x, y: y))
            x += size.width
            totalWidth = max(totalWidth, x)
            x += spacing
            lineHeight = max(lineHeight, size.height)
        }

        let totalHeight = sizes.isEmpty ? 0 : y + lineHeight
        return (placements, CGSize(width: totalWidth, height: totalHeight))
    }
}

/// Wrapping flow layout (the legacy CSS was `display: flex; flex-wrap:
/// wrap`; a plain HStack overflowed the window with many or long tags).
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let result = FlowLayoutMath.layout(
            sizes: sizes,
            maxWidth: proposal.width ?? .infinity,
            spacing: spacing)
        return CGSize(
            width: proposal.width ?? result.size.width,
            height: result.size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let result = FlowLayoutMath.layout(
            sizes: sizes,
            maxWidth: bounds.width,
            spacing: spacing)
        for (subview, placement) in zip(subviews, result.placements) {
            subview.place(
                at: CGPoint(x: bounds.minX + placement.x, y: bounds.minY + placement.y),
                proposal: .unspecified)
        }
    }
}
