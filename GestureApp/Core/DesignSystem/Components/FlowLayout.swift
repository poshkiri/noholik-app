import SwiftUI

/// Simple flow layout that wraps subviews to new lines when they don't fit.
/// Used for tag clouds, interests, communication prefs, etc.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = layoutRows(maxWidth: maxWidth, subviews: subviews)

        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        for (index, row) in rows.enumerated() {
            let rowHeight: CGFloat = row.map(\.height).max() ?? 0
            var rowWidth: CGFloat = 0
            for (itemIndex, size) in row.enumerated() {
                rowWidth += size.width
                if itemIndex < row.count - 1 { rowWidth += spacing }
            }
            totalWidth = max(totalWidth, rowWidth)
            totalHeight += rowHeight
            if index < rows.count - 1 { totalHeight += spacing }
        }
        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }

    // MARK: Helpers

    private func layoutRows(maxWidth: CGFloat, subviews: Subviews) -> [[CGSize]] {
        var rows: [[CGSize]] = [[]]
        var currentWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let wouldOverflow = currentWidth + size.width > maxWidth
            let isCurrentRowEmpty = rows[rows.count - 1].isEmpty

            if wouldOverflow && !isCurrentRowEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(size)
            currentWidth += size.width + spacing
        }
        return rows
    }
}
