import Foundation

enum ShoppingItemAddMode: String, CaseIterable, Identifiable {
    case manual
    case recipe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual: String(localized: "Manual Item")
        case .recipe: String(localized: "Recipe Ingredients")
        }
    }
}

struct ShoppingItemAddDraft: Identifiable {
    let id = UUID()
    let listID: String
    let nextPosition: Int
}

struct ShoppingItemAddValue {
    let mode: ShoppingItemAddMode
    let display: String
    let quantity: Double
    let note: String?
    let position: Int
    let recipeID: String?
    let recipeQuantity: Double
}

struct ShoppingListAddValue {
    let name: String
}

func shoppingItemSort(_ lhs: MealieShoppingListItem, _ rhs: MealieShoppingListItem) -> Bool {
    if lhs.checked != rhs.checked {
        return !lhs.checked
    }
    return lhs.position < rhs.position
}
