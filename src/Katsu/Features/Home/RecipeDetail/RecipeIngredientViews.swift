import SwiftUI

struct RecipeIngredientRow: View {
    let ingredient: MealieRecipeIngredient

    private var display: RecipeIngredientDisplay {
        RecipeIngredientDisplay(ingredient: ingredient)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.md) {
            if let measurement = display.measurement {
                Text(measurement)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.accentDeep)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .frame(width: 76)
                    .frame(minHeight: DesignSystem.HitTarget.minimum)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.accentSoft, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(display.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                if let note = display.note {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(display.accessibilityLabel)
    }
}

struct RecipeIngredientDisplay {
    let measurement: String?
    let name: String
    let note: String?

    init(measurement: String?, name: String, note: String?) {
        self.measurement = measurement
        self.name = name
        self.note = note
    }

    var accessibilityLabel: String {
        [measurement, name, note]
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: ", ")
    }

    init(ingredient: MealieRecipeIngredient) {
        let structuredMeasurement = Self.structuredMeasurement(for: ingredient)
        let structuredName = ingredient.food?.name?.nilIfBlank

        if let structuredMeasurement, let structuredName {
            measurement = structuredMeasurement
            name = structuredName
            note = Self.distinctNote(ingredient.note, from: [structuredMeasurement, structuredName, ingredient.display])
            return
        }

        if let structuredName {
            measurement = nil
            name = structuredName
            note = Self.distinctNote(ingredient.note, from: [structuredName, ingredient.display])
            return
        }

        measurement = nil
        name = ingredient.displayText
        note = Self.distinctNote(ingredient.note, from: [ingredient.displayText, ingredient.display])
    }

    private static func structuredMeasurement(for ingredient: MealieRecipeIngredient) -> String? {
        guard let quantity = ingredient.quantity.flatMap(formatQuantity),
              let unit = ingredient.unit?.abbreviation?.nilIfBlank ?? ingredient.unit?.name?.nilIfBlank else {
            return nil
        }
        return "\(quantity) \(unit)"
    }

    private static func formatQuantity(_ quantity: Double) -> String? {
        guard quantity > 0 else { return nil }
        if quantity.rounded() == quantity {
            return String(Int(quantity))
        }
        return String(format: "%.2f", quantity)
            .trimmingCharacters(in: CharacterSet(charactersIn: "0"))
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    private static func distinctNote(_ note: String?, from displayedValues: [String?]) -> String? {
        guard let note = note?.nilIfBlank else { return nil }
        let normalizedNote = normalizedIngredientText(note)
        let duplicatesDisplayedValue = displayedValues
            .compactMap { $0?.nilIfBlank }
            .map(normalizedIngredientText)
            .contains(normalizedNote)
        return duplicatesDisplayedValue ? nil : note
    }

    private static func normalizedIngredientText(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
