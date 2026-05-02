import SwiftUI

struct RecipesView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var recipeResultsState = RecipeResultsState()
    @State private var showSettings = false
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

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
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
            .onAppear {
                if env.configuration.openSettingsOnLaunch {
                    showSettings = true
                }
            }
        }
    }
}
