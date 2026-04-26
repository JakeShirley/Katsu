import Foundation

/// In-memory implementation used when `-debugUseMockServer` is set. Backed
/// by hard-coded fixtures so the app runs entirely offline for previews,
/// snapshots, and demos.
final class MockMealieAPIClient: MealieAPIClient, @unchecked Sendable {
    private let serverInfo: MealieServerInfo
    private let user: MealieUser
    private let validUsername: String
    private let validPassword: String
    private let mintedToken: MealieAuthToken

    init(
        serverInfo: MealieServerInfo,
        user: MealieUser,
        validUsername: String,
        validPassword: String,
        mintedToken: MealieAuthToken
    ) {
        self.serverInfo = serverInfo
        self.user = user
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
}
