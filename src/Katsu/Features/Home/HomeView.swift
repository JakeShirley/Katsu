import SwiftUI

/// Home screen for the active Mealie server.
struct HomeView: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        if env.activeProfile == nil && !env.hasServerProfiles {
            AddServerHomeView()
        } else {
            TabView {
                RecipesView()
                    .tabItem {
                        Label("Recipes", systemImage: "book.closed")
                    }

                RecipeSearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }

                MealPlansView()
                    .tabItem {
                        Label("Meal Plans", systemImage: "calendar")
                    }

                ShoppingListsView()
                    .tabItem {
                        Label("Shopping", systemImage: "cart")
                    }
            }
        }
    }
}

private struct AddServerHomeView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        Image(systemName: "server.rack")
                            .font(.largeTitle)
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Add a Mealie server")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Connect Katsu to your Mealie server, then sign in to browse your recipes.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        NavigationLink {
                            OnboardingFlowView()
                        } label: {
                            Label("Add Server", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity, minHeight: DesignSystem.HitTarget.minimum)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Add a Mealie server. Connect Katsu to your Mealie server, then sign in to browse your recipes.")
                }
            }
            .navigationTitle("Katsu")
        }
    }
}
