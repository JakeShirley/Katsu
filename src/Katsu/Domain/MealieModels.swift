import Foundation

/// Subset of `/api/app/about` that Katsu needs to confirm we're talking to a
/// Mealie server and to show a friendly server label.
struct MealieServerInfo: Codable, Equatable {
    let production: Bool?
    let version: String?
    let demoStatus: Bool?
    let allowSignup: Bool?
    let defaultGroupSlug: String?
    let defaultHouseholdSlug: String?

    enum CodingKeys: String, CodingKey {
        case production
        case version
        case demoStatus
        case allowSignup
        case defaultGroupSlug
        case defaultHouseholdSlug
    }
}

/// `POST /api/auth/token` response. Mealie returns snake_case fields.
struct MealieAuthToken: Codable, Equatable {
    let accessToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

/// Subset of `/api/users/self` that v0 displays.
struct MealieUser: Codable, Equatable, Identifiable {
    let id: String
    let username: String
    let email: String?
    let fullName: String?
    let admin: Bool?
    let groupId: String?
    let householdId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case fullName
        case admin
        case groupId
        case householdId
    }
}

/// Paginated `/api/recipes` response used by the recipe list.
struct MealieRecipePage: Codable, Equatable {
    let items: [MealieRecipeSummary]
    let page: Int
    let perPage: Int
    let total: Int?
    let totalPages: Int?

    enum CodingKeys: String, CodingKey {
        case items
        case page
        case perPage = "per_page"
        case total
        case totalPages = "total_pages"
    }
}

struct MealieRecipeFilters: Equatable, Sendable {
    var search: String = ""
    var categories: [String] = []
    var tags: [String] = []
    var households: [String] = []

    var isEmpty: Bool {
        search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            categories.isEmpty && tags.isEmpty && households.isEmpty
    }
}

struct MealieMealPlanPage: Codable, Equatable {
    let items: [MealieMealPlanEntry]
    let page: Int
    let perPage: Int
    let total: Int?
    let totalPages: Int?

    enum CodingKeys: String, CodingKey {
        case items
        case page
        case perPage = "per_page"
        case total
        case totalPages = "total_pages"
    }
}

enum MealieMealPlanEntryType: String, Codable, CaseIterable, Equatable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case side
    case snack
    case drink
    case dessert

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: String(localized: "Breakfast")
        case .lunch: String(localized: "Lunch")
        case .dinner: String(localized: "Dinner")
        case .side: String(localized: "Side")
        case .snack: String(localized: "Snack")
        case .drink: String(localized: "Drink")
        case .dessert: String(localized: "Dessert")
        }
    }
}

struct MealieMealPlanEntry: Codable, Equatable, Identifiable {
    let id: Int
    let date: String
    let entryType: MealieMealPlanEntryType
    let title: String?
    let text: String?
    let recipeID: String?
    let groupID: String?
    let userID: String?
    let householdID: String?
    let recipe: MealieRecipeSummary?

    var displayTitle: String {
        if let recipeName = recipe?.displayName, !recipeName.isEmpty {
            return recipeName
        }
        if let title, !title.isEmpty {
            return title
        }
        if let text, !text.isEmpty {
            return text
        }
        return entryType.displayName
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case entryType
        case title
        case text
        case recipeID = "recipeId"
        case groupID = "groupId"
        case userID = "userId"
        case householdID = "householdId"
        case recipe
    }
}

struct MealieMealPlanEntryCreate: Encodable, Equatable {
    let date: String
    let entryType: MealieMealPlanEntryType
    let title: String
    let text: String
    let recipeID: String?

    enum CodingKeys: String, CodingKey {
        case date
        case entryType
        case title
        case text
        case recipeID = "recipeId"
    }
}

struct MealieMealPlanRandomCreate: Encodable, Equatable {
    let date: String
    let entryType: MealieMealPlanEntryType
}

struct MealieMealPlanEntryUpdate: Encodable, Equatable {
    let date: String
    let entryType: MealieMealPlanEntryType
    let title: String
    let text: String
    let recipeID: String?
    let id: Int
    let groupID: String
    let userID: String

    enum CodingKeys: String, CodingKey {
        case date
        case entryType
        case title
        case text
        case recipeID = "recipeId"
        case id
        case groupID = "groupId"
        case userID = "userId"
    }
}

struct MealieUserRatingSummary: Codable, Equatable {
    let recipeID: String
    let rating: Double?
    let isFavorite: Bool

    enum CodingKeys: String, CodingKey {
        case recipeID = "recipeId"
        case rating
        case isFavorite
    }
}

/// Lightweight recipe summary returned by `/api/recipes`.
struct MealieRecipeSummary: Codable, Equatable, Identifiable {
    let recipeID: String?
    let slug: String
    let name: String?
    let description: String?
    let recipeYield: String?

    var id: String { recipeID ?? slug }
    var displayName: String {
        if let name, !name.isEmpty {
            return name
        }
        return slug
    }

    enum CodingKeys: String, CodingKey {
        case recipeID = "id"
        case slug
        case name
        case description
        case recipeYield
    }
}

/// Full recipe payload returned by `/api/recipes/{slug}`.
struct MealieRecipeDetail: Codable, Equatable, Identifiable {
    let recipeID: String?
    let slug: String
    let name: String?
    let description: String?
    let recipeYield: String?
    let recipeServings: Double?
    let totalTime: String?
    let prepTime: String?
    let cookTime: String?
    let recipeCategory: [MealieRecipeToken]?
    let tags: [MealieRecipeToken]?
    let rating: Double?
    let image: MealieRecipeImage?
    let recipeIngredient: [MealieRecipeIngredient]
    let recipeInstructions: [MealieRecipeInstruction]?
    let nutrition: MealieRecipeNutrition?
    let settings: MealieRecipeSettings?

    var id: String { recipeID ?? slug }
    var displayName: String {
        if let name, !name.isEmpty {
            return name
        }
        return slug
    }

    var summary: MealieRecipeSummary {
        MealieRecipeSummary(
            recipeID: recipeID,
            slug: slug,
            name: name,
            description: description,
            recipeYield: recipeYield
        )
    }

    func imageURL(serverURL: URL) -> URL? {
        guard image != nil, let recipeID else { return nil }
        return serverURL
            .appendingPathComponent("api/media/recipes")
            .appendingPathComponent(recipeID)
            .appendingPathComponent("images/min-original.webp")
    }

    enum CodingKeys: String, CodingKey {
        case recipeID = "id"
        case slug
        case name
        case description
        case recipeYield
        case recipeServings
        case totalTime
        case prepTime
        case cookTime
        case recipeCategory
        case tags
        case rating
        case image
        case recipeIngredient
        case recipeInstructions
        case nutrition
        case settings
    }
}

struct MealieRecipeImage: Codable, Equatable {
    init() {}
    init(from decoder: Decoder) throws {}
    func encode(to encoder: Encoder) throws {}
}

struct MealieRecipeToken: Codable, Equatable, Identifiable {
    let tokenID: String?
    let name: String
    let slug: String

    var id: String { tokenID ?? slug }

    enum CodingKeys: String, CodingKey {
        case tokenID = "id"
        case name
        case slug
    }
}

struct MealieRecipeIngredient: Codable, Equatable, Identifiable {
    let referenceID: String?
    let display: String?
    let title: String?
    let note: String?
    let quantity: Double?
    let unit: MealieIngredientUnit?
    let food: MealieIngredientFood?

    var id: String { referenceID ?? displayText }
    var displayText: String {
        if let display, !display.isEmpty { return display }
        if let title, !title.isEmpty { return title }
        if let note, !note.isEmpty { return note }
        if let foodName = food?.name, !foodName.isEmpty { return foodName }
        return String(localized: "Ingredient")
    }

    enum CodingKeys: String, CodingKey {
        case referenceID = "referenceId"
        case display
        case title
        case note
        case quantity
        case unit
        case food
    }
}

struct MealieIngredientUnit: Codable, Equatable {
    let name: String?
    let abbreviation: String?
}

struct MealieIngredientFood: Codable, Equatable {
    let name: String?
}

struct MealieRecipeInstruction: Codable, Equatable, Identifiable {
    let stepID: String?
    let title: String?
    let summary: String?
    let text: String?

    var id: String { stepID ?? displayText }
    var displayText: String {
        if let text, !text.isEmpty { return text }
        if let summary, !summary.isEmpty { return summary }
        if let title, !title.isEmpty { return title }
        return String(localized: "Instruction")
    }

    enum CodingKeys: String, CodingKey {
        case stepID = "id"
        case title
        case summary
        case text
    }
}

struct MealieRecipeNutrition: Codable, Equatable {
    let calories: String?
    let carbohydrateContent: String?
    let cholesterolContent: String?
    let fatContent: String?
    let fiberContent: String?
    let proteinContent: String?
    let saturatedFatContent: String?
    let sodiumContent: String?
    let sugarContent: String?
    let transFatContent: String?
    let unsaturatedFatContent: String?

    var entries: [MealieRecipeNutritionEntry] {
        [
            entry(label: String(localized: "Calories"), value: calories),
            entry(label: String(localized: "Carbohydrates"), value: carbohydrateContent),
            entry(label: String(localized: "Cholesterol"), value: cholesterolContent),
            entry(label: String(localized: "Fat"), value: fatContent),
            entry(label: String(localized: "Fiber"), value: fiberContent),
            entry(label: String(localized: "Protein"), value: proteinContent),
            entry(label: String(localized: "Saturated fat"), value: saturatedFatContent),
            entry(label: String(localized: "Sodium"), value: sodiumContent),
            entry(label: String(localized: "Sugar"), value: sugarContent),
            entry(label: String(localized: "Trans fat"), value: transFatContent),
            entry(label: String(localized: "Unsaturated fat"), value: unsaturatedFatContent)
        ].compactMap { $0 }
    }

    private func entry(label: String, value: String?) -> MealieRecipeNutritionEntry? {
        guard let value, !value.isEmpty else { return nil }
        return MealieRecipeNutritionEntry(label: label, value: value)
    }
}

struct MealieRecipeNutritionEntry: Identifiable, Equatable {
    var id: String { label }
    let label: String
    let value: String
}

struct MealieRecipeSettings: Codable, Equatable {
    let showNutrition: Bool?
}

/// Paginated shopping-list browser response from `/api/households/shopping/lists`.
struct MealieShoppingListPage: Codable, Equatable {
    let items: [MealieShoppingListSummary]
    let page: Int
    let perPage: Int
    let total: Int?
    let totalPages: Int?

    enum CodingKeys: String, CodingKey {
        case items
        case page
        case perPage = "per_page"
        case total
        case totalPages = "total_pages"
    }
}

struct MealieShoppingListSummary: Codable, Equatable, Identifiable {
    let id: String
    let name: String?
    let createdAt: String?
    let updatedAt: String?
    let recipeReferences: [MealieShoppingRecipeReference]

    var displayName: String {
        if let name, !name.isEmpty { return name }
        return String(localized: "Shopping List")
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt
        case updatedAt
        case recipeReferences
    }
}

struct MealieShoppingListDetail: Codable, Equatable, Identifiable {
    let id: String
    let name: String?
    let createdAt: String?
    let updatedAt: String?
    let listItems: [MealieShoppingListItem]
    let recipeReferences: [MealieShoppingRecipeReference]

    var displayName: String {
        if let name, !name.isEmpty { return name }
        return String(localized: "Shopping List")
    }

    var summary: MealieShoppingListSummary {
        MealieShoppingListSummary(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            recipeReferences: recipeReferences
        )
    }

    func replacingItem(_ item: MealieShoppingListItem) -> MealieShoppingListDetail {
        var updatedItems = listItems
        if let index = updatedItems.firstIndex(where: { $0.id == item.id }) {
            updatedItems[index] = item
        }
        return MealieShoppingListDetail(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            listItems: updatedItems,
            recipeReferences: recipeReferences
        )
    }

    func applying(_ collection: MealieShoppingListItemsCollection) -> MealieShoppingListDetail {
        var updatedItems = listItems
        let deletedIDs = Set(collection.deletedItems.map(\.id))
        updatedItems.removeAll { deletedIDs.contains($0.id) }

        for item in collection.updatedItems + collection.createdItems where item.shoppingListID == id {
            if let index = updatedItems.firstIndex(where: { $0.id == item.id }) {
                updatedItems[index] = item
            } else {
                updatedItems.append(item)
            }
        }

        return MealieShoppingListDetail(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            listItems: updatedItems,
            recipeReferences: recipeReferences
        )
    }

    func addingRecipeReference(recipeID: String, quantity: Double) -> MealieShoppingListDetail {
        let updatedReference = MealieShoppingRecipeReference(
            id: recipeID,
            shoppingListID: id,
            recipeID: recipeID,
            recipeQuantity: quantity
        )
        let updatedReferences = recipeReferences.contains { $0.recipeID == recipeID }
            ? recipeReferences
            : recipeReferences + [updatedReference]
        return MealieShoppingListDetail(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            listItems: listItems,
            recipeReferences: updatedReferences
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt
        case updatedAt
        case listItems
        case recipeReferences
    }
}

struct MealieShoppingListItem: Codable, Equatable, Identifiable {
    let id: String
    let shoppingListID: String
    let display: String
    let note: String?
    let checked: Bool
    let position: Int
    let quantity: Double
    let unit: MealieShoppingIngredientUnit?
    let food: MealieShoppingIngredientFood?
    let label: MealieShoppingLabel?
    let recipeReferences: [MealieShoppingItemRecipeReference]
    let createdAt: String?
    let updatedAt: String?

    var displayName: String {
        if !display.isEmpty { return display }
        if let foodName = food?.name, !foodName.isEmpty { return foodName }
        if let note, !note.isEmpty { return note }
        return String(localized: "Shopping item")
    }

    var quantityText: String? {
        guard quantity != 1 else { return nil }
        let formatted = quantity.formatted(.number.precision(.fractionLength(0...2)))
        if let abbreviation = unit?.abbreviation, !abbreviation.isEmpty {
            return "\(formatted) \(abbreviation)"
        }
        if let unitName = unit?.name, !unitName.isEmpty {
            return "\(formatted) \(unitName)"
        }
        return formatted
    }

    func withChecked(_ checked: Bool) -> MealieShoppingListItem {
        MealieShoppingListItem(
            id: id,
            shoppingListID: shoppingListID,
            display: display,
            note: note,
            checked: checked,
            position: position,
            quantity: quantity,
            unit: unit,
            food: food,
            label: label,
            recipeReferences: recipeReferences,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    enum CodingKeys: String, CodingKey {
        case id
        case shoppingListID = "shoppingListId"
        case display
        case note
        case checked
        case position
        case quantity
        case unit
        case food
        case label
        case recipeReferences
        case createdAt
        case updatedAt
    }
}

struct MealieShoppingListItemUpdate: Encodable, Equatable {
    let shoppingListID: String
    let checked: Bool
    let quantity: Double
    let note: String?
    let display: String
    let position: Int
    let foodID: String?
    let labelID: String?
    let unitID: String?
    let recipeReferences: [MealieShoppingItemRecipeReference]

    init(item: MealieShoppingListItem) {
        shoppingListID = item.shoppingListID
        checked = item.checked
        quantity = item.quantity
        note = item.note
        display = item.display
        position = item.position
        foodID = item.food?.id
        labelID = item.label?.id
        unitID = item.unit?.id
        recipeReferences = item.recipeReferences
    }

    enum CodingKeys: String, CodingKey {
        case shoppingListID = "shoppingListId"
        case checked
        case quantity
        case note
        case display
        case position
        case foodID = "foodId"
        case labelID = "labelId"
        case unitID = "unitId"
        case recipeReferences
    }
}

struct MealieShoppingListItemCreate: Encodable, Equatable {
    let shoppingListID: String
    let checked: Bool
    let quantity: Double
    let note: String?
    let display: String
    let position: Int
    let recipeReferences: [MealieShoppingItemRecipeReferenceCreate]

    enum CodingKeys: String, CodingKey {
        case shoppingListID = "shoppingListId"
        case checked
        case quantity
        case note
        case display
        case position
        case recipeReferences
    }
}

struct MealieShoppingRecipeAdd: Encodable, Equatable {
    let recipeIncrementQuantity: Double
}

struct MealieShoppingListItemsCollection: Codable, Equatable {
    let createdItems: [MealieShoppingListItem]
    let updatedItems: [MealieShoppingListItem]
    let deletedItems: [MealieShoppingListItem]

    var isEmpty: Bool {
        createdItems.isEmpty && updatedItems.isEmpty && deletedItems.isEmpty
    }
}

struct MealieShoppingIngredientUnit: Codable, Equatable {
    let id: String?
    let name: String?
    let abbreviation: String?
}

struct MealieShoppingIngredientFood: Codable, Equatable {
    let id: String?
    let name: String?
}

struct MealieShoppingLabel: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let color: String?
}

struct MealieShoppingRecipeReference: Codable, Equatable, Identifiable {
    let id: String
    let shoppingListID: String?
    let recipeID: String?
    let recipeQuantity: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case shoppingListID = "shoppingListId"
        case recipeID = "recipeId"
        case recipeQuantity
    }
}

struct MealieShoppingItemRecipeReference: Codable, Equatable, Identifiable {
    let id: String?
    let recipeID: String
    let recipeQuantity: Double?
    let recipeScale: Double?
    let recipeNote: String?
    let shoppingListItemID: String?

    enum CodingKeys: String, CodingKey {
        case id
        case recipeID = "recipeId"
        case recipeQuantity
        case recipeScale
        case recipeNote
        case shoppingListItemID = "shoppingListItemId"
    }
}

struct MealieShoppingItemRecipeReferenceCreate: Encodable, Equatable {
    let recipeID: String
    let recipeQuantity: Double
    let recipeScale: Double?
    let recipeNote: String?

    enum CodingKeys: String, CodingKey {
        case recipeID = "recipeId"
        case recipeQuantity
        case recipeScale
        case recipeNote
    }
}

/// Persistable record of a Mealie server the user has connected to.
struct ServerProfile: Codable, Equatable, Identifiable {
    let id: UUID
    var displayName: String
    var serverURL: URL
    var version: String?
    var lastUsername: String?

    init(
        id: UUID = UUID(),
        displayName: String,
        serverURL: URL,
        version: String? = nil,
        lastUsername: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.serverURL = serverURL
        self.version = version
        self.lastUsername = lastUsername
    }
}
