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
