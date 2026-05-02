import SwiftUI

/// Home screen for the active Mealie server.
struct HomeView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var selectedTab: HomeTab = .recipes

    var body: some View {
        if env.activeProfile == nil && !env.hasServerProfiles {
            AddServerHomeView()
        } else {
            TabView(selection: $selectedTab) {
                RecipesView()
                    .tabItem {
                        Label("Recipes", systemImage: "book.closed")
                    }
                    .tag(HomeTab.recipes)

                RecipeSearchView()
                    .tabItem {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                    .tag(HomeTab.search)

                MealPlansView()
                    .tabItem {
                        Label("Meal Plans", systemImage: "calendar")
                    }
                    .tag(HomeTab.mealPlans)

                ShoppingListsView()
                    .tabItem {
                        Label("Shopping", systemImage: "cart")
                    }
                    .tag(HomeTab.shopping)

                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(HomeTab.settings)
            }
            .onAppear {
                if env.configuration.openSettingsOnLaunch {
                    selectedTab = .settings
                }
            }
        }
    }
}

private enum HomeTab: Hashable {
    case recipes
    case search
    case mealPlans
    case shopping
    case settings
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
