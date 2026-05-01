import Foundation

/// In-memory implementation used when `-debugUseMockServer` is set. Backed
/// by hard-coded fixtures so the app runs entirely offline for previews,
/// snapshots, and demos.
final class MockMealieAPIClient: MealieAPIClient, @unchecked Sendable {
    private let serverInfo: MealieServerInfo
    private let user: MealieUser
    private var recipes: [MealieRecipeSummary]
    private var mealPlanEntries: [MealieMealPlanEntry]
    private var userRatings: [String: MealieUserRatingSummary]
    private var shoppingLists: [MealieShoppingListDetail]
    private let validUsername: String
    private let validPassword: String
    private let mintedToken: MealieAuthToken

    init(
        serverInfo: MealieServerInfo,
        user: MealieUser,
        recipes: [MealieRecipeSummary],
        mealPlanEntries: [MealieMealPlanEntry] = [],
        userRatings: [String: MealieUserRatingSummary] = [:],
        shoppingLists: [MealieShoppingListDetail] = [],
        validUsername: String,
        validPassword: String,
        mintedToken: MealieAuthToken
    ) {
        self.serverInfo = serverInfo
        self.user = user
        self.recipes = recipes
        self.mealPlanEntries = mealPlanEntries
        self.userRatings = userRatings
        self.shoppingLists = shoppingLists
        self.validUsername = validUsername
        self.validPassword = validPassword
        self.mintedToken = mintedToken
    }

    static func preloaded() -> MockMealieAPIClient {
        MockMealieAPIClient(
            serverInfo: MealieServerInfo(
                production: false,
                version: "v2.5.0-mock",
                demoStatus: false,
                allowSignup: false,
                defaultGroupSlug: "home",
                defaultHouseholdSlug: "family"
            ),
            user: MealieUser(
                id: "00000000-0000-0000-0000-000000000001",
                username: "chef",
                email: "chef@example.com",
                fullName: "Mock Chef",
                admin: true,
                groupId: "00000000-0000-0000-0000-0000000000aa",
                householdId: "00000000-0000-0000-0000-0000000000bb"
            ),
            recipes: [
                MealieRecipeSummary(
                    recipeID: "00000000-0000-0000-0000-000000000101",
                    slug: "miso-ginger-salmon",
                    name: "Miso Ginger Salmon",
                    description: "A quick weeknight dinner with rice and greens.",
                    recipeYield: "4 servings"
                ),
                MealieRecipeSummary(
                    recipeID: "00000000-0000-0000-0000-000000000102",
                    slug: "crispy-katsu-curry",
                    name: "Crispy Katsu Curry",
                    description: "Golden cutlets with a rich Japanese curry sauce.",
                    recipeYield: "3 servings"
                ),
                MealieRecipeSummary(
                    recipeID: "00000000-0000-0000-0000-000000000103",
                    slug: "sesame-cucumber-salad",
                    name: "Sesame Cucumber Salad",
                    description: "Cool, crunchy cucumbers dressed with sesame and rice vinegar.",
                    recipeYield: "2 servings"
                ),
                MealieRecipeSummary(
                    recipeID: "00000000-0000-0000-0000-000000000104",
                    slug: "garlic-noodles",
                    name: "Garlic Noodles",
                    description: "Buttery noodles with garlic, soy, and scallions.",
                    recipeYield: "4 servings"
                ),
                MealieRecipeSummary(
                    recipeID: "00000000-0000-0000-0000-000000000105",
                    slug: "matcha-pancakes",
                    name: "Matcha Pancakes",
                    description: "Fluffy breakfast pancakes with a gentle green tea flavor.",
                    recipeYield: "8 pancakes"
                ),
                MealieRecipeSummary(
                    recipeID: "00000000-0000-0000-0000-000000000106",
                    slug: "tahini-roasted-carrots",
                    name: "Tahini Roasted Carrots",
                    description: "Sweet roasted carrots finished with lemony tahini.",
                    recipeYield: "4 servings"
                ),
                MealieRecipeSummary(
                    recipeID: "00000000-0000-0000-0000-000000000107",
                    slug: "chicken-rice-soup",
                    name: "Chicken Rice Soup",
                    description: "Comforting soup for busy evenings or chilly weekends.",
                    recipeYield: "6 bowls"
                ),
                MealieRecipeSummary(
                    recipeID: "00000000-0000-0000-0000-000000000108",
                    slug: "berry-yogurt-parfaits",
                    name: "Berry Yogurt Parfaits",
                    description: "Layered yogurt, berries, and granola for quick breakfasts.",
                    recipeYield: "4 jars"
                )
            ],
            mealPlanEntries: Self.sampleMealPlanEntries(),
            userRatings: [
                "00000000-0000-0000-0000-000000000101": MealieUserRatingSummary(
                    recipeID: "00000000-0000-0000-0000-000000000101",
                    rating: 4,
                    isFavorite: true
                ),
                "00000000-0000-0000-0000-000000000102": MealieUserRatingSummary(
                    recipeID: "00000000-0000-0000-0000-000000000102",
                    rating: 5,
                    isFavorite: false
                )
            ],
            shoppingLists: Self.sampleShoppingLists(),
            validUsername: "chef",
            validPassword: "katsu",
            mintedToken: MealieAuthToken(
                accessToken: "mock-access-token",
                tokenType: "bearer"
            )
        )
    }

    func fetchServerInfo(serverURL: URL) async throws -> MealieServerInfo {
        try await Task.sleep(nanoseconds: 150_000_000)
        return serverInfo
    }

    func login(serverURL: URL, username: String, password: String) async throws -> MealieAuthToken {
        try await Task.sleep(nanoseconds: 250_000_000)
        guard username == validUsername, password == validPassword else {
            throw AppError.unauthorized
        }
        return mintedToken
    }

    func fetchCurrentUser(serverURL: URL, token: MealieAuthToken) async throws -> MealieUser {
        try await Task.sleep(nanoseconds: 150_000_000)
        guard token.accessToken == mintedToken.accessToken else {
            throw AppError.unauthorized
        }
        return user
    }

    func fetchRecipes(serverURL: URL, token: MealieAuthToken, page: Int, perPage: Int, filters: MealieRecipeFilters) async throws -> MealieRecipePage {
        try await Task.sleep(nanoseconds: 200_000_000)
        guard token.accessToken == mintedToken.accessToken else {
            throw AppError.unauthorized
        }

        let filteredRecipes = filtered(recipes: recipes, filters: filters)
        let safePage = max(page, 1)
        let safePerPage = max(perPage, 1)
        let start = min((safePage - 1) * safePerPage, filteredRecipes.count)
        let end = min(start + safePerPage, filteredRecipes.count)
        let totalPages = Int(ceil(Double(filteredRecipes.count) / Double(safePerPage)))

        return MealieRecipePage(
            items: Array(filteredRecipes[start..<end]),
            page: safePage,
            perPage: safePerPage,
            total: filteredRecipes.count,
            totalPages: totalPages
        )
    }

    func fetchMealPlanEntries(serverURL: URL, token: MealieAuthToken, startDate: String, endDate: String) async throws -> MealieMealPlanPage {
        try await Task.sleep(nanoseconds: 180_000_000)
        guard token.accessToken == mintedToken.accessToken else {
            throw AppError.unauthorized
        }

        let entries = mealPlanEntries
            .filter { $0.date >= startDate && $0.date <= endDate }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date {
                    return lhs.entryType.rawValue < rhs.entryType.rawValue
                }
                return lhs.date < rhs.date
            }
        return MealieMealPlanPage(
            items: entries,
            page: 1,
            perPage: 50,
            total: entries.count,
            totalPages: 1
        )
    }

    func createMealPlanEntry(serverURL: URL, token: MealieAuthToken, entry: MealieMealPlanEntryCreate) async throws -> MealieMealPlanEntry {
        try await Task.sleep(nanoseconds: 160_000_000)
        guard token.accessToken == mintedToken.accessToken else {
            throw AppError.unauthorized
        }

        let created = MealieMealPlanEntry(
            id: (mealPlanEntries.map(\.id).max() ?? 0) + 1,
            date: entry.date,
            entryType: entry.entryType,
            title: entry.title,
            text: entry.text,
            recipeID: entry.recipeID,
            groupID: user.groupId,
            userID: user.id,
            householdID: user.householdId,
            recipe: recipeSummary(for: entry.recipeID)
        )
        mealPlanEntries.append(created)
        return created
    }

    func createRandomMealPlanEntry(serverURL: URL, token: MealieAuthToken, entry: MealieMealPlanRandomCreate) async throws -> MealieMealPlanEntry {
        try await Task.sleep(nanoseconds: 160_000_000)
        guard token.accessToken == mintedToken.accessToken else {
            throw AppError.unauthorized
        }
        guard let recipe = recipes.randomElement(), let recipeID = recipe.recipeID else {
            throw AppError.server(status: 404)
        }

        let created = MealieMealPlanEntry(
            id: (mealPlanEntries.map(\.id).max() ?? 0) + 1,
            date: entry.date,
            entryType: entry.entryType,
            title: nil,
            text: nil,
            recipeID: recipeID,
            groupID: user.groupId,
            userID: user.id,
            householdID: user.householdId,
            recipe: recipe
        )
        mealPlanEntries.append(created)
        return created
    }

    func updateMealPlanEntry(serverURL: URL, token: MealieAuthToken, entryID: Int, entry: MealieMealPlanEntryUpdate) async throws -> MealieMealPlanEntry {
        try await Task.sleep(nanoseconds: 160_000_000)
        guard token.accessToken == mintedToken.accessToken else {
            throw AppError.unauthorized
        }
        guard let index = mealPlanEntries.firstIndex(where: { $0.id == entryID }) else {
            throw AppError.server(status: 404)
        }

        let updated = MealieMealPlanEntry(
            id: entry.id,
            date: entry.date,
            entryType: entry.entryType,
            title: entry.title,
            text: entry.text,
            recipeID: entry.recipeID,
            groupID: entry.groupID,
            userID: entry.userID,
            householdID: mealPlanEntries[index].householdID,
            recipe: recipeSummary(for: entry.recipeID)
        )
        mealPlanEntries[index] = updated
        return updated
    }

    func deleteMealPlanEntry(serverURL: URL, token: MealieAuthToken, entryID: Int) async throws -> MealieMealPlanEntry {
        try await Task.sleep(nanoseconds: 160_000_000)
        guard token.accessToken == mintedToken.accessToken else {
            throw AppError.unauthorized
        }
        guard let index = mealPlanEntries.firstIndex(where: { $0.id == entryID }) else {
            throw AppError.server(status: 404)
        }
        return mealPlanEntries.remove(at: index)
    }

    private func filtered(recipes: [MealieRecipeSummary], filters: MealieRecipeFilters) -> [MealieRecipeSummary] {
        let search = filters.search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return recipes.filter { recipe in
            let detail = detail(for: recipe)
            let searchableText = [recipe.displayName, recipe.description, recipe.slug]
                .compactMap { $0?.lowercased() }
                .joined(separator: " ")
            let matchesSearch = search.isEmpty || searchableText.contains(search)
            let categorySlugs = Set((detail.recipeCategory ?? []).map(\.slug))
            let tagSlugs = Set((detail.tags ?? []).map(\.slug))
            let matchesCategories = filters.categories.isEmpty || !categorySlugs.isDisjoint(with: filters.categories)
            let matchesTags = filters.tags.isEmpty || !tagSlugs.isDisjoint(with: filters.tags)
            let matchesHouseholds = filters.households.isEmpty || filters.households.contains(user.householdId ?? "")
            return matchesSearch && matchesCategories && matchesTags && matchesHouseholds
        }
    }

    func fetchRecipeDetail(serverURL: URL, token: MealieAuthToken, slug: String) async throws -> MealieRecipeDetail {
        try await Task.sleep(nanoseconds: 180_000_000)
        guard token.accessToken == mintedToken.accessToken else {
            throw AppError.unauthorized
        }
        guard let summary = recipes.first(where: { $0.slug == slug || $0.id == slug }) else {
            throw AppError.server(status: 404)
        }
        return detail(for: summary)
    }

    func importRecipeFromURL(serverURL: URL, token: MealieAuthToken, url: URL, includeTags: Bool, includeCategories: Bool) async throws -> String {
        try await Task.sleep(nanoseconds: 300_000_000)
        guard token.accessToken == mintedToken.accessToken else {
            throw AppError.unauthorized
        }

        let source = url.host ?? url.deletingPathExtension().lastPathComponent
        let baseSlug = slugify(url.deletingPathExtension().lastPathComponent.isEmpty ? source : url.deletingPathExtension().lastPathComponent)
        let slug = uniqueSlug(baseSlug.isEmpty ? "imported-recipe" : baseSlug)
        let recipe = MealieRecipeSummary(
            recipeID: UUID().uuidString.lowercased(),
            slug: slug,
            name: title(from: slug),
            description: "Imported from \(source).",
            recipeYield: "Imported recipe"
        )
        recipes.insert(recipe, at: 0)
        return slug
    }

    func fetchUserRating(serverURL: URL, token: MealieAuthToken, recipeID: String) async throws -> MealieUserRatingSummary {
        try await Task.sleep(nanoseconds: 120_000_000)
        guard token.accessToken == mintedToken.accessToken else {
            throw AppError.unauthorized
        }
        return userRatings[recipeID] ?? MealieUserRatingSummary(recipeID: recipeID, rating: nil, isFavorite: false)
    }

    func updateUserRating(serverURL: URL, token: MealieAuthToken, userID: String, slug: String, rating: Double?, isFavorite: Bool?) async throws {
        try await Task.sleep(nanoseconds: 160_000_000)
        guard token.accessToken == mintedToken.accessToken else {
            throw AppError.unauthorized
        }
        guard userID == user.id,
              let recipe = recipes.first(where: { $0.slug == slug || $0.id == slug }),
              let recipeID = recipe.recipeID else {
            throw AppError.server(status: 404)
        }
        let current = userRatings[recipeID] ?? MealieUserRatingSummary(recipeID: recipeID, rating: nil, isFavorite: false)
        userRatings[recipeID] = MealieUserRatingSummary(
            recipeID: recipeID,
            rating: rating ?? current.rating,
            isFavorite: isFavorite ?? current.isFavorite
        )
    }

    func fetchShoppingLists(serverURL: URL, token: MealieAuthToken, page: Int, perPage: Int) async throws -> MealieShoppingListPage {
        try await Task.sleep(nanoseconds: 180_000_000)
        guard token.accessToken == mintedToken.accessToken else {
            throw AppError.unauthorized
        }

        let safePage = max(page, 1)
        let safePerPage = max(perPage, 1)
        let start = min((safePage - 1) * safePerPage, shoppingLists.count)
        let end = min(start + safePerPage, shoppingLists.count)
        let totalPages = Int(ceil(Double(shoppingLists.count) / Double(safePerPage)))

        return MealieShoppingListPage(
            items: shoppingLists[start..<end].map(\.summary),
            page: safePage,
            perPage: safePerPage,
            total: shoppingLists.count,
            totalPages: totalPages
        )
    }

    func fetchShoppingListDetail(serverURL: URL, token: MealieAuthToken, listID: String) async throws -> MealieShoppingListDetail {
        try await Task.sleep(nanoseconds: 160_000_000)
        guard token.accessToken == mintedToken.accessToken else {
            throw AppError.unauthorized
        }
        guard let list = shoppingLists.first(where: { $0.id == listID }) else {
            throw AppError.server(status: 404)
        }
        return list
    }

    private func detail(for summary: MealieRecipeSummary) -> MealieRecipeDetail {
        switch summary.slug {
        case "miso-ginger-salmon":
            return recipeDetail(
                summary,
                servings: 4,
                totalTime: "PT30M",
                prepTime: "PT10M",
                cookTime: "PT20M",
                categories: [token("Dinner", "dinner")],
                tags: [token("Weeknight", "weeknight"), token("Seafood", "seafood")],
                rating: 4.5,
                ingredients: [
                    ingredient("4 salmon fillets"),
                    ingredient("2 tbsp white miso"),
                    ingredient("1 tbsp grated ginger"),
                    ingredient("2 cups cooked rice"),
                    ingredient("Steamed greens, to serve")
                ],
                instructions: [
                    instruction("Whisk miso, ginger, and a splash of water into a glaze."),
                    instruction("Brush the salmon and roast until just cooked through."),
                    instruction("Serve over rice with greens.")
                ],
                nutrition: nutrition(calories: "420", protein: "35 g", carbohydrate: "38 g", fat: "16 g")
            )
        case "crispy-katsu-curry":
            return recipeDetail(
                summary,
                servings: 3,
                totalTime: "PT55M",
                prepTime: "PT20M",
                cookTime: "PT35M",
                categories: [token("Dinner", "dinner")],
                tags: [token("Japanese", "japanese"), token("Comfort food", "comfort-food")],
                rating: 5,
                ingredients: [
                    ingredient("3 chicken cutlets"),
                    ingredient("1 cup panko breadcrumbs"),
                    ingredient("Japanese curry sauce"),
                    ingredient("Cooked short-grain rice")
                ],
                instructions: [
                    instruction("Bread the cutlets with flour, egg, and panko."),
                    instruction("Fry until deeply golden and crisp."),
                    instruction("Slice and plate with rice and curry sauce.")
                ],
                nutrition: nutrition(calories: "680", protein: "42 g", carbohydrate: "74 g", fat: "24 g")
            )
        default:
            return recipeDetail(
                summary,
                servings: nil,
                totalTime: nil,
                prepTime: nil,
                cookTime: nil,
                categories: [token("Favorites", "favorites")],
                tags: [token("Mock", "mock")],
                rating: nil,
                ingredients: [
                    ingredient("Main ingredient"),
                    ingredient("Seasoning to taste"),
                    ingredient("Fresh garnish")
                ],
                instructions: [
                    instruction("Prepare the ingredients."),
                    instruction("Cook until ready and serve warm.")
                ],
                nutrition: nil
            )
        }
    }

    private static func sampleMealPlanEntries() -> [MealieMealPlanEntry] {
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now

        func date(_ offset: Int) -> String {
            mealPlanDateFormatter.string(from: calendar.date(byAdding: .day, value: offset, to: weekStart) ?? weekStart)
        }

        return [
            mealPlanEntry(id: 1, date: date(0), entryType: .dinner, title: nil, recipeID: "00000000-0000-0000-0000-000000000101", recipeSlug: "miso-ginger-salmon", recipeName: "Miso Ginger Salmon"),
            mealPlanEntry(id: 2, date: date(2), entryType: .lunch, title: "Leftover katsu bowls", recipeID: nil, recipeSlug: nil, recipeName: nil),
            mealPlanEntry(id: 3, date: date(4), entryType: .dinner, title: nil, recipeID: "00000000-0000-0000-0000-000000000102", recipeSlug: "crispy-katsu-curry", recipeName: "Crispy Katsu Curry"),
            mealPlanEntry(id: 4, date: date(6), entryType: .breakfast, title: nil, recipeID: "00000000-0000-0000-0000-000000000108", recipeSlug: "berry-yogurt-parfaits", recipeName: "Berry Yogurt Parfaits")
        ]
    }

    private static func mealPlanEntry(id: Int, date: String, entryType: MealieMealPlanEntryType, title: String?, recipeID: String?, recipeSlug: String?, recipeName: String?) -> MealieMealPlanEntry {
        MealieMealPlanEntry(
            id: id,
            date: date,
            entryType: entryType,
            title: title,
            text: nil,
            recipeID: recipeID,
            groupID: "00000000-0000-0000-0000-0000000000aa",
            userID: "00000000-0000-0000-0000-000000000001",
            householdID: "00000000-0000-0000-0000-0000000000bb",
            recipe: recipeID.flatMap { id in
                MealieRecipeSummary(
                    recipeID: id,
                    slug: recipeSlug ?? id,
                    name: recipeName,
                    description: nil,
                    recipeYield: nil
                )
            }
        )
    }

    private func recipeSummary(for recipeID: String?) -> MealieRecipeSummary? {
        guard let recipeID else { return nil }
        return recipes.first { $0.id == recipeID || $0.recipeID == recipeID }
    }

    private static func sampleShoppingLists() -> [MealieShoppingListDetail] {
        [
            MealieShoppingListDetail(
                id: "00000000-0000-0000-0000-000000000501",
                name: "Weekly Groceries",
                createdAt: nil,
                updatedAt: nil,
                listItems: [
                    shoppingItem(
                        id: "00000000-0000-0000-0000-000000000601",
                        listID: "00000000-0000-0000-0000-000000000501",
                        display: "Salmon fillets",
                        note: "Dinner for Tuesday",
                        quantity: 4,
                        unit: nil,
                        checked: false,
                        position: 0
                    ),
                    shoppingItem(
                        id: "00000000-0000-0000-0000-000000000602",
                        listID: "00000000-0000-0000-0000-000000000501",
                        display: "Short-grain rice",
                        note: nil,
                        quantity: 2,
                        unit: MealieShoppingIngredientUnit(id: "cup", name: "cup", abbreviation: "cup"),
                        checked: false,
                        position: 1
                    ),
                    shoppingItem(
                        id: "00000000-0000-0000-0000-000000000603",
                        listID: "00000000-0000-0000-0000-000000000501",
                        display: "Panko breadcrumbs",
                        note: nil,
                        quantity: 1,
                        unit: nil,
                        checked: true,
                        position: 2
                    )
                ],
                recipeReferences: [
                    MealieShoppingRecipeReference(
                        id: "00000000-0000-0000-0000-000000000701",
                        shoppingListID: "00000000-0000-0000-0000-000000000501",
                        recipeID: "00000000-0000-0000-0000-000000000101",
                        recipeQuantity: 1
                    )
                ]
            ),
            MealieShoppingListDetail(
                id: "00000000-0000-0000-0000-000000000502",
                name: "Pantry Restock",
                createdAt: nil,
                updatedAt: nil,
                listItems: [
                    shoppingItem(
                        id: "00000000-0000-0000-0000-000000000604",
                        listID: "00000000-0000-0000-0000-000000000502",
                        display: "White miso",
                        note: "Check fridge first",
                        quantity: 1,
                        unit: nil,
                        checked: false,
                        position: 0
                    ),
                    shoppingItem(
                        id: "00000000-0000-0000-0000-000000000605",
                        listID: "00000000-0000-0000-0000-000000000502",
                        display: "Soy sauce",
                        note: nil,
                        quantity: 1,
                        unit: nil,
                        checked: false,
                        position: 1
                    )
                ],
                recipeReferences: []
            )
        ]
    }

    private static func shoppingItem(
        id: String,
        listID: String,
        display: String,
        note: String?,
        quantity: Double,
        unit: MealieShoppingIngredientUnit?,
        checked: Bool,
        position: Int
    ) -> MealieShoppingListItem {
        MealieShoppingListItem(
            id: id,
            shoppingListID: listID,
            display: display,
            note: note,
            checked: checked,
            position: position,
            quantity: quantity,
            unit: unit,
            food: nil,
            label: nil,
            recipeReferences: [],
            createdAt: nil,
            updatedAt: nil
        )
    }

    private func recipeDetail(
        _ summary: MealieRecipeSummary,
        servings: Double?,
        totalTime: String?,
        prepTime: String?,
        cookTime: String?,
        categories: [MealieRecipeToken],
        tags: [MealieRecipeToken],
        rating: Double?,
        ingredients: [MealieRecipeIngredient],
        instructions: [MealieRecipeInstruction],
        nutrition: MealieRecipeNutrition?
    ) -> MealieRecipeDetail {
        MealieRecipeDetail(
            recipeID: summary.recipeID,
            slug: summary.slug,
            name: summary.name,
            description: summary.description,
            recipeYield: summary.recipeYield,
            recipeServings: servings,
            totalTime: totalTime,
            prepTime: prepTime,
            cookTime: cookTime,
            recipeCategory: categories,
            tags: tags,
            rating: rating,
            image: nil,
            recipeIngredient: ingredients,
            recipeInstructions: instructions,
            nutrition: nutrition,
            settings: MealieRecipeSettings(showNutrition: true)
        )
    }

    private func token(_ name: String, _ slug: String) -> MealieRecipeToken {
        MealieRecipeToken(tokenID: slug, name: name, slug: slug)
    }

    private func ingredient(_ display: String) -> MealieRecipeIngredient {
        MealieRecipeIngredient(
            referenceID: display,
            display: display,
            title: nil,
            note: nil,
            quantity: nil,
            unit: nil,
            food: nil
        )
    }

    private func instruction(_ text: String) -> MealieRecipeInstruction {
        MealieRecipeInstruction(stepID: text, title: nil, summary: nil, text: text)
    }

    private func nutrition(calories: String, protein: String, carbohydrate: String, fat: String) -> MealieRecipeNutrition {
        MealieRecipeNutrition(
            calories: calories,
            carbohydrateContent: carbohydrate,
            cholesterolContent: nil,
            fatContent: fat,
            fiberContent: nil,
            proteinContent: protein,
            saturatedFatContent: nil,
            sodiumContent: nil,
            sugarContent: nil,
            transFatContent: nil,
            unsaturatedFatContent: nil
        )
    }

    private func slugify(_ value: String) -> String {
        value
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: "-")
    }

    private func uniqueSlug(_ base: String) -> String {
        var candidate = base
        var index = 2
        let existing = Set(recipes.map(\.slug))
        while existing.contains(candidate) {
            candidate = "\(base)-\(index)"
            index += 1
        }
        return candidate
    }

    private func title(from slug: String) -> String {
        slug
            .split(separator: "-")
            .map { word in
                word.prefix(1).uppercased() + word.dropFirst()
            }
            .joined(separator: " ")
    }
}
