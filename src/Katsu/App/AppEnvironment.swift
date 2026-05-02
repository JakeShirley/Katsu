import Foundation
import Network
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
    let recipeOfflineCache: RecipeOfflineCache
    private let networkMonitor = NWPathMonitor()
    private let networkMonitorQueue = DispatchQueue(label: "org.odinseye.katsu.network-monitor")

    @Published var activeProfile: ServerProfile?
    @Published var currentUser: MealieUser?
    @Published var hasServerProfiles: Bool
    @Published var recipeCacheSnapshot: RecipeOfflineCacheSnapshot = .empty
    @Published var isSyncingOfflineRecipes = false
    @Published var networkReachabilityTrigger = 0
    private var isNetworkReachable = false

    init(
        configuration: AppConfiguration,
        apiClient: MealieAPIClient,
        credentialStore: CredentialStore,
        profileStore: ServerProfileStore,
        preferenceStore: AppPreferenceStore,
        recipeOfflineCache: RecipeOfflineCache
    ) {
        self.configuration = configuration
        self.apiClient = apiClient
        self.credentialStore = credentialStore
        self.profileStore = profileStore
        self.preferenceStore = preferenceStore
        self.recipeOfflineCache = recipeOfflineCache
        let storedProfiles = profileStore.allProfiles()
        self.activeProfile = profileStore.activeProfile() ?? storedProfiles.first
        self.hasServerProfiles = !storedProfiles.isEmpty
        if let activeProfile = self.activeProfile {
            profileStore.setActiveProfileID(activeProfile.id)
            recipeCacheSnapshot = recipeOfflineCache.snapshot(profileID: activeProfile.id)
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
            recipeCacheSnapshot = recipeOfflineCache.snapshot(profileID: profile.id)
        }

        startNetworkMonitor()
    }

    deinit {
        networkMonitor.cancel()
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
            preferenceStore: UserDefaultsAppPreferenceStore(),
            recipeOfflineCache: FileRecipeOfflineCache()
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
        refreshRecipeCacheSnapshot()
    }

    func switchToProfile(_ profile: ServerProfile) {
        profileStore.setActiveProfileID(profile.id)
        activeProfile = profile
        currentUser = nil
        hasServerProfiles = !profileStore.allProfiles().isEmpty
        refreshRecipeCacheSnapshot()
    }

    func signOut() {
        let signedOutID = activeProfile?.id ?? profileStore.activeProfileID()
        if let id = signedOutID {
            try? credentialStore.deleteToken(for: id)
            profileStore.remove(id: id)
            recipeOfflineCache.clear(profileID: id)
        }
        activeProfile = profileStore.activeProfile()
        currentUser = nil
        hasServerProfiles = !profileStore.allProfiles().isEmpty
        refreshRecipeCacheSnapshot()
    }

    func refreshRecipeCacheSnapshot() {
        guard let activeProfile else {
            recipeCacheSnapshot = .empty
            return
        }
        recipeCacheSnapshot = recipeOfflineCache.snapshot(profileID: activeProfile.id)
    }

    func clearOfflineRecipes() {
        guard let activeProfile else { return }
        recipeOfflineCache.clear(profileID: activeProfile.id)
        refreshRecipeCacheSnapshot()
    }

    func syncOfflineRecipesIfNeeded() async {
        let lastUpdated = recipeCacheSnapshot.lastUpdated ?? .distantPast
        guard Date().timeIntervalSince(lastUpdated) > 6 * 60 * 60 else { return }
        await syncOfflineRecipes(force: false)
    }

    func syncOfflineRecipes(force: Bool) async {
        guard !isSyncingOfflineRecipes,
              let profile = activeProfile,
              let token = try? credentialStore.loadToken(for: profile.id) else { return }
        isSyncingOfflineRecipes = true
        defer { isSyncingOfflineRecipes = false }

        var pageNumber = 1
        var totalPages = 1
        repeat {
            do {
                let page = try await apiClient.fetchRecipes(
                    serverURL: profile.serverURL,
                    token: token,
                    page: pageNumber,
                    perPage: 50,
                    filters: MealieRecipeFilters()
                )
                totalPages = page.totalPages ?? page.total.map { Int(ceil(Double($0) / Double(page.perPage))) } ?? pageNumber
                await cacheRecipesOffline(page.items, profile: profile, token: token, force: force)
                pageNumber += 1
            } catch {
                break
            }
        } while pageNumber <= totalPages

        refreshRecipeCacheSnapshot()
    }

    func cacheRecipesOffline(_ recipes: [MealieRecipeSummary], profile: ServerProfile, token: MealieAuthToken, force: Bool = false) async {
        for recipe in recipes {
            if !force, recipeOfflineCache.cachedRecipeDetail(profileID: profile.id, slug: recipe.slug) != nil {
                continue
            }
            await cacheRecipeOffline(recipe, profile: profile, token: token)
        }
        refreshRecipeCacheSnapshot()
    }

    func cacheRecipeOffline(_ recipe: MealieRecipeSummary, profile: ServerProfile, token: MealieAuthToken) async {
        do {
            let rawData = try await apiClient.fetchRecipeDetailData(serverURL: profile.serverURL, token: token, slug: recipe.slug)
            let detail = try JSONDecoder().decode(MealieRecipeDetail.self, from: rawData)
            recipeOfflineCache.cacheRecipeDetail(detail, rawData: rawData, profileID: profile.id)
            refreshRecipeCacheSnapshot()
            await cacheMedia(for: detail, profile: profile, token: token)
            refreshRecipeCacheSnapshot()
        } catch {
            return
        }
    }

    func cacheLoadedRecipeOffline(_ detail: MealieRecipeDetail, rawData: Data, profile: ServerProfile, token: MealieAuthToken) async {
        recipeOfflineCache.cacheRecipeDetail(detail, rawData: rawData, profileID: profile.id)
        await cacheMedia(for: detail, profile: profile, token: token)
        refreshRecipeCacheSnapshot()
    }

    private func cacheMedia(for detail: MealieRecipeDetail, profile: ServerProfile, token: MealieAuthToken) async {
        guard let recipeID = detail.recipeID else { return }
        if detail.image != nil {
            for fileName in ["min-original.webp", "original.webp", "tiny-original.webp"] {
                do {
                    let data = try await apiClient.fetchRecipeImageData(serverURL: profile.serverURL, token: token, recipeID: recipeID, fileName: fileName)
                    recipeOfflineCache.cacheMedia(data, profileID: profile.id, recipeID: recipeID, slug: detail.slug, fileName: fileName, kind: .image)
                } catch {
                    continue
                }
            }
        }

        for asset in detail.assets ?? [] {
            guard let fileName = asset.fileName, !fileName.isEmpty else { continue }
            do {
                let data = try await apiClient.fetchRecipeAssetData(serverURL: profile.serverURL, token: token, recipeID: recipeID, fileName: fileName)
                recipeOfflineCache.cacheMedia(data, profileID: profile.id, recipeID: recipeID, slug: detail.slug, fileName: fileName, kind: .asset)
            } catch {
                continue
            }
        }
    }

    private func startNetworkMonitor() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let reachable = path.status == .satisfied
                if reachable, !isNetworkReachable {
                    networkReachabilityTrigger += 1
                }
                isNetworkReachable = reachable
            }
        }
        networkMonitor.start(queue: networkMonitorQueue)
    }
}
