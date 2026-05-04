import SwiftUI

struct RecipeSearchView: View {
    @Environment(\.dismissSearch) private var dismissSearch
    @StateObject private var recipeResultsState = RecipeResultsState()
    @AppStorage("katsu.recentRecipeSearches") private var recentSearchesData = Data()
    @State private var searchText = ""
    @State private var appliedFilters = MealieRecipeFilters()

    private let suggestions = [
        RecipeSearchSuggestion(title: "Dinner", subtitle: "Weeknight recipes", systemImage: "fork.knife", query: "dinner"),
        RecipeSearchSuggestion(title: "Breakfast", subtitle: "Morning ideas", systemImage: "sun.max", query: "breakfast"),
        RecipeSearchSuggestion(title: "Katsu", subtitle: "Japanese comfort food", systemImage: "magnifyingglass", query: "katsu"),
        RecipeSearchSuggestion(title: "Salad", subtitle: "Fresh recipes", systemImage: "leaf", query: "salad")
    ]

    private var draftFilters: MealieRecipeFilters {
        MealieRecipeFilters(search: searchText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var recentSearches: [String] {
        (try? JSONDecoder().decode([String].self, from: recentSearchesData)) ?? []
    }

    var body: some View {
        NavigationStack {
            RecipeResultsList(
                state: recipeResultsState,
                filters: appliedFilters,
                refreshTrigger: 0,
                loadsWhenFiltersEmpty: false,
                allowsOfflineCache: false,
                resultsTitle: "Results",
                emptyStateTitle: "No matching recipes",
                emptyStateDescription: "Try another recipe name.",
                emptyStateImage: "magnifyingglass",
                idleStateTitle: "Start searching",
                idleStateDescription: "Type a recipe name to find matches on this server.",
                idleStateImage: "sparkle.magnifyingglass",
                footer: nil
            ) {
                EmptyView()
            }
            .navigationTitle("Search")
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
                                Button {
                                    applySearch(recentSearch)
                                } label: {
                                    RecipeSearchRecentRow(query: recentSearch)
                                }
                            }
                        }
                    }

                    Section("Suggestions") {
                        ForEach(suggestions) { suggestion in
                            Button {
                                applySearch(suggestion.query)
                            } label: {
                                RecipeSearchSuggestionRow(suggestion: suggestion)
                            }
                        }
                    }
                }
            }
            .onSubmit(of: .search) {
                saveRecentSearch(searchText)
            }
            .task(id: draftFilters) {
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    appliedFilters = draftFilters
                    saveRecentSearch(draftFilters.search)
                }
            }
        }
    }

    private func applySearch(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }

        searchText = trimmedQuery
        appliedFilters = MealieRecipeFilters(search: trimmedQuery)
        saveRecentSearch(trimmedQuery)
        dismissSearch()
    }

    private func saveRecentSearch(_ rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        var recents = recentSearches.filter { $0.localizedCaseInsensitiveCompare(query) != .orderedSame }
        recents.insert(query, at: 0)
        recentSearchesData = (try? JSONEncoder().encode(Array(recents.prefix(4)))) ?? Data()
    }
}

private struct RecipeSearchSuggestion: Identifiable {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    let query: String

    var id: String { query }
}

private struct RecipeSearchSuggestionRow: View {
    let suggestion: RecipeSearchSuggestion

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                Text(suggestion.title)
                    .font(.body)

                Text(suggestion.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: suggestion.systemImage)
                .foregroundStyle(DesignSystem.Colors.accentDeep)
                .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                .background(DesignSystem.Colors.accentSoft.opacity(0.75), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                .accessibilityHidden(true)
        }
        .frame(minHeight: DesignSystem.HitTarget.minimum)
        .accessibilityElement(children: .combine)
    }
}

private struct RecipeSearchRecentRow: View {
    let query: String

    var body: some View {
        Label {
            Text(query)
                .font(.body)
        } icon: {
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
                .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                .accessibilityHidden(true)
        }
        .frame(minHeight: DesignSystem.HitTarget.minimum)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Recent search: \(query)"))
    }
}
