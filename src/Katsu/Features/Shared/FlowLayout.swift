import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, proposedWidth: proposal.width ?? 0)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x > bounds.minX && origin.x + size.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: origin, proposal: ProposedViewSize(size))
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    private func rows(for subviews: Subviews, proposedWidth: CGFloat) -> [CGSize] {
        var rows: [CGSize] = []
        var current = CGSize.zero
        let maxWidth = proposedWidth > 0 ? proposedWidth : .greatestFiniteMagnitude

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if current.width > 0 && current.width + spacing + size.width > maxWidth {
                rows.append(current)
                current = size
            } else {
                current.width += current.width > 0 ? spacing + size.width : size.width
                current.height = max(current.height, size.height)
            }
        }
        if current.width > 0 || current.height > 0 {
            rows.append(current)
        }
        return rows
    }
}
