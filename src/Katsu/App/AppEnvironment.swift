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

    @Published var activeProfile: ServerProfile? {
        didSet {
            if oldValue?.id != activeProfile?.id {
                reloadFavoriteRecipeIDs()
            }
        }
    }
    @Published var currentUser: MealieUser?
    @Published var hasServerProfiles: Bool
    @Published var recipeCacheSnapshot: RecipeOfflineCacheSnapshot = .empty
    @Published var allRecipeCacheSnapshot: RecipeOfflineCacheSnapshot = .empty
    @Published var isSyncingOfflineRecipes = false
    @Published var offlineRecipeSyncProgress: Double?
    @Published var networkReachabilityTrigger = 0
    @Published var tabLayout: [HomeTabLayoutItem]
    @Published private(set) var authenticationIssueProfileIDs: Set<UUID> = []
    /// Recipe IDs the signed-in user has favorited on the active profile,
    /// persisted with the offline cache so favorites filter offline.
    @Published private(set) var favoriteRecipeIDs: Set<String> = []
    /// Bumped when the user toggles a favorite so favorites-only lists refetch.
    @Published private(set) var favoritesRevision = 0
    private var isNetworkReachable = false

    var activeProfileNeedsSignIn: Bool {
        guard let activeProfile else { return false }
        return authenticationIssueProfileIDs.contains(activeProfile.id)
    }

    /// Whether the active server is new enough for `feature` (CON-014).
    /// Unknown or development versions are treated as supported.
    func supports(_ feature: MealieFeature) -> Bool {
        feature.isSupported(byServerVersion: activeProfile?.version)
    }

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
        self.tabLayout = preferenceStore.tabLayout
        let storedProfiles = profileStore.allProfiles()
        self.activeProfile = profileStore.activeProfile() ?? storedProfiles.first
        self.hasServerProfiles = !storedProfiles.isEmpty
        self.authenticationIssueProfileIDs = Set(storedProfiles.compactMap { profile in
            (try? credentialStore.loadToken(for: profile.id)) == nil ? profile.id : nil
        })
        if let activeProfile = self.activeProfile {
            profileStore.setActiveProfileID(activeProfile.id)
            recipeCacheSnapshot = recipeOfflineCache.snapshot(profileID: activeProfile.id)
        }
        refreshAllRecipeCacheSnapshot()

        if configuration.useMockServer,
           let token = configuration.debugAuthToken,
           self.activeProfile == nil {
            let profile = ServerProfile(
                displayName: configuration.initialServerURL?.host ?? "Mock Mealie",
                serverURL: configuration.initialServerURL ?? URL(string: "https://mock.mealie.local")!,
                version: configuration.debugMockServerVersion ?? MockMealieAPIClient.defaultServerVersion,
                lastUsername: "chef"
            )
            try? credentialStore.saveToken(MealieAuthToken(accessToken: token, tokenType: "bearer"), for: profile.id)
            profileStore.upsert(profile)
            profileStore.setActiveProfileID(profile.id)
            self.activeProfile = profile
            self.hasServerProfiles = true
            recipeCacheSnapshot = recipeOfflineCache.snapshot(profileID: profile.id)
            refreshAllRecipeCacheSnapshot()
        }

        reloadFavoriteRecipeIDs()
        startNetworkMonitor()
    }

    deinit {
        networkMonitor.cancel()
    }

    static func live(configuration: AppConfiguration) -> AppEnvironment {
        let apiClient: MealieAPIClient = configuration.useMockServer
            ? MockMealieAPIClient.preloaded(serverVersion: configuration.debugMockServerVersion)
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
        user: MealieUser,
        credentials: LoginCredentials? = nil
    ) {
        try? credentialStore.saveToken(token, for: profile.id)
        if let credentials {
            try? credentialStore.saveLoginCredentials(credentials, for: profile.id)
        } else if profile.resolvedAuthMethod == .apiToken {
            // API tokens can't be renewed by re-login; drop stale passwords so
            // a revoked token surfaces "sign in needed" instead of silently
            // switching back to password auth.
            try? credentialStore.deleteLoginCredentials(for: profile.id)
        }
        profileStore.upsert(profile)
        profileStore.setActiveProfileID(profile.id)
        authenticationIssueProfileIDs.remove(profile.id)
        activeProfile = profile
        currentUser = user
        hasServerProfiles = true
        refreshRecipeCacheSnapshot()
    }

    /// Validates the chosen sign-in method against `profile`'s server and
    /// adopts the resulting session. Password sign-in keeps credentials for
    /// transparent re-login; API token sign-in (CON-013) stores only the
    /// token because Mealie can't refresh it.
    func signIn(
        profile: ServerProfile,
        method: ServerAuthMethod,
        username: String,
        password: String,
        apiToken: String
    ) async throws {
        var saved = profile
        saved.authMethod = method
        switch method {
        case .password:
            guard !password.isEmpty else { throw AppError.missingPassword }
            let token = try await apiClient.login(
                serverURL: profile.serverURL,
                username: username,
                password: password
            )
            let user = try await apiClient.fetchCurrentUser(serverURL: profile.serverURL, token: token)
            saved.lastUsername = username
            adoptAuthenticatedSession(
                profile: saved,
                token: token,
                user: user,
                credentials: LoginCredentials(username: username, password: password)
            )
        case .apiToken:
            guard let token = MealieAuthToken(apiToken: apiToken) else { throw AppError.missingAPIToken }
            let user: MealieUser
            do {
                user = try await apiClient.fetchCurrentUser(serverURL: profile.serverURL, token: token)
            } catch AppError.unauthorized {
                throw AppError.invalidAPIToken
            }
            saved.lastUsername = user.username
            adoptAuthenticatedSession(profile: saved, token: token, user: user)
        }
    }

    /// Returns the cached signed-in user, fetching `/api/users/self` once
    /// when it isn't known yet (e.g. after switching profiles).
    func resolveCurrentUser(profile: ServerProfile, token: MealieAuthToken) async throws -> MealieUser {
        if let currentUser, activeProfile?.id == profile.id {
            return currentUser
        }
        let user = try await apiClient.fetchCurrentUser(serverURL: profile.serverURL, token: token)
        if activeProfile?.id == profile.id {
            currentUser = user
        }
        return user
    }

    func switchToProfile(_ profile: ServerProfile) {
        profileStore.setActiveProfileID(profile.id)
        activeProfile = profile
        currentUser = nil
        if (try? credentialStore.loadToken(for: profile.id)) == nil {
            markAuthenticationIssue(for: profile)
        }
        hasServerProfiles = !profileStore.allProfiles().isEmpty
        refreshRecipeCacheSnapshot()
    }

    /// Re-reads `/api/app/about` for the active profile and persists the
    /// reported version so feature gates follow server upgrades (CON-014).
    /// Failures are ignored; the last known version stays in effect.
    func refreshActiveServerInfo() async {
        guard let profile = activeProfile,
              let info = try? await apiClient.fetchServerInfo(serverURL: profile.serverURL),
              let version = info.version,
              version != profile.version,
              activeProfile?.id == profile.id else {
            return
        }
        var updated = activeProfile ?? profile
        updated.version = version
        profileStore.upsert(updated)
        activeProfile = updated
    }

    func removeServer(_ profile: ServerProfile) {
        try? credentialStore.deleteToken(for: profile.id)
        try? credentialStore.deleteLoginCredentials(for: profile.id)
        profileStore.remove(id: profile.id)
        authenticationIssueProfileIDs.remove(profile.id)
        recipeOfflineCache.clear(profileID: profile.id)
        activeProfile = profileStore.activeProfile()
        currentUser = nil
        hasServerProfiles = !profileStore.allProfiles().isEmpty
        refreshRecipeCacheSnapshot()
    }

    func refreshRecipeCacheSnapshot() {
        guard let activeProfile else {
            recipeCacheSnapshot = .empty
            refreshAllRecipeCacheSnapshot()
            return
        }
        recipeCacheSnapshot = recipeOfflineCache.snapshot(profileID: activeProfile.id)
        refreshAllRecipeCacheSnapshot()
    }

    func refreshAllRecipeCacheSnapshot() {
        let snapshots = profileStore.allProfiles().map { recipeOfflineCache.snapshot(profileID: $0.id) }
        allRecipeCacheSnapshot = RecipeOfflineCacheSnapshot(
            recipeCount: snapshots.reduce(0) { $0 + $1.recipeCount },
            byteCount: snapshots.reduce(0) { $0 + $1.byteCount },
            lastUpdated: snapshots.compactMap(\.lastUpdated).max()
        )
    }

    func clearOfflineRecipes() {
        for profile in profileStore.allProfiles() {
            recipeOfflineCache.clear(profileID: profile.id)
        }
        refreshRecipeCacheSnapshot()
    }

    // MARK: - Favorites

    private func reloadFavoriteRecipeIDs() {
        favoriteRecipeIDs = activeProfile.map { recipeOfflineCache.cachedFavoriteRecipeIDs(profileID: $0.id) } ?? []
    }

    /// Replaces the known favorites with the server's list.
    func refreshFavoriteRecipeIDs(profile: ServerProfile, token: MealieAuthToken) async throws {
        let favorites = try await apiClient.fetchFavorites(serverURL: profile.serverURL, token: token)
        let recipeIDs = Set(favorites.filter(\.isFavorite).map(\.recipeID))
        recipeOfflineCache.cacheFavoriteRecipeIDs(recipeIDs, profileID: profile.id)
        if activeProfile?.id == profile.id, favoriteRecipeIDs != recipeIDs {
            favoriteRecipeIDs = recipeIDs
        }
    }

    /// Adds recipes the server just returned for a favorites-only query.
    func mergeFavoriteRecipeIDs(_ recipeIDs: [String], profile: ServerProfile) {
        guard activeProfile?.id == profile.id else { return }
        let updated = favoriteRecipeIDs.union(recipeIDs)
        guard updated != favoriteRecipeIDs else { return }
        favoriteRecipeIDs = updated
        recipeOfflineCache.cacheFavoriteRecipeIDs(updated, profileID: profile.id)
    }

    /// Records a favorite change made or observed on a single recipe.
    func recordFavorite(_ isFavorite: Bool, recipeID: String, profile: ServerProfile) {
        guard activeProfile?.id == profile.id else { return }
        var updated = favoriteRecipeIDs
        if isFavorite {
            updated.insert(recipeID)
        } else {
            updated.remove(recipeID)
        }
        guard updated != favoriteRecipeIDs else { return }
        favoriteRecipeIDs = updated
        recipeOfflineCache.cacheFavoriteRecipeIDs(updated, profileID: profile.id)
        favoritesRevision += 1
    }

    func updateTabLayout(_ layout: [HomeTabLayoutItem]) {
        tabLayout = HomeTabLayoutItem.normalized(layout)
        preferenceStore.tabLayout = tabLayout
    }

    func markAuthenticationIssue(for profile: ServerProfile) {
        authenticationIssueProfileIDs.insert(profile.id)
    }

    func clearAuthenticationIssue(for profile: ServerProfile) {
        authenticationIssueProfileIDs.remove(profile.id)
    }

    // MARK: - Transparent re-authentication

    /// Re-logs in using stored credentials and saves the resulting token.
    /// Throws `AppError.unauthorized` if no credentials are on file, which is
    /// always the case for API token profiles (CON-013).
    private func reauthenticate(for profile: ServerProfile) async throws -> MealieAuthToken {
        guard let credentials = try? credentialStore.loadLoginCredentials(for: profile.id) else {
            throw AppError.unauthorized
        }
        let token = try await apiClient.login(
            serverURL: profile.serverURL,
            username: credentials.username,
            password: credentials.password
        )
        try? credentialStore.saveToken(token, for: profile.id)
        clearAuthenticationIssue(for: profile)
        return token
    }

    /// Loads the access token for `profile`, transparently re-authenticating
    /// once if the token is missing or has expired (HTTP 401). On a second
    /// consecutive 401 the error is re-thrown so callers can surface it.
    func withToken<T>(
        for profile: ServerProfile,
        operation: (MealieAuthToken) async throws -> T
    ) async throws -> T {
        let token: MealieAuthToken
        if let stored = try? credentialStore.loadToken(for: profile.id) {
            token = stored
        } else {
            token = try await reauthenticate(for: profile)
        }

        do {
            return try await operation(token)
        } catch AppError.unauthorized {
            // Token likely expired; get a fresh one and retry exactly once.
            let freshToken = try await reauthenticate(for: profile)
            return try await operation(freshToken)
        }
    }

    func syncOfflineRecipesIfNeeded() async {
        let lastUpdated = recipeCacheSnapshot.lastUpdated ?? .distantPast
        guard Date().timeIntervalSince(lastUpdated) > 6 * 60 * 60 else { return }
        await syncOfflineRecipes(force: false)
    }

    func syncOfflineRecipes(force: Bool) async {
        guard !isSyncingOfflineRecipes,
              let profile = activeProfile else { return }
        isSyncingOfflineRecipes = true
        offlineRecipeSyncProgress = 0
        var downloadedRecipeCount = 0
        var expectedRecipeCount: Int?
        defer {
            isSyncingOfflineRecipes = false
            offlineRecipeSyncProgress = nil
        }

        var pageNumber = 1
        var totalPages = 1
        repeat {
            do {
                var usedToken: MealieAuthToken?
                let page = try await withToken(for: profile) { token in
                    usedToken = token
                    return try await apiClient.fetchRecipes(
                        serverURL: profile.serverURL,
                        token: token,
                        page: pageNumber,
                        perPage: 50,
                        filters: MealieRecipeFilters()
                    )
                }
                totalPages = page.totalPages ?? page.total.map { Int(ceil(Double($0) / Double(page.perPage))) } ?? pageNumber
                expectedRecipeCount = page.total ?? expectedRecipeCount ?? (totalPages * page.perPage)
                guard let usedToken else { return }
                await cacheRecipesOffline(page.items, profile: profile, token: usedToken, force: force) {
                    downloadedRecipeCount += 1
                    if let expectedRecipeCount, expectedRecipeCount > 0 {
                        self.offlineRecipeSyncProgress = min(Double(downloadedRecipeCount) / Double(expectedRecipeCount), 1)
                    }
                }
                pageNumber += 1
            } catch {
                break
            }
        } while pageNumber <= totalPages

        _ = try? await withToken(for: profile) { token in
            try await refreshFavoriteRecipeIDs(profile: profile, token: token)
        }
        refreshRecipeCacheSnapshot()
    }

    func cacheRecipesOffline(
        _ recipes: [MealieRecipeSummary],
        profile: ServerProfile,
        token: MealieAuthToken,
        force: Bool = false,
        onRecipeCached: (() -> Void)? = nil
    ) async {
        for recipe in recipes {
            if !force, recipeOfflineCache.cachedRecipeDetail(profileID: profile.id, slug: recipe.slug) != nil {
                onRecipeCached?()
                continue
            }
            await cacheRecipeOffline(recipe, profile: profile, token: token)
            onRecipeCached?()
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
