import SwiftUI

struct RecipesView: View {
    @StateObject private var recipeResultsState = RecipeResultsState()
    @State private var showImportRecipe = false
    @State private var refreshTrigger = 0

    var body: some View {
        NavigationStack {
            RecipeResultsList(
                state: recipeResultsState,
                filters: MealieRecipeFilters(),
                refreshTrigger: refreshTrigger,
                loadsWhenFiltersEmpty: true,
                allowsOfflineCache: true,
                resultsTitle: nil,
                emptyStateTitle: "No recipes yet",
                emptyStateDescription: "Imported and saved recipes will appear here.",
                emptyStateImage: "book.closed",
                idleStateTitle: "No recipes yet",
                idleStateDescription: "Imported and saved recipes will appear here.",
                idleStateImage: "book.closed",
                footer: "Meal plans and shopping lists are coming soon.",
                presentation: .cardFeed
            ) {
                EmptyView()
            }
            .navigationTitle("Recipes")
            .navigationBarTitleDisplayMode(.inline)
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
}
