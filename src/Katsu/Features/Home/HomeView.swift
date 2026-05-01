import SwiftUI

/// Home screen for the active Mealie server.
struct HomeView: View {
    var body: some View {
        TabView {
            HomeDashboardView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            RecipesView()
                .tabItem {
                    Label("Recipes", systemImage: "book.closed")
                }
        }
    }
}

private struct HomeDashboardView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var showSettings = false
    @State private var loadError: String?
    @State private var isLoadingUser = false

    var body: some View {
        NavigationStack {
            List {
                if let profile = env.activeProfile {
                    Section("Connected Server") {
                        LabeledContent("Name", value: profile.displayName)
                        LabeledContent("URL", value: profile.serverURL.absoluteString)
                        if let version = profile.version {
                            LabeledContent("Version", value: version)
                        }
                    }
                }

                Section("Signed in as") {
                    if let user = env.currentUser {
                        LabeledContent("Username", value: user.username)
                        if let name = user.fullName, !name.isEmpty {
                            LabeledContent("Name", value: name)
                        }
                        if let email = user.email {
                            LabeledContent("Email", value: email)
                        }
                        if user.admin == true {
                            Label("Administrator", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(DesignSystem.accent)
                        }
                    } else if isLoadingUser {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Loading account…")
                        }
                    } else if let loadError {
                        Text(loadError).foregroundStyle(.red)
                    } else {
                        Text("Not loaded yet").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Katsu")
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
                await refreshUserIfNeeded()
            }
            .refreshable {
                await refreshUser(force: true)
            }
            .onAppear {
                if env.configuration.openSettingsOnLaunch {
                    showSettings = true
                }
            }
        }
    }

    private func refreshUserIfNeeded() async {
        if env.currentUser == nil {
            await refreshUser(force: true)
        }
    }

    private func refreshUser(force: Bool) async {
        guard let profile = env.activeProfile else { return }
        guard let token = try? env.credentialStore.loadToken(for: profile.id) else {
            loadError = AppError.unauthorized.errorDescription
            return
        }
        isLoadingUser = true
        defer { isLoadingUser = false }
        do {
            let user = try await env.apiClient.fetchCurrentUser(
                serverURL: profile.serverURL,
                token: token
            )
            env.currentUser = user
            loadError = nil
        } catch let error as AppError {
            loadError = error.errorDescription
        } catch {
            loadError = error.localizedDescription
        }
    }
}

private struct RecipesView: View {
    @EnvironmentObject private var env: AppEnvironment
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
            .task(id: env.activeProfile?.id) {
                await refreshRecipesIfNeeded()
            }
            .refreshable {
                await refreshRecipes()
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
