import SwiftUI

struct RecipeIngredientRow: View {
    let ingredient: MealieRecipeIngredient
    var scaleFactor = 1.0

    private var display: RecipeIngredientDisplay {
        RecipeIngredientDisplay(ingredient: ingredient, scaleFactor: scaleFactor)
    }

    var body: some View {
        RecipeIngredientContent(display: display)
            .padding(.vertical, DesignSystem.Spacing.xs)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(display.accessibilityLabel)
    }
}

struct RecipeIngredientContent: View {
    let display: RecipeIngredientDisplay

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

    init(ingredient: MealieRecipeIngredient, scaleFactor: Double = 1) {
        let structuredMeasurement = Self.structuredMeasurement(for: ingredient, scaleFactor: scaleFactor)
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

    init(shoppingItem: MealieShoppingListItem) {
        let structuredMeasurement = Self.structuredMeasurement(for: shoppingItem)
        let structuredName = shoppingItem.food?.name?.nilIfBlank

        if let structuredMeasurement, let structuredName {
            measurement = structuredMeasurement
            name = structuredName
            note = Self.distinctNote(shoppingItem.note, from: [structuredMeasurement, structuredName, shoppingItem.display])
            return
        }

        if let structuredName {
            measurement = nil
            name = structuredName
            note = Self.distinctNote(shoppingItem.note, from: [structuredName, shoppingItem.display])
            return
        }

        measurement = nil
        name = shoppingItem.displayName
        note = Self.distinctNote(shoppingItem.note, from: [shoppingItem.displayName, shoppingItem.display])
    }

    private static func structuredMeasurement(for ingredient: MealieRecipeIngredient, scaleFactor: Double) -> String? {
        guard let rawQuantity = ingredient.quantity,
              let quantity = formatQuantity(rawQuantity * scaleFactor),
              let unit = ingredient.unit?.abbreviation?.nilIfBlank ?? ingredient.unit?.name?.nilIfBlank else {
            return nil
        }
        return "\(quantity) \(unit)"
    }

    private static func structuredMeasurement(for item: MealieShoppingListItem) -> String? {
        guard let quantity = formatQuantity(item.quantity),
              let unit = item.unit?.abbreviation?.nilIfBlank ?? item.unit?.name?.nilIfBlank else {
            return nil
        }
        return "\(quantity) \(unit)"
    }

    private static func formatQuantity(_ quantity: Double) -> String? {
        guard quantity > 0 else { return nil }
        if quantity.rounded() == quantity {
            return String(Int(quantity))
        }
        return String(format: "%.2f", quantity).trimmingTrailingZeros()
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

    func trimmingTrailingZeros() -> String {
        guard contains(".") else { return self }
        var value = self
        while value.last == "0" {
            value.removeLast()
        }
        if value.last == "." {
            value.removeLast()
        }
        return value
    }
}
