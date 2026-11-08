import SwiftUI

struct RecipeResultsList<Header: View>: View {
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject var state: RecipeResultsState
    let filters: MealieRecipeFilters
    let refreshTrigger: Int
    let loadsWhenFiltersEmpty: Bool
    let allowsOfflineCache: Bool
    let resultsTitle: LocalizedStringKey?
    let emptyStateTitle: LocalizedStringKey
    let emptyStateDescription: LocalizedStringKey
    let emptyStateImage: String
    let idleStateTitle: LocalizedStringKey
    let idleStateDescription: LocalizedStringKey
    let idleStateImage: String
    let footer: LocalizedStringKey?
    let presentation: RecipeResultsPresentation
    let header: Header

    @State private var isTwoPage = false

    private let recipesPerPage = 5
    /// Hides recipes unfavorited since the page loaded so the favorites
    /// list updates immediately, before the refetch lands.
    private var visibleRecipes: [MealieRecipeSummary] {
        guard filters.favoritesOnly else { return state.recipes }
        return state.recipes.filter { recipe in
            recipe.recipeID.map(env.favoriteRecipeIDs.contains) ?? true
        }
    }

    private var taskID: RecipeResultsTaskID {
        RecipeResultsTaskID(profileID: env.activeProfile?.id, filters: filters, refreshTrigger: refreshTrigger)
    }

    init(
        state: RecipeResultsState,
        filters: MealieRecipeFilters,
        refreshTrigger: Int,
        loadsWhenFiltersEmpty: Bool,
        allowsOfflineCache: Bool,
        resultsTitle: LocalizedStringKey?,
        emptyStateTitle: LocalizedStringKey,
        emptyStateDescription: LocalizedStringKey,
        emptyStateImage: String,
        idleStateTitle: LocalizedStringKey,
        idleStateDescription: LocalizedStringKey,
        idleStateImage: String,
        footer: LocalizedStringKey?,
        presentation: RecipeResultsPresentation = .groupedList,
        @ViewBuilder header: () -> Header
    ) {
        self.state = state
        self.filters = filters
        self.refreshTrigger = refreshTrigger
        self.loadsWhenFiltersEmpty = loadsWhenFiltersEmpty
        self.allowsOfflineCache = allowsOfflineCache
        self.resultsTitle = resultsTitle
        self.emptyStateTitle = emptyStateTitle
        self.emptyStateDescription = emptyStateDescription
        self.emptyStateImage = emptyStateImage
        self.idleStateTitle = idleStateTitle
        self.idleStateDescription = idleStateDescription
        self.idleStateImage = idleStateImage
        self.footer = footer
        self.presentation = presentation
        self.header = header()
    }

    var body: some View {
        content
        .task(id: taskID) {
            await refreshRecipesForCurrentFilters()
            if filters.isEmpty, loadsWhenFiltersEmpty {
                await env.syncOfflineRecipesIfNeeded()
            }
        }
        .refreshable {
            await refreshRecipesForCurrentFilters(force: true)
            if filters.isEmpty, loadsWhenFiltersEmpty {
                await env.syncOfflineRecipes(force: true)
            }
        }
        .task(id: env.networkReachabilityTrigger) {
            guard state.showingCachedRecipes else { return }
            await refreshRecipesForCurrentFilters(force: true)
        }
        .onChange(of: env.favoritesRevision) {
            guard filters.favoritesOnly else { return }
            Task { await refreshRecipesForCurrentFilters(force: true) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch presentation {
        case .groupedList:
            groupedListContent
        case .cardFeed:
            cardFeedContent
        }
    }

    private var groupedListContent: some View {
        List {
            header

            if let resultsTitle {
                Section(resultsTitle) {
                    resultsContent
                }
            } else {
                Section {
                    resultsContent
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, DesignSystem.Spacing.sm, for: .scrollContent)
    }

    private var cardFeedContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                header

                if let resultsTitle {
                    Text(resultsTitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.top, DesignSystem.Spacing.xs)
                }

                feedResultsContent
            }
            .padding(.top, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .background(DesignSystem.Colors.background)
        .onTwoPageWidthChange { isTwoPage = $0 }
    }

    private var feedColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.md, alignment: .top),
            count: isTwoPage ? 2 : 1
        )
    }

    @ViewBuilder
    private var resultsContent: some View {
        if filters.isEmpty && !loadsWhenFiltersEmpty {
            ContentUnavailableView {
                Label {
                    Text(idleStateTitle)
                } icon: {
                    Image(systemName: idleStateImage)
                }
            } description: {
                Text(idleStateDescription)
            }
            .listRowBackground(Color.clear)
        } else if state.isLoadingRecipes && visibleRecipes.isEmpty {
            LoadingRecipeRow(title: "Loading recipes…")
        } else if let recipeLoadError = state.recipeLoadError, visibleRecipes.isEmpty {
            RecipeErrorRow(errorMessage: recipeLoadError) {
                Task { await refreshRecipes() }
            }
        } else if visibleRecipes.isEmpty {
            ContentUnavailableView {
                Label {
                    Text(emptyStateTitle)
                } icon: {
                    Image(systemName: emptyStateImage)
                }
            } description: {
                Text(emptyStateDescription)
            }
            .listRowBackground(Color.clear)
        } else {
            if state.showingCachedRecipes {
                Label("Showing offline recipes", systemImage: "wifi.slash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Showing offline recipes")
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            ForEach(visibleRecipes) { recipe in
                NavigationLink {
                    RecipeDetailView(recipe: recipe)
                } label: {
                    RecipeRow(recipe: recipe, profileID: env.activeProfile?.id, serverURL: env.activeProfile?.serverURL)
                }
                .listRowInsets(EdgeInsets(top: DesignSystem.Spacing.xs, leading: DesignSystem.Spacing.lg, bottom: DesignSystem.Spacing.xs, trailing: DesignSystem.Spacing.lg))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .onAppear {
                    if recipe.id == visibleRecipes.last?.id {
                        Task { await loadMoreRecipesIfNeeded() }
                    }
                }
            }

            if state.isLoadingMoreRecipes {
                LoadingRecipeRow(title: "Loading more recipes…")
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else if state.recipeLoadError != nil {
                Button("Try Again") {
                    Task { await loadMoreRecipesIfNeeded(force: true) }
                }
                .frame(minHeight: DesignSystem.HitTarget.minimum)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }

        if let footer {
            Text(footer)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var feedResultsContent: some View {
        if filters.isEmpty && !loadsWhenFiltersEmpty {
            RecipeUnavailableCard(title: idleStateTitle, description: idleStateDescription, systemImage: idleStateImage)
        } else if state.isLoadingRecipes && visibleRecipes.isEmpty {
            RecipeStatusCard {
                LoadingRecipeRow(title: "Loading recipes…")
            }
        } else if let recipeLoadError = state.recipeLoadError, visibleRecipes.isEmpty {
            RecipeStatusCard {
                RecipeErrorRow(errorMessage: recipeLoadError) {
                    Task { await refreshRecipes() }
                }
            }
        } else if visibleRecipes.isEmpty {
            RecipeUnavailableCard(title: emptyStateTitle, description: emptyStateDescription, systemImage: emptyStateImage)
        } else {
            if state.showingCachedRecipes {
                RecipeStatusCard {
                    Label("Showing offline recipes", systemImage: "wifi.slash")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Showing offline recipes")
                }
            }

            LazyVGrid(columns: feedColumns, alignment: .leading, spacing: DesignSystem.Spacing.md) {
                ForEach(visibleRecipes) { recipe in
                    feedCard(for: recipe)
                        .onAppear {
                            if recipe.id == visibleRecipes.last?.id {
                                Task { await loadMoreRecipesIfNeeded() }
                            }
                        }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)

            if state.isLoadingMoreRecipes {
                RecipeStatusCard {
                    LoadingRecipeRow(title: "Loading more recipes…")
                }
            } else if state.recipeLoadError != nil {
                RecipeStatusCard {
                    Button("Try Again") {
                        Task { await loadMoreRecipesIfNeeded(force: true) }
                    }
                    .frame(minHeight: DesignSystem.HitTarget.minimum)
                }
            }
        }

        if let footer {
            Text(footer)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.xs)
        }
    }

    private func feedCard(for recipe: MealieRecipeSummary) -> some View {
        NavigationLink {
            RecipeDetailView(recipe: recipe)
        } label: {
            RecipeRow(
                recipe: recipe,
                profileID: env.activeProfile?.id,
                serverURL: env.activeProfile?.serverURL,
                showsDisclosureIndicator: true,
                fillsAvailableHeight: isTwoPage
            )
        }
        .buttonStyle(.plain)
    }

    private func refreshRecipesForCurrentFilters(force: Bool = false) async {
        guard loadsWhenFiltersEmpty || !filters.isEmpty else {
            state.reset()
            return
        }
        if force || state.recipes.isEmpty || state.taskID != taskID {
            state.taskID = taskID
            await refreshRecipes()
        }
    }

    private func refreshRecipes() async {
        await loadRecipes(page: 1, replacingExisting: true)
    }

    private func loadMoreRecipesIfNeeded(force: Bool = false) async {
        guard force || hasMoreRecipes else { return }
        await loadRecipes(page: state.recipePage + 1, replacingExisting: false)
    }

    private var hasMoreRecipes: Bool {
        if let recipeTotalPages = state.recipeTotalPages {
            return state.recipePage < recipeTotalPages
        }
        return !state.recipes.isEmpty
    }

    private func loadRecipes(page: Int, replacingExisting: Bool) async {
        guard let profile = env.activeProfile else { return }
        let filters = filters
        if replacingExisting {
            guard !state.isLoadingRecipes else { return }
            state.isLoadingRecipes = true
        } else {
            guard !state.isLoadingMoreRecipes else { return }
            state.isLoadingMoreRecipes = true
        }
        defer {
            state.isLoadingRecipes = false
            state.isLoadingMoreRecipes = false
        }

        do {
            var usedToken: MealieAuthToken?
            let page = try await env.withToken(for: profile) { token in
                usedToken = token
                var requestFilters = filters
                if filters.favoritesOnly, requestFilters.favoritedByUserID == nil {
                    requestFilters.favoritedByUserID = try await env.resolveCurrentUser(profile: profile, token: token).id
                }
                if replacingExisting, filters.isEmpty || filters.favoritesOnly {
                    // Keeps offline favorites filtering current.
                    try? await env.refreshFavoriteRecipeIDs(profile: profile, token: token)
                }
                return try await env.apiClient.fetchRecipes(
                    serverURL: profile.serverURL,
                    token: token,
                    page: page,
                    perPage: recipesPerPage,
                    filters: requestFilters
                )
            }
            if filters.favoritesOnly {
                env.mergeFavoriteRecipeIDs(page.items.compactMap(\.recipeID), profile: profile)
            }
            state.recipePage = page.page
            state.recipeTotalPages = page.totalPages ?? page.total.map { total in
                Int(ceil(Double(total) / Double(page.perPage)))
            }
            state.recipes = replacingExisting ? page.items : state.recipes + page.items
            state.showingCachedRecipes = false
            state.recipeLoadError = nil
            env.clearAuthenticationIssue(for: profile)
            if replacingExisting, filters.isEmpty, let usedToken {
                await env.cacheRecipesOffline(page.items, profile: profile, token: usedToken)
            }
        } catch let error as AppError {
            if error == .unauthorized {
                env.markAuthenticationIssue(for: profile)
            } else if error != .offline {
                env.clearAuthenticationIssue(for: profile)
            }
            showCachedRecipesOrError(error, profile: profile, replacingExisting: replacingExisting)
        } catch {
            state.recipeLoadError = error.localizedDescription
        }
    }

    private func showCachedRecipesOrError(_ error: AppError, profile: ServerProfile, replacingExisting: Bool) {
        if (error == .offline || error == .unauthorized), replacingExisting, allowsOfflineCache {
            let cachedRecipes = env.recipeOfflineCache.cachedRecipeSummaries(profileID: profile.id).filter { recipe in
                recipe.matches(filters, favoriteRecipeIDs: env.favoriteRecipeIDs)
            }
            if !cachedRecipes.isEmpty {
                state.recipes = cachedRecipes
                state.recipePage = 1
                state.recipeTotalPages = 1
                state.showingCachedRecipes = true
                state.recipeLoadError = nil
                return
            }
        }

        state.recipeLoadError = error.errorDescription
    }
}

struct RecipeResultsTaskID: Equatable {
    let profileID: UUID?
    let filters: MealieRecipeFilters
    let refreshTrigger: Int
}

@MainActor
final class RecipeResultsState: ObservableObject {
    @Published var recipes: [MealieRecipeSummary] = []
    @Published var recipePage = 1
    @Published var recipeTotalPages: Int?
    @Published var recipeLoadError: String?
    @Published var isLoadingRecipes = false
    @Published var isLoadingMoreRecipes = false
    @Published var showingCachedRecipes = false
    var taskID: RecipeResultsTaskID?

    func reset() {
        recipes = []
        recipePage = 1
        recipeTotalPages = nil
        recipeLoadError = nil
        isLoadingRecipes = false
        isLoadingMoreRecipes = false
        showingCachedRecipes = false
        taskID = nil
    }
}

enum RecipeResultsPresentation {
    case groupedList
    case cardFeed
}

private struct RecipeStatusCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
            .overlay {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                    .stroke(DesignSystem.Colors.separator.opacity(0.16))
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
    }
}

private struct RecipeUnavailableCard: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    let systemImage: String

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(DesignSystem.Colors.accentDeep)
                .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                .background(DesignSystem.Colors.accentSoft.opacity(0.75), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xl)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(DesignSystem.Colors.separator.opacity(0.16))
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}

struct LoadingRecipeRow: View {
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ProgressView()
            Text(title)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}

struct RecipeErrorRow: View {
    let errorMessage: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(errorMessage)
                .foregroundStyle(DesignSystem.Colors.destructive)
            Button("Try Again", action: onRetry)
                .frame(minHeight: DesignSystem.HitTarget.minimum)
        }
    }
}
