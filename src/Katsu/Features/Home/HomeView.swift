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

private struct RecipesView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var showSettings = false
    @State private var recipes: [MealieRecipeSummary] = []
    @State private var recipePage = 1
    @State private var recipeTotalPages: Int?
    @State private var recipeLoadError: String?
    @State private var isLoadingRecipes = false
    @State private var isLoadingMoreRecipes = false

    private let recipesPerPage = 5

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if isLoadingRecipes && recipes.isEmpty {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ProgressView()
                            Text("Loading recipes…")
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Loading recipes")
                    } else if let recipeLoadError, recipes.isEmpty {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text(recipeLoadError)
                                .foregroundStyle(DesignSystem.Colors.destructive)
                            Button("Try Again") {
                                Task { await refreshRecipes() }
                            }
                            .frame(minHeight: DesignSystem.HitTarget.minimum)
                        }
                    } else if recipes.isEmpty {
                        Text("No recipes yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recipes) { recipe in
                            RecipeRow(recipe: recipe)
                                .onAppear {
                                    if recipe.id == recipes.last?.id {
                                        Task { await loadMoreRecipesIfNeeded() }
                                    }
                                }
                        }

                        if isLoadingMoreRecipes {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                ProgressView()
                                Text("Loading more recipes…")
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Loading more recipes")
                        } else if recipeLoadError != nil {
                            Button("Try Again") {
                                Task { await loadMoreRecipesIfNeeded(force: true) }
                            }
                            .frame(minHeight: DesignSystem.HitTarget.minimum)
                        }
                    }

                    Text("Meal plans and shopping lists are coming soon.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Recipes")
            .toolbar {
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
            .task(id: env.activeProfile?.id) {
                await refreshRecipesIfNeeded()
            }
            .refreshable {
                await refreshRecipes()
            }
            .onAppear {
                if env.configuration.openSettingsOnLaunch {
                    showSettings = true
                }
            }
        }
    }

    private func refreshRecipesIfNeeded() async {
        if recipes.isEmpty {
            await refreshRecipes()
        }
    }

    private func refreshRecipes() async {
        await loadRecipes(page: 1, replacingExisting: true)
    }

    private func loadMoreRecipesIfNeeded(force: Bool = false) async {
        guard force || hasMoreRecipes else { return }
        await loadRecipes(page: recipePage + 1, replacingExisting: false)
    }

    private var hasMoreRecipes: Bool {
        if let recipeTotalPages {
            return recipePage < recipeTotalPages
        }
        return !recipes.isEmpty
    }

    private func loadRecipes(page: Int, replacingExisting: Bool) async {
        guard let profile = env.activeProfile else { return }
        guard let token = try? env.credentialStore.loadToken(for: profile.id) else {
            recipeLoadError = AppError.unauthorized.errorDescription
            return
        }
        if replacingExisting {
            guard !isLoadingRecipes else { return }
            isLoadingRecipes = true
        } else {
            guard !isLoadingMoreRecipes else { return }
            isLoadingMoreRecipes = true
        }
        defer {
            isLoadingRecipes = false
            isLoadingMoreRecipes = false
        }

        do {
            let page = try await env.apiClient.fetchRecipes(
                serverURL: profile.serverURL,
                token: token,
                page: page,
                perPage: recipesPerPage
            )
            recipePage = page.page
            recipeTotalPages = page.totalPages ?? page.total.map { total in
                Int(ceil(Double(total) / Double(page.perPage)))
            }
            recipes = replacingExisting ? page.items : recipes + page.items
            recipeLoadError = nil
        } catch let error as AppError {
            recipeLoadError = error.errorDescription
        } catch {
            recipeLoadError = error.localizedDescription
        }
    }
}

private struct RecipeRow: View {
    let recipe: MealieRecipeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(recipe.displayName)
                .font(.headline)
                .foregroundStyle(.primary)

            if let description = recipe.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let recipeYield = recipe.recipeYield, !recipeYield.isEmpty {
                Label(recipeYield, systemImage: "fork.knife")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        [recipe.displayName, recipe.description, recipe.recipeYield]
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .joined(separator: ", ")
    }
}
