import SwiftUI

struct ShoppingListsHeroCard: View {
    let listCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(systemName: "cart")
                .font(.title3)
                .foregroundStyle(DesignSystem.Colors.accentDeep)
                .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                .background(DesignSystem.Colors.accentSoft.opacity(0.75), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Shop from your Mealie lists")
                        .font(.headline)

                    Text("Open a list to review what you need before heading to the store.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Label(String(localized: "Shopping lists: \(listCount)"), systemImage: "list.bullet")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.accentDeep)
                    .lineLimit(1)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.accentSoft.opacity(0.75), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .padding(.top, DesignSystem.Spacing.sm)
        .padding(.bottom, DesignSystem.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Shop from your Mealie lists. Open a list to review what you need before heading to the store. Shopping lists: \(listCount)"))
    }
}

struct ShoppingListRow: View {
    let list: MealieShoppingListSummary

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(systemName: "checklist")
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Colors.accentDeep)
                .frame(width: 36, height: 36)
                .background(DesignSystem.Colors.accentSoft.opacity(0.75), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(list.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if !list.recipeReferences.isEmpty {
                    Label(String(localized: "Recipes: \(list.recipeReferences.count)"), systemImage: "book.closed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if list.recipeReferences.isEmpty {
            return list.displayName
        }
        return String(localized: "\(list.displayName), recipes: \(list.recipeReferences.count)")
    }
}

struct ShoppingListStatusRow: View {
    let detail: MealieShoppingListDetail

    private var checkedCount: Int {
        detail.listItems.filter(\.checked).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(detail.displayName)
                .font(.headline)

            Label(String(localized: "Items: \(detail.listItems.count)"), systemImage: "checklist")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(String(localized: "Checked: \(checkedCount)"), systemImage: "checkmark.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(detail.displayName), items: \(detail.listItems.count), checked: \(checkedCount)"))
    }
}

struct ShoppingItemToggleRow: View {
    let item: MealieShoppingListItem
    let isSaving: Bool
    let isFading: Bool
    let onToggle: () -> Void

    private var isRecipeIngredient: Bool {
        !item.recipeReferences.isEmpty
    }

    private var recipeIngredientDisplay: RecipeIngredientDisplay {
        RecipeIngredientDisplay(shoppingItem: item)
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.checked ? DesignSystem.Colors.accent : .secondary)
                    .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                    .accessibilityHidden(true)

                itemContent

                Spacer(minLength: DesignSystem.Spacing.sm)

                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Updating item")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .opacity(isFading ? 0.25 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(item.checked ? "Marks this item unchecked" : "Marks this item checked")
    }

    @ViewBuilder private var itemContent: some View {
        if isRecipeIngredient {
            RecipeIngredientContent(display: recipeIngredientDisplay)
                .strikethrough(item.checked)
                .foregroundStyle(item.checked ? .secondary : .primary)
        } else {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(item.displayName)
                    .font(.body)
                    .strikethrough(item.checked)
                    .foregroundStyle(item.checked ? .secondary : .primary)

                if let quantityText = item.quantityText {
                    Text(quantityText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let note = item.note, !note.isEmpty, note != item.displayName {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var accessibilityLabel: String {
        if isRecipeIngredient {
            return [
                recipeIngredientDisplay.accessibilityLabel,
                item.checked ? String(localized: "Checked") : String(localized: "Unchecked")
            ]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        }

        return [
            item.displayName,
            item.checked ? String(localized: "Checked") : String(localized: "Unchecked"),
            item.quantityText,
            item.note == item.displayName ? nil : item.note
        ]
        .compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        .joined(separator: ", ")
    }
}

struct ShoppingLoadingRow: View {
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ProgressView()
            Text(title)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}

struct ShoppingErrorRow: View {
    let errorMessage: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(errorMessage)
                .foregroundStyle(DesignSystem.Colors.destructive)
            Button("Try Again", action: onRetry)
                .frame(minHeight: DesignSystem.HitTarget.minimum)
        }
    }
}
