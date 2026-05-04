import SwiftUI

struct RecipesView: View {
    @StateObject private var recipeResultsState = RecipeResultsState()
    @AppStorage("katsu.recentRecipeSearches") private var recentSearchesData = Data()
    @State private var showImportRecipe = false
    @State private var refreshTrigger = 0
    @State private var searchText = ""
    @State private var appliedFilters = MealieRecipeFilters()

    private let suggestions = [
        "Dinner",
        "Breakfast",
        "Katsu",
        "Salad"
    ]

    private var draftFilters: MealieRecipeFilters {
        MealieRecipeFilters(search: searchText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var isSearching: Bool {
        !appliedFilters.isEmpty
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
                allowsOfflineCache: appliedFilters.isEmpty,
                resultsTitle: nil,
                emptyStateTitle: isSearching ? "No matching recipes" : "No recipes yet",
                emptyStateDescription: isSearching ? "Try another recipe name." : "Imported and saved recipes will appear here.",
                emptyStateImage: isSearching ? "magnifyingglass" : "book.closed",
                idleStateTitle: "No recipes yet",
                idleStateDescription: "Imported and saved recipes will appear here.",
                idleStateImage: "book.closed",
                footer: isSearching ? nil : "Meal plans and shopping lists are coming soon.",
                presentation: .cardFeed
            ) {
                EmptyView()
            }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search recipes"
            ) {
                if draftFilters.isEmpty {
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
