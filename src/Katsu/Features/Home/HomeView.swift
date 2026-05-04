import SwiftUI

/// Home screen for the active Mealie server.
struct HomeView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var selectedTab: HomeTab = .recipes

    private var enabledTabs: [HomeTab] {
        env.tabLayout.filter(\.isEnabled).map(\.tab)
    }

    var body: some View {
        if env.activeProfile == nil && !env.hasServerProfiles {
            AddServerHomeView()
        } else {
            TabView(selection: $selectedTab) {
                ForEach(enabledTabs) { tab in
                    tab.destination
                        .tabItem { tab.label }
                        .badge(tab == .settings && env.activeProfileNeedsSignIn ? Text(verbatim: "!") : nil)
                        .tag(tab)
                }
            }
            .onChange(of: enabledTabs) { _, tabs in
                if !tabs.contains(selectedTab) {
                    selectedTab = tabs.first ?? .settings
                }
            }
            .onAppear {
                if env.configuration.openSettingsOnLaunch {
                    selectedTab = .settings
                } else if !enabledTabs.contains(selectedTab) {
                    selectedTab = enabledTabs.first ?? .settings
                }
            }
        }
    }
}

extension HomeTab {
    var title: LocalizedStringKey {
        switch self {
        case .recipes:
            "Recipes"
        case .shopping:
            "Shopping"
        case .settings:
            "Settings"
        case .search:
            "Search"
        case .mealPlans:
            "Meal Plans"
        }
    }

    var systemImage: String {
        switch self {
        case .recipes:
            "book.closed"
        case .shopping:
            "cart"
        case .settings:
            "gearshape"
        case .search:
            "magnifyingglass"
        case .mealPlans:
            "calendar"
        }
    }

    var label: some View {
        Label(title, systemImage: systemImage)
    }

    @ViewBuilder var destination: some View {
        switch self {
        case .recipes:
            RecipesView()
        case .shopping:
            ShoppingListsView()
        case .settings:
            NavigationStack {
                SettingsView()
            }
        case .search:
            RecipeSearchView()
        case .mealPlans:
            MealPlansView()
        }
    }

    var localizedTitle: String {
        switch self {
        case .recipes:
            String(localized: "Recipes")
        case .shopping:
            String(localized: "Shopping")
        case .settings:
            String(localized: "Settings")
        case .search:
            String(localized: "Search")
        case .mealPlans:
            String(localized: "Meal Plans")
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
