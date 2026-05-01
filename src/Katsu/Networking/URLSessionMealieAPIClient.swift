import Foundation

final class URLSessionMealieAPIClient: MealieAPIClient, @unchecked Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        // Mealie's REST endpoints return camelCase (e.g. /api/app/about,
        // /api/users/self) while OAuth-style endpoints return snake_case
        // (/api/auth/token: access_token, token_type). Using
        // `.convertFromSnakeCase` here would camelCase incoming JSON keys
        // before CodingKey lookup, which prevents `MealieAuthToken`'s explicit
        // `access_token`/`token_type` raw values from matching and causes the
        // login response to fail decoding. Rely on each model's explicit
        // CodingKeys instead.
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    func fetchServerInfo(serverURL: URL) async throws -> MealieServerInfo {
        let request = URLRequest(url: serverURL.appendingPathComponent("api/app/about"))
        return try await perform(request)
    }

    func login(serverURL: URL, username: String, password: String) async throws -> MealieAuthToken {
        var request = URLRequest(url: serverURL.appendingPathComponent("api/auth/token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let body = formEncode([
            "username": username,
            "password": password
        ])
        request.httpBody = body.data(using: .utf8)
        return try await perform(request)
    }

    func fetchCurrentUser(serverURL: URL, token: MealieAuthToken) async throws -> MealieUser {
        var request = URLRequest(url: serverURL.appendingPathComponent("api/users/self"))
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    func fetchRecipes(serverURL: URL, token: MealieAuthToken, page: Int, perPage: Int, filters: MealieRecipeFilters) async throws -> MealieRecipePage {
        var components = URLComponents(url: serverURL.appendingPathComponent("api/recipes"), resolvingAgainstBaseURL: false)
        var queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "perPage", value: String(perPage))
        ]
        let search = filters.search.trimmingCharacters(in: .whitespacesAndNewlines)
        if !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
        }
        queryItems.append(contentsOf: filters.categories.map { URLQueryItem(name: "categories", value: $0) })
        queryItems.append(contentsOf: filters.tags.map { URLQueryItem(name: "tags", value: $0) })
        queryItems.append(contentsOf: filters.households.map { URLQueryItem(name: "households", value: $0) })
        components?.queryItems = queryItems
        guard let url = components?.url else {
            throw AppError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    func fetchMealPlanEntries(serverURL: URL, token: MealieAuthToken, startDate: String, endDate: String) async throws -> MealieMealPlanPage {
        var components = URLComponents(url: serverURL.appendingPathComponent("api/households/mealplans"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "start_date", value: startDate),
            URLQueryItem(name: "end_date", value: endDate),
            URLQueryItem(name: "orderBy", value: "date"),
            URLQueryItem(name: "orderDirection", value: "asc"),
            URLQueryItem(name: "perPage", value: "50")
        ]
        guard let url = components?.url else {
            throw AppError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    func createMealPlanEntry(serverURL: URL, token: MealieAuthToken, entry: MealieMealPlanEntryCreate) async throws -> MealieMealPlanEntry {
        var request = URLRequest(url: serverURL.appendingPathComponent("api/households/mealplans"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(entry)
        return try await perform(request)
    }

    func createRandomMealPlanEntry(serverURL: URL, token: MealieAuthToken, entry: MealieMealPlanRandomCreate) async throws -> MealieMealPlanEntry {
        var request = URLRequest(url: serverURL.appendingPathComponent("api/households/mealplans/random"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(entry)
        return try await perform(request)
    }

    func updateMealPlanEntry(serverURL: URL, token: MealieAuthToken, entryID: Int, entry: MealieMealPlanEntryUpdate) async throws -> MealieMealPlanEntry {
        var request = URLRequest(url: serverURL.appendingPathComponent("api/households/mealplans/\(entryID)"))
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(entry)
        return try await perform(request)
    }

    func deleteMealPlanEntry(serverURL: URL, token: MealieAuthToken, entryID: Int) async throws -> MealieMealPlanEntry {
        var request = URLRequest(url: serverURL.appendingPathComponent("api/households/mealplans/\(entryID)"))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await perform(request)
    }

    func fetchRecipeDetail(serverURL: URL, token: MealieAuthToken, slug: String) async throws -> MealieRecipeDetail {
        let encodedSlug = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        var request = URLRequest(url: serverURL.appendingPathComponent("api/recipes/\(encodedSlug)"))
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    func importRecipeFromURL(serverURL: URL, token: MealieAuthToken, url: URL, includeTags: Bool, includeCategories: Bool) async throws -> String {
        var request = URLRequest(url: serverURL.appendingPathComponent("api/recipes/create/url"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(ImportRecipeRequest(
            url: url.absoluteString,
            includeTags: includeTags,
            includeCategories: includeCategories
        ))
        return try await perform(request)
    }

    func fetchUserRating(serverURL: URL, token: MealieAuthToken, recipeID: String) async throws -> MealieUserRatingSummary {
        let encodedID = recipeID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? recipeID
        var request = URLRequest(url: serverURL.appendingPathComponent("api/users/self/ratings/\(encodedID)"))
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    func updateUserRating(serverURL: URL, token: MealieAuthToken, userID: String, slug: String, rating: Double?, isFavorite: Bool?) async throws {
        let encodedUserID = userID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? userID
        let encodedSlug = slug.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? slug
        var request = URLRequest(url: serverURL.appendingPathComponent("api/users/\(encodedUserID)/ratings/\(encodedSlug)"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(UserRatingUpdate(rating: rating, isFavorite: isFavorite))
        let _: EmptyResponse = try await perform(request)
    }

    func fetchShoppingLists(serverURL: URL, token: MealieAuthToken, page: Int, perPage: Int) async throws -> MealieShoppingListPage {
        var components = URLComponents(url: serverURL.appendingPathComponent("api/households/shopping/lists"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "perPage", value: String(perPage))
        ]
        guard let url = components?.url else {
            throw AppError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    func fetchShoppingListDetail(serverURL: URL, token: MealieAuthToken, listID: String) async throws -> MealieShoppingListDetail {
        let encodedID = listID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? listID
        var request = URLRequest(url: serverURL.appendingPathComponent("api/households/shopping/lists/\(encodedID)"))
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    func updateShoppingListItem(serverURL: URL, token: MealieAuthToken, itemID: String, item: MealieShoppingListItemUpdate) async throws -> MealieShoppingListItemsCollection {
        let encodedID = itemID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? itemID
        var request = URLRequest(url: serverURL.appendingPathComponent("api/households/shopping/items/\(encodedID)"))
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(item)
        return try await perform(request)
    }

    // MARK: - Helpers

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw map(urlError: urlError)
        } catch {
            throw AppError.unknown(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AppError.invalidServerResponse
        }

        switch http.statusCode {
        case 200..<300:
            do {
                if T.self == EmptyResponse.self, data.isEmpty {
                    return EmptyResponse() as! T
                }
                return try decoder.decode(T.self, from: data)
            } catch {
                throw AppError.invalidServerResponse
            }
        case 401:
            throw AppError.unauthorized
        case 403:
            throw AppError.forbidden
        case 429:
            throw AppError.rateLimited
        default:
            throw AppError.server(status: http.statusCode)
        }
    }

    private func map(urlError: URLError) -> AppError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
             .cannotFindHost, .timedOut, .dnsLookupFailed:
            return .offline
        case .secureConnectionFailed, .serverCertificateUntrusted,
             .serverCertificateHasBadDate, .serverCertificateNotYetValid,
             .serverCertificateHasUnknownRoot, .clientCertificateRejected,
             .clientCertificateRequired:
            return .tlsTrust
        case .badURL, .unsupportedURL:
            return .invalidURL
        default:
            return .unknown(urlError.localizedDescription)
        }
    }

    private func formEncode(_ pairs: [String: String]) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return pairs
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
    }

    private struct ImportRecipeRequest: Encodable {
        let url: String
        let includeTags: Bool
        let includeCategories: Bool
    }

    private struct UserRatingUpdate: Encodable {
        let rating: Double?
        let isFavorite: Bool?
    }

    private struct EmptyResponse: Decodable {}
}
