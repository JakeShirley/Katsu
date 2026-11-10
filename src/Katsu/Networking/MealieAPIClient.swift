import Foundation

/// Abstract Mealie API surface. Implementations: real `URLSession` and
/// in-memory mock for offline development.
protocol MealieAPIClient: AnyObject, Sendable {
    func fetchServerInfo(serverURL: URL) async throws -> MealieServerInfo
    func login(serverURL: URL, username: String, password: String) async throws -> MealieAuthToken
    func fetchCurrentUser(serverURL: URL, token: MealieAuthToken) async throws -> MealieUser
    func fetchRecipes(serverURL: URL, token: MealieAuthToken, page: Int, perPage: Int, filters: MealieRecipeFilters) async throws -> MealieRecipePage
    func fetchMealPlanEntries(serverURL: URL, token: MealieAuthToken, startDate: String, endDate: String) async throws -> MealieMealPlanPage
    func createMealPlanEntry(serverURL: URL, token: MealieAuthToken, entry: MealieMealPlanEntryCreate) async throws -> MealieMealPlanEntry
    func createRandomMealPlanEntry(serverURL: URL, token: MealieAuthToken, entry: MealieMealPlanRandomCreate) async throws -> MealieMealPlanEntry
    func updateMealPlanEntry(serverURL: URL, token: MealieAuthToken, entryID: Int, entry: MealieMealPlanEntryUpdate) async throws -> MealieMealPlanEntry
    func deleteMealPlanEntry(serverURL: URL, token: MealieAuthToken, entryID: Int) async throws -> MealieMealPlanEntry
    func fetchRecipeDetail(serverURL: URL, token: MealieAuthToken, slug: String) async throws -> MealieRecipeDetail
    func fetchRecipeDetailData(serverURL: URL, token: MealieAuthToken, slug: String) async throws -> Data
    func fetchRecipeImageData(serverURL: URL, token: MealieAuthToken, recipeID: String, fileName: String) async throws -> Data
    func fetchRecipeAssetData(serverURL: URL, token: MealieAuthToken, recipeID: String, fileName: String) async throws -> Data
    func importRecipeFromURL(serverURL: URL, token: MealieAuthToken, url: URL, includeTags: Bool, includeCategories: Bool) async throws -> String
    func importRecipeFromJSON(serverURL: URL, token: MealieAuthToken, json: String) async throws -> String
    func uploadRecipeAsset(serverURL: URL, token: MealieAuthToken, slug: String, name: String, icon: String, fileExtension: String, data: Data) async throws
    func updateRecipeImage(serverURL: URL, token: MealieAuthToken, slug: String, fileExtension: String, data: Data) async throws
    func fetchUserRating(serverURL: URL, token: MealieAuthToken, recipeID: String) async throws -> MealieUserRatingSummary
    func fetchFavorites(serverURL: URL, token: MealieAuthToken) async throws -> [MealieUserRatingSummary]
    func updateUserRating(serverURL: URL, token: MealieAuthToken, userID: String, slug: String, rating: Double?, isFavorite: Bool?) async throws
    func fetchShoppingLists(serverURL: URL, token: MealieAuthToken, page: Int, perPage: Int) async throws -> MealieShoppingListPage
    func fetchShoppingListDetail(serverURL: URL, token: MealieAuthToken, listID: String) async throws -> MealieShoppingListDetail
    func createShoppingList(serverURL: URL, token: MealieAuthToken, list: MealieShoppingListCreate) async throws -> MealieShoppingListDetail
    func deleteShoppingList(serverURL: URL, token: MealieAuthToken, listID: String) async throws -> MealieShoppingListSummary
    func createShoppingListItem(serverURL: URL, token: MealieAuthToken, item: MealieShoppingListItemCreate) async throws -> MealieShoppingListItemsCollection
    func updateShoppingListItem(serverURL: URL, token: MealieAuthToken, itemID: String, item: MealieShoppingListItemUpdate) async throws -> MealieShoppingListItemsCollection
    func addRecipeToShoppingList(serverURL: URL, token: MealieAuthToken, listID: String, recipeID: String, add: MealieShoppingRecipeAdd) async throws -> MealieShoppingListDetail
}
