import SwiftUI

/// A titled, rounded group of rows for recipe detail, styled like an
/// inset-grouped list section. Recipe detail lays these out in a plain
/// `ScrollView` rather than a `List` so its columns can animate between one
/// and two pages.
struct RecipeDetailCard<Content: View>: View {
    var title: LocalizedStringKey?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .accessibilityAddTraits(.isHeader)
            }

            VStack(alignment: .leading, spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(rows) { row in
                        if row.id != rows.first?.id {
                            Divider()
                                .padding(.leading, DesignSystem.Spacing.lg)
                        }
                        row
                            .frame(maxWidth: .infinity, minHeight: DesignSystem.HitTarget.minimum, alignment: .leading)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                }
            }
            .background(
                DesignSystem.Colors.surface,
                in: RoundedRectangle(cornerRadius: DesignSystem.Radius.xl, style: .continuous)
            )
        }
        // Moves and resizes the card as one unit when recipe detail switches
        // between one and two pages, so rows don't drift from their card.
        .geometryGroup()
    }
}
