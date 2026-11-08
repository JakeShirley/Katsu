import SwiftUI

struct RecipesView: View {
    @StateObject private var recipeResultsState = RecipeResultsState()
    @AppStorage("katsu.recentRecipeSearches") private var recentSearchesData = Data()
    @State private var showImportRecipe = false
    @State private var refreshTrigger = 0
    @State private var searchText = ""
    @State private var appliedFilters = MealieRecipeFilters()
    @State private var favoritesOnly = false

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

    var body: some View {
        NavigationStack {
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
                footer: !appliedFilters.isEmpty ? nil : "Meal plans and shopping lists are coming soon.",
                presentation: .cardFeed
            ) {
                EmptyView()
            }
            .navigationTitle(favoritesOnly ? "Favorites" : "Recipes")
            .navigationBarTitleDisplayMode(.inline)
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
            .sheet(isPresented: $showImportRecipe) {
                NavigationStack {
                    ImportRecipeView {
                        await MainActor.run {
                            refreshTrigger += 1
                        }
                    }
                }
            }
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
