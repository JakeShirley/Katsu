import Foundation
import SwiftUI

/// Top-level dependency container for Katsu. Views observe this object and
/// reach for collaborators (API client, stores) through it rather than
/// constructing them directly.
@MainActor
final class AppEnvironment: ObservableObject {
    let configuration: AppConfiguration
    let apiClient: MealieAPIClient
    let credentialStore: CredentialStore
    let profileStore: ServerProfileStore
    let preferenceStore: AppPreferenceStore

    @Published var activeProfile: ServerProfile?
    @Published var currentUser: MealieUser?
    @Published var hasServerProfiles: Bool

    init(
        configuration: AppConfiguration,
        apiClient: MealieAPIClient,
        credentialStore: CredentialStore,
        profileStore: ServerProfileStore,
        preferenceStore: AppPreferenceStore
    ) {
        self.configuration = configuration
        self.apiClient = apiClient
        self.credentialStore = credentialStore
        self.profileStore = profileStore
        self.preferenceStore = preferenceStore
        let storedProfiles = profileStore.allProfiles()
        self.activeProfile = profileStore.activeProfile() ?? storedProfiles.first
        self.hasServerProfiles = !storedProfiles.isEmpty
        if let activeProfile = self.activeProfile {
            profileStore.setActiveProfileID(activeProfile.id)
        }

        if configuration.useMockServer,
           let token = configuration.debugAuthToken,
           self.activeProfile == nil {
            let profile = ServerProfile(
                displayName: configuration.initialServerURL?.host ?? "Mock Mealie",
                serverURL: configuration.initialServerURL ?? URL(string: "https://mock.mealie.local")!,
                version: "v2.5.0-mock",
                lastUsername: "chef"
            )
            try? credentialStore.saveToken(MealieAuthToken(accessToken: token, tokenType: "bearer"), for: profile.id)
            profileStore.upsert(profile)
            profileStore.setActiveProfileID(profile.id)
            self.activeProfile = profile
            self.hasServerProfiles = true
        }
    }

    static func live(configuration: AppConfiguration) -> AppEnvironment {
        let apiClient: MealieAPIClient = configuration.useMockServer
            ? MockMealieAPIClient.preloaded()
            : URLSessionMealieAPIClient()

        return AppEnvironment(
            configuration: configuration,
            apiClient: apiClient,
            credentialStore: KeychainCredentialStore(),
            profileStore: UserDefaultsServerProfileStore(),
            preferenceStore: UserDefaultsAppPreferenceStore()
        )
    }

    /// Persist a freshly authenticated profile + token, and refresh
    /// `activeProfile` / `currentUser` on the main thread.
    func adoptAuthenticatedSession(
        profile: ServerProfile,
        token: MealieAuthToken,
        user: MealieUser
    ) {
        try? credentialStore.saveToken(token, for: profile.id)
        profileStore.upsert(profile)
        profileStore.setActiveProfileID(profile.id)
        activeProfile = profile
        currentUser = user
        hasServerProfiles = true
    }

    func switchToProfile(_ profile: ServerProfile) {
        profileStore.setActiveProfileID(profile.id)
        activeProfile = profile
        currentUser = nil
        hasServerProfiles = !profileStore.allProfiles().isEmpty
    }

    func signOut() {
        let signedOutID = activeProfile?.id ?? profileStore.activeProfileID()
        if let id = signedOutID {
            try? credentialStore.deleteToken(for: id)
            profileStore.remove(id: id)
        }
        activeProfile = profileStore.activeProfile()
        currentUser = nil
        hasServerProfiles = !profileStore.allProfiles().isEmpty
    }
}
