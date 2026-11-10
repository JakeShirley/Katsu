import SwiftUI

struct RecipesView: View {
    @StateObject private var recipeResultsState = RecipeResultsState()
    @AppStorage("katsu.recentRecipeSearches") private var recentSearchesData = Data()
    @State private var showImportRecipe = false
    @State private var refreshTrigger = 0
    @State private var searchText = ""
    @State private var appliedFilters = MealieRecipeFilters()
    @State private var favoritesOnly = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var containerWidth: CGFloat = 0
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.deviceFold) private var deviceFold

    private let suggestions = [
        "Dinner",
        "Breakfast",
        "Katsu",
        "Salad"
    ]

    private var draftFilters: MealieRecipeFilters {
        MealieRecipeFilters(
            search: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
            favoritesOnly: favoritesOnly
        )
    }

    private var isSearching: Bool {
        !appliedFilters.search.isEmpty
    }

    private var emptyStateTitle: LocalizedStringKey {
        if appliedFilters.favoritesOnly {
            return isSearching ? "No matching favorites" : "No favorite recipes yet"
        }
        return isSearching ? "No matching recipes" : "No recipes yet"
    }

    private var emptyStateDescription: LocalizedStringKey {
        if appliedFilters.favoritesOnly {
            return isSearching ? "Try another recipe name." : "Tap Add Favorite on a recipe to see it here."
        }
        return isSearching ? "Try another recipe name." : "Imported and saved recipes will appear here."
    }

    private var emptyStateImage: String {
        if appliedFilters.favoritesOnly, !isSearching {
            return "heart"
        }
        return isSearching ? "magnifyingglass" : "book.closed"
    }

    private var recentSearches: [String] {
        (try? JSONDecoder().decode([String].self, from: recentSearchesData)) ?? []
    }

    /// In book posture the list fills the page before the fold and the
    /// selected recipe the page after it.
    private var sidebarWidth: CGFloat {
        deviceFold?.verticalFoldX ?? 400
    }

    private var navigationTitle: LocalizedStringKey {
        favoritesOnly ? "Favorites" : "Recipes"
    }

    /// Collapses the split view into a stack when both columns can't fit
    /// side by side, even though the size class is regular.
    private var splitHorizontalSizeClass: UserInterfaceSizeClass? {
        guard containerWidth > 0, containerWidth < AdaptiveLayout.splitViewMinimumWidth else {
            return horizontalSizeClass
        }
        return .compact
    }

    var body: some View {
        // When there's room for two columns (iPad and unfolded iPhone Duo in
        // landscape) the feed stays visible beside the selected recipe;
        // otherwise the split view collapses into a single navigation stack.
        NavigationSplitView(columnVisibility: $columnVisibility) {
            results
                .navigationTitle(navigationTitle)
                .navigationSplitViewColumnWidth(sidebarWidth)
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search recipes"
                ) {
                    if draftFilters.search.isEmpty {
                        if !recentSearches.isEmpty {
                            Section("Recents") {
                                ForEach(recentSearches, id: \.self) { recentSearch in
                                    Text(recentSearch)
                                        .searchCompletion(recentSearch)
                                }
                            }
                        }

                        Section("Suggestions") {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Text(suggestion)
                                    .searchCompletion(suggestion)
                            }
                        }
                    }
                }
                .onSubmit(of: .search) {
                    applySubmittedSearch()
                }
                .task(id: draftFilters) {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        appliedFilters = draftFilters
                        saveRecentSearch(draftFilters.search)
                    }
                }
                .toolbar {
                    recipesToolbar
                }
                .sheet(isPresented: $showImportRecipe) {
                    NavigationStack {
                        ImportRecipeView {
                            await MainActor.run {
                                refreshTrigger += 1
                            }
                        }
                    }
                }
        } detail: {
            ContentUnavailableView {
                Label("Select a recipe", systemImage: "book.closed")
            } description: {
                Text("Choose a recipe to see its ingredients and steps.")
            }
            .background(DesignSystem.Colors.background)
        }
        .navigationSplitViewStyle(.balanced)
        .environment(\.horizontalSizeClass, splitHorizontalSizeClass)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            containerWidth = width
        }
    }

    private var results: some View {
        RecipeResultsList(
            state: recipeResultsState,
            filters: appliedFilters,
            refreshTrigger: refreshTrigger,
            loadsWhenFiltersEmpty: true,
            allowsOfflineCache: true,
            resultsTitle: nil,
            emptyStateTitle: emptyStateTitle,
            emptyStateDescription: emptyStateDescription,
            emptyStateImage: emptyStateImage,
            idleStateTitle: "No recipes yet",
            idleStateDescription: "Imported and saved recipes will appear here.",
            idleStateImage: "book.closed",
            footer: nil,
            presentation: .cardFeed
        ) {
            EmptyView()
        }
    }

    @ToolbarContentBuilder
    private var recipesToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                favoritesOnly.toggle()
                appliedFilters = draftFilters
            } label: {
                Label(
                    favoritesOnly ? "Show All Recipes" : "Show Favorites Only",
                    systemImage: favoritesOnly ? "heart.fill" : "heart"
                )
            }
            .accessibilityLabel(favoritesOnly ? "Show All Recipes" : "Show Favorites Only")
            .accessibilityAddTraits(favoritesOnly ? .isSelected : [])
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showImportRecipe = true
            } label: {
                Label("Import Recipe", systemImage: "square.and.arrow.down")
            }
            .accessibilityLabel("Import Recipe")
        }
    }

    private func applySubmittedSearch() {
        appliedFilters = draftFilters
        saveRecentSearch(draftFilters.search)
    }

    private func saveRecentSearch(_ rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        var recents = recentSearches.filter { $0.localizedCaseInsensitiveCompare(query) != .orderedSame }
        recents.insert(query, at: 0)
        recentSearchesData = (try? JSONEncoder().encode(Array(recents.prefix(4)))) ?? Data()
    }
}
