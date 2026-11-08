import SwiftUI

struct RecipeRow: View {
    let recipe: MealieRecipeSummary
    let profileID: UUID?
    let serverURL: URL?
    var showsDisclosureIndicator = false
    /// Stretches the card to the tallest card in its grid row.
    var fillsAvailableHeight = false

    private var imageURL: URL? {
        guard let serverURL else { return nil }
        return recipe.imageURL(serverURL: serverURL)
    }

    private var accentSymbol: String {
        let lowercasedName = recipe.displayName.lowercased()
        if lowercasedName.contains("salmon") || lowercasedName.contains("soup") {
            return "flame.fill"
        }
        if lowercasedName.contains("salad") || lowercasedName.contains("carrot") {
            return "leaf.fill"
        }
        if lowercasedName.contains("pancake") || lowercasedName.contains("parfait") {
            return "sun.max.fill"
        }
        return "fork.knife"
    }

    private var categoryHint: LocalizedStringKey {
        let lowercasedName = recipe.displayName.lowercased()
        if lowercasedName.contains("salmon") || lowercasedName.contains("curry") || lowercasedName.contains("noodle") || lowercasedName.contains("soup") {
            return "Dinner"
        }
        if lowercasedName.contains("salad") || lowercasedName.contains("carrot") {
            return "Fresh"
        }
        if lowercasedName.contains("pancake") || lowercasedName.contains("parfait") {
            return "Breakfast"
        }
        return "Recipe"
    }

    var body: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.lg) {
            RecipeRowArtwork(recipe: recipe, profileID: profileID, imageURL: imageURL, accentSymbol: accentSymbol)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(recipe.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        if let description = recipe.description, !description.isEmpty {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: DesignSystem.Spacing.xs)
                }

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(categoryHint)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.accentDeep)
                        .lineLimit(1)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(DesignSystem.Colors.accentSoft.opacity(0.75), in: Capsule())

                    if let recipeYield = recipe.recipeYield, !recipeYield.isEmpty {
                        Label(recipeYield, systemImage: "person.2")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            if showsDisclosureIndicator {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                    .accessibilityHidden(true)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxHeight: fillsAvailableHeight ? .infinity : nil, alignment: .leading)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(DesignSystem.Colors.separator.opacity(0.16))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        [recipe.displayName, recipe.description, recipe.recipeYield]
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: ", ")
    }
}

private struct RecipeRowArtwork: View {
    @EnvironmentObject private var env: AppEnvironment
    let recipe: MealieRecipeSummary
    let profileID: UUID?
    let imageURL: URL?
    let accentSymbol: String

    private var localImageURL: URL? {
        guard let profileID, let recipeID = recipe.recipeID else { return nil }
        return env.recipeOfflineCache.localImageURL(profileID: profileID, recipeID: recipeID, slug: recipe.slug, fileName: "min-original.webp")
    }

    var body: some View {
        Group {
            if let localImageURL {
                AsyncImage(url: localImageURL) { phase in
                    switch phase {
                    case .empty:
                        fallback
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        fallback
                            .overlay {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(DesignSystem.Colors.accentDeep)
                            }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        fallback
                    @unknown default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: 76, height: 76)
        .contentShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .accessibilityHidden(true)
    }

    private var fallback: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .fill(LinearGradient(
                    colors: [
                        DesignSystem.Colors.accentSoft,
                        DesignSystem.Colors.accent.opacity(0.22)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Image(systemName: accentSymbol)
                .font(.title2)
                .foregroundStyle(DesignSystem.Colors.accentDeep)
                .frame(width: 32, height: 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Image(systemName: "sparkle")
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.accentDeep.opacity(0.55))
                .padding(DesignSystem.Spacing.sm)
        }
    }
}
