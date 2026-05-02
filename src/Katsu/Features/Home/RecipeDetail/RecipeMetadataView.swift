import SwiftUI

struct RecipeMetadataView: View {
    let detail: MealieRecipeDetail

    var body: some View {
        let totalTime = detail.totalTime.flatMap(recipeReadableDuration)
        let prepTime = detail.prepTime.flatMap(recipeReadableDuration)
        let cookTime = detail.cookTime.flatMap(recipeReadableDuration)

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let recipeYield = detail.recipeYield, !recipeYield.isEmpty {
                Label(recipeYield, systemImage: "fork.knife")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            if let totalTime {
                RecipeTotalTimeCard(totalTime: totalTime)
            }
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                if let prepTime {
                    RecipeTimeMetric(label: "Prep", value: prepTime, systemImage: "timer")
                }
                if let cookTime {
                    RecipeTimeMetric(label: "Cook", value: cookTime, systemImage: "flame")
                }
            }
            if let rating = detail.rating {
                Label(String(localized: "Rating: \(rating, specifier: "%.1f")"), systemImage: "star.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

func recipeReadableDuration(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    guard trimmed.hasPrefix("PT") else { return trimmed }

    var hours = 0
    var minutes = 0
    var number = ""

    for character in trimmed.dropFirst(2) {
        if character.isNumber {
            number.append(character)
        } else {
            guard let durationValue = Int(number) else { return trimmed }
            switch character {
            case "H":
                hours = durationValue
            case "M":
                minutes = durationValue
            default:
                return trimmed
            }
            number = ""
        }
    }

    guard number.isEmpty else { return trimmed }
    let parts = [
        hours > 0 ? String(localized: "\(hours) hr") : nil,
        minutes > 0 ? String(localized: "\(minutes) min") : nil
    ].compactMap(\.self)
    return parts.isEmpty ? trimmed : parts.joined(separator: " ")
}

private struct RecipeTotalTimeCard: View {
    let totalTime: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "clock.fill")
                .font(.title3)
                .foregroundStyle(DesignSystem.Colors.accentDeep)
                .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                .background(DesignSystem.Colors.accentSoft, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text("Total Time")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(totalTime)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(DesignSystem.Colors.separator.opacity(0.5), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Total time: \(totalTime)"))
    }
}

private struct RecipeTimeMetric: View {
    let label: LocalizedStringKey
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        .accessibilityElement(children: .combine)
    }
}
