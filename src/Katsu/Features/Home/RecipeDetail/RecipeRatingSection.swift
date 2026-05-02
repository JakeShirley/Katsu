import SwiftUI

struct RecipeRatingSection: View {
    let rating: MealieUserRatingSummary
    let isUpdating: Bool
    let errorMessage: String?
    let onToggleFavorite: (MealieUserRatingSummary) async -> Void
    let onSetRating: (Double?) async -> Void

    var body: some View {
        Section("My Rating") {
            Button {
                Task { await onToggleFavorite(rating) }
            } label: {
                Label(rating.isFavorite ? "Remove Favorite" : "Add Favorite", systemImage: rating.isFavorite ? "heart.fill" : "heart")
                    .frame(maxWidth: .infinity, minHeight: DesignSystem.HitTarget.minimum, alignment: .leading)
            }
            .disabled(isUpdating)
            .accessibilityLabel(rating.isFavorite ? "Remove Favorite" : "Add Favorite")

            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        Task { await onSetRating(Double(value)) }
                    } label: {
                        Image(systemName: (rating.rating ?? 0) >= Double(value) ? "star.fill" : "star")
                            .font(.title3)
                            .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                    }
                    .buttonStyle(.plain)
                    .disabled(isUpdating)
                    .accessibilityLabel(String(localized: "Set rating to \(value) stars"))
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.destructive)
            }
        }
    }
}
