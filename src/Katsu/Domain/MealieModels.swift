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
