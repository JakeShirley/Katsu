import SwiftUI

/// Shared breakpoints for wide layouts such as iPhone Duo unfolded (inner
/// display ≈ 669pt wide) and iPad.
enum AdaptiveLayout {
    /// Narrowest width at which content can sit as two side-by-side "pages",
    /// one on each side of the iPhone Duo hinge.
    static let twoPageMinimumWidth: CGFloat = 600

    /// Horizontal content margin applied to both edges of each page in a
    /// two-page layout, so the gutter at the hinge is twice this value.
    static let twoPageMargin: CGFloat = DesignSystem.Spacing.lg

    /// Shortest landscape height that can split into upper and lower halves.
    /// Ordinary phones in landscape (≈440pt or less) stay below this.
    static let tabletopMinimumHeight: CGFloat = 500

    static func isTwoPage(width: CGFloat) -> Bool {
        width >= twoPageMinimumWidth
    }

    /// Landscape with enough height to split into upper and lower halves along
    /// a horizontal hinge (iPhone Duo held like a laptop).
    static func isTabletop(size: CGSize) -> Bool {
        size.width > size.height && size.height >= tabletopMinimumHeight
    }
}

extension View {
    /// Reports whether this view is wide enough for a two-page layout.
    func onTwoPageWidthChange(_ action: @escaping (Bool) -> Void) -> some View {
        onGeometryChange(for: Bool.self) { proxy in
            AdaptiveLayout.isTwoPage(width: proxy.size.width)
        } action: { isTwoPage in
            action(isTwoPage)
        }
    }
}
