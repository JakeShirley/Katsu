import SwiftUI

struct RecipeMetadataView: View {
    let detail: MealieRecipeDetail
    @Binding var adjustedServings: Double?

    var body: some View {
        let totalTime = detail.totalTime.flatMap(recipeReadableDuration)
        let prepTime = detail.prepTime.flatMap(recipeReadableDuration)
        let cookTime = (detail.cookTime ?? detail.performTime).flatMap(recipeReadableDuration)

        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let totalTime {
                RecipeTotalTimeCard(totalTime: totalTime)
            }
            if prepTime != nil || cookTime != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        if let prepTime {
                            RecipeTimeMetric(label: "Prep", value: prepTime, systemImage: "timer", prefersSingleLine: true)
                        }
                        if let cookTime {
                            RecipeTimeMetric(label: "Cook", value: cookTime, systemImage: "flame", prefersSingleLine: true)
                        }
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        if let prepTime {
                            RecipeTimeMetric(label: "Prep", value: prepTime, systemImage: "timer", prefersSingleLine: false)
                        }
                        if let cookTime {
                            RecipeTimeMetric(label: "Cook", value: cookTime, systemImage: "flame", prefersSingleLine: false)
                        }
                    }
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

extension MealieRecipeDetail {
    var defaultServings: Double? {
        if let recipeServings, recipeServings > 0 {
            return recipeServings
        }
        if let recipeYieldQuantity, recipeYieldQuantity > 0 {
            return recipeYieldQuantity
        }
        return nil
    }

    var canAdjustServings: Bool {
        guard defaultServings != nil, settings?.disableAmount != true else { return false }
        return recipeIngredient.contains { ingredient in
            (ingredient.quantity ?? 0) > 0
        }
    }
}

struct RecipeServingsMetric: View {
    let detail: MealieRecipeDetail
    @Binding var adjustedServings: Double?

    private var servingValue: Binding<Double> {
        Binding(
            get: { adjustedServings ?? detail.defaultServings ?? 1 },
            set: { adjustedServings = max(1, $0) }
        )
    }

    private var servingDisplayValue: String {
        Self.formatServings(adjustedServings ?? detail.defaultServings) ?? detail.recipeYield?.nilIfBlank ?? "-"
    }

    var body: some View {
        Group {
            if detail.canAdjustServings {
                Stepper(value: servingValue, in: 1...99, step: 1) {
                    label
                }
                .accessibilityLabel("Adjust servings")
                .accessibilityValue(servingDisplayValue)
            } else {
                label
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.background, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        .accessibilityElement(children: detail.canAdjustServings ? .contain : .combine)
        .accessibilityLabel(detail.canAdjustServings ? "Adjust servings" : String(localized: "Servings: \(servingDisplayValue)"))
    }

    private var label: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "person.2.fill")
                .foregroundStyle(DesignSystem.Colors.accentDeep)
                .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                .background(DesignSystem.Colors.accentSoft, in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text("Servings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: true, vertical: false)
                Text(servingDisplayValue)
                    .font(.title3.monospacedDigit())
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: true, vertical: false)
                if detail.defaultServings == nil,
                   let recipeYield = detail.recipeYield?.nilIfBlank,
                   recipeYield != servingDisplayValue {
                    Text(recipeYield)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .layoutPriority(1)
        }
    }

    private static func formatServings(_ value: Double?) -> String? {
        guard let value else { return nil }
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value).trimmingTrailingZeros()
    }
}

func recipeReadableDuration(_ value: String) -> String? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    guard trimmed.hasPrefix("P") else { return trimmed }

    var hours = 0
    var minutes = 0
    var isTimeComponent = false
    var number = ""

    for character in trimmed.dropFirst() {
        if character.isNumber {
            number.append(character)
        } else if character == "T" {
            isTimeComponent = true
        } else {
            guard let durationValue = Int(number) else { return trimmed }
            switch character {
            case "D":
                hours += durationValue * 24
            case "H":
                guard isTimeComponent else { return trimmed }
                hours += durationValue
            case "M":
                guard isTimeComponent else { return trimmed }
                minutes += durationValue
            case "S":
                guard isTimeComponent else { return trimmed }
                if durationValue >= 30 {
                    minutes += 1
                }
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
    var prefersSingleLine = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: prefersSingleLine, vertical: false)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: prefersSingleLine, vertical: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.background, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
        .accessibilityElement(children: .combine)
    }
}
