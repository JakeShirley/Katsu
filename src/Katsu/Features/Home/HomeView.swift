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
                    Tab(value: tab) {
                        tab.destination
                    } label: {
                        tab.label
                    }
                    .badge(tab == .settings && env.activeProfileNeedsSignIn ? Text(verbatim: "!") : nil)
                }
            }
            .tabViewStyle(.tabBarOnly)
            .tabBarMinimizeBehavior(.onScrollDown)
            .onChange(of: enabledTabs) { _, tabs in
                if !tabs.contains(selectedTab) {
                    selectedTab = tabs.first ?? .settings
                }
            }
            .task(id: env.activeProfile?.id) {
                await env.refreshActiveServerInfo()
            }
            .onAppear {
                #if DEBUG
                if env.configuration.openSettingsOnLaunch {
                    selectedTab = .settings
                    return
                }
                #endif
                if !enabledTabs.contains(selectedTab) {
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
        case .mealPlans:
            "Meal Plans"
        case .search:
            "Search"
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
        case .mealPlans:
            "calendar"
        case .search:
            "magnifyingglass"
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
        case .mealPlans:
            MealPlansView()
        case .search:
            RecipesView()
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
        case .mealPlans:
            String(localized: "Meal Plans")
        case .search:
            String(localized: "Search")
        }
    }
}

private struct AddServerHomeView: View {
    @State private var showOnboarding = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
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
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Add a Mealie server. Connect Katsu to your Mealie server, then sign in to browse your recipes.")

                    Button {
                        showOnboarding = true
                    } label: {
                        Label("Add Server", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: DesignSystem.HitTarget.minimum)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(DesignSystem.Spacing.xl)
                .background(
                    DesignSystem.Colors.surface,
                    in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg * 1.5, style: .continuous)
                )
                .readableContentWidth(AdaptiveLayout.formMaxWidth)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Katsu")
            .navigationDestination(isPresented: $showOnboarding) {
                OnboardingFlowView()
            }
        }
    }
}
