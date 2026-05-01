import Foundation

/// Abstract Mealie API surface. Implementations: real `URLSession` and
/// in-memory mock for offline development.
protocol MealieAPIClient: AnyObject, Sendable {
    func fetchServerInfo(serverURL: URL) async throws -> MealieServerInfo
    func login(serverURL: URL, username: String, password: String) async throws -> MealieAuthToken
    func fetchCurrentUser(serverURL: URL, token: MealieAuthToken) async throws -> MealieUser
    func fetchRecipes(serverURL: URL, token: MealieAuthToken, page: Int, perPage: Int) async throws -> MealieRecipePage
    func fetchRecipeDetail(serverURL: URL, token: MealieAuthToken, slug: String) async throws -> MealieRecipeDetail
}
