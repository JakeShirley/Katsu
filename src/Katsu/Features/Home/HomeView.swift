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

private struct RecipesView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var showSettings = false
    @State private var showImportRecipe = false
    @State private var refreshTrigger = 0

    var body: some View {
        NavigationStack {
            RecipeResultsList(
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
                footer: "Meal plans and shopping lists are coming soon."
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

private struct RecipeSearchView: View {
    @State private var searchText = ""
    @State private var categoryFilter = ""
    @State private var tagFilter = ""
    @State private var householdFilter = ""
    @State private var appliedFilters = MealieRecipeFilters()

    private var draftFilters: MealieRecipeFilters {
        MealieRecipeFilters(
            search: searchText.trimmingCharacters(in: .whitespacesAndNewlines),
            categories: recipeFilterTokens(from: categoryFilter),
            tags: recipeFilterTokens(from: tagFilter),
            households: recipeFilterTokens(from: householdFilter)
        )
    }

    private var activeFilterCount: Int {
        let draft = draftFilters
        return (draft.search.isEmpty ? 0 : 1) + draft.categories.count + draft.tags.count + draft.households.count
    }

    var body: some View {
        NavigationStack {
            RecipeResultsList(
                filters: appliedFilters,
                refreshTrigger: 0,
                loadsWhenFiltersEmpty: false,
                allowsOfflineCache: false,
                resultsTitle: "Results",
                emptyStateTitle: "No matching recipes",
                emptyStateDescription: "Try a broader search or remove one of the filters.",
                emptyStateImage: "magnifyingglass",
                idleStateTitle: "Start searching",
                idleStateDescription: "Search by recipe name, then refine with Mealie category, tag, or household slugs.",
                idleStateImage: "sparkle.magnifyingglass",
                footer: nil
            ) {
                Section {
                    RecipeSearchHeroCard(activeFilterCount: activeFilterCount)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section("Refine Search") {
                    RecipeFilterField(
                        title: "Categories",
                        systemImage: "folder",
                        placeholder: "dinner, vegan, weeknight",
                        text: $categoryFilter,
                        onSubmit: applyFilters
                    )

                    RecipeFilterField(
                        title: "Tags",
                        systemImage: "tag",
                        placeholder: "quick, family, freezer",
                        text: $tagFilter,
                        onSubmit: applyFilters
                    )

                    RecipeFilterField(
                        title: "Households",
                        systemImage: "house",
                        placeholder: "main-household",
                        text: $householdFilter,
                        onSubmit: applyFilters
                    )

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Button {
                            applyFilters()
                        } label: {
                            Label("Search Now", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity, minHeight: DesignSystem.HitTarget.minimum)
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            clearFilters()
                        } label: {
                            Label("Clear", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity, minHeight: DesignSystem.HitTarget.minimum)
                        }
                        .buttonStyle(.bordered)
                        .disabled(draftFilters.isEmpty)
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search recipes"
            )
            .onSubmit(of: .search, applyFilters)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !draftFilters.isEmpty {
                        Button("Clear") {
                            clearFilters()
                        }
                    }
                }
            }
            .task(id: draftFilters) {
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    appliedFilters = draftFilters
                }
            }
        }
    }

    private func applyFilters() {
        appliedFilters = draftFilters
    }

    private func clearFilters() {
        searchText = ""
        categoryFilter = ""
        tagFilter = ""
        householdFilter = ""
        appliedFilters = MealieRecipeFilters()
    }
}

private struct RecipeResultsList<Header: View>: View {
    @EnvironmentObject private var env: AppEnvironment
    let filters: MealieRecipeFilters
    let refreshTrigger: Int
    let loadsWhenFiltersEmpty: Bool
    let allowsOfflineCache: Bool
    let resultsTitle: LocalizedStringKey?
    let emptyStateTitle: LocalizedStringKey
    let emptyStateDescription: LocalizedStringKey
    let emptyStateImage: String
    let idleStateTitle: LocalizedStringKey
    let idleStateDescription: LocalizedStringKey
    let idleStateImage: String
    let footer: LocalizedStringKey?
    let header: Header

    @State private var recipes: [MealieRecipeSummary] = []
    @State private var recipePage = 1
    @State private var recipeTotalPages: Int?
    @State private var recipeLoadError: String?
    @State private var isLoadingRecipes = false
    @State private var isLoadingMoreRecipes = false
    @State private var showingCachedRecipes = false

    private let recipesPerPage = 5
    private var taskID: RecipeResultsTaskID {
        RecipeResultsTaskID(profileID: env.activeProfile?.id, filters: filters, refreshTrigger: refreshTrigger)
    }

    init(
        filters: MealieRecipeFilters,
        refreshTrigger: Int,
        loadsWhenFiltersEmpty: Bool,
        allowsOfflineCache: Bool,
        resultsTitle: LocalizedStringKey?,
        emptyStateTitle: LocalizedStringKey,
        emptyStateDescription: LocalizedStringKey,
        emptyStateImage: String,
        idleStateTitle: LocalizedStringKey,
        idleStateDescription: LocalizedStringKey,
        idleStateImage: String,
        footer: LocalizedStringKey?,
        @ViewBuilder header: () -> Header
    ) {
        self.filters = filters
        self.refreshTrigger = refreshTrigger
        self.loadsWhenFiltersEmpty = loadsWhenFiltersEmpty
        self.allowsOfflineCache = allowsOfflineCache
        self.resultsTitle = resultsTitle
        self.emptyStateTitle = emptyStateTitle
        self.emptyStateDescription = emptyStateDescription
        self.emptyStateImage = emptyStateImage
        self.idleStateTitle = idleStateTitle
        self.idleStateDescription = idleStateDescription
        self.idleStateImage = idleStateImage
        self.footer = footer
        self.header = header()
    }

    var body: some View {
        List {
            header

            if let resultsTitle {
                Section(resultsTitle) {
                    resultsContent
                }
            } else {
                Section {
                    resultsContent
                }
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, DesignSystem.Spacing.sm, for: .scrollContent)
        .task(id: taskID) {
            await refreshRecipesForCurrentFilters()
        }
        .refreshable {
            await refreshRecipesForCurrentFilters(force: true)
        }
    }

    @ViewBuilder
    private var resultsContent: some View {
        if filters.isEmpty && !loadsWhenFiltersEmpty {
            ContentUnavailableView {
                Label {
                    Text(idleStateTitle)
                } icon: {
                    Image(systemName: idleStateImage)
                }
            } description: {
                Text(idleStateDescription)
            }
            .listRowBackground(Color.clear)
        } else if isLoadingRecipes && recipes.isEmpty {
            LoadingRecipeRow(title: "Loading recipes…")
        } else if let recipeLoadError, recipes.isEmpty {
            RecipeErrorRow(errorMessage: recipeLoadError) {
                Task { await refreshRecipes() }
            }
        } else if recipes.isEmpty {
            ContentUnavailableView {
                Label {
                    Text(emptyStateTitle)
                } icon: {
                    Image(systemName: emptyStateImage)
                }
            } description: {
                Text(emptyStateDescription)
            }
            .listRowBackground(Color.clear)
        } else {
            if showingCachedRecipes {
                Label("Showing offline recipes", systemImage: "wifi.slash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Showing offline recipes")
            }

            ForEach(recipes) { recipe in
                NavigationLink {
                    RecipeDetailView(recipe: recipe)
                } label: {
                    RecipeRow(recipe: recipe)
                }
                .onAppear {
                    if recipe.id == recipes.last?.id {
                        Task { await loadMoreRecipesIfNeeded() }
                    }
                }
            }

            if isLoadingMoreRecipes {
                LoadingRecipeRow(title: "Loading more recipes…")
            } else if recipeLoadError != nil {
                Button("Try Again") {
                    Task { await loadMoreRecipesIfNeeded(force: true) }
                }
                .frame(minHeight: DesignSystem.HitTarget.minimum)
            }
        }

        if let footer {
            Text(footer)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func refreshRecipesForCurrentFilters(force: Bool = false) async {
        guard loadsWhenFiltersEmpty || !filters.isEmpty else {
            resetResults()
            return
        }
        if force || recipes.isEmpty || !isLoadingRecipes {
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
        let filters = filters
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
                perPage: recipesPerPage,
                filters: filters
            )
            recipePage = page.page
            recipeTotalPages = page.totalPages ?? page.total.map { total in
                Int(ceil(Double(total) / Double(page.perPage)))
            }
            recipes = replacingExisting ? page.items : recipes + page.items
            showingCachedRecipes = false
            recipeLoadError = nil
        } catch let error as AppError {
            if error == .offline, replacingExisting, allowsOfflineCache, filters.isEmpty {
                let cachedRecipes = env.preferenceStore.cachedRecipeSummaries(profileID: profile.id)
                if !cachedRecipes.isEmpty {
                    recipes = cachedRecipes
                    recipePage = 1
                    recipeTotalPages = 1
                    showingCachedRecipes = true
                    recipeLoadError = nil
                } else {
                    recipeLoadError = error.errorDescription
                }
            } else {
                recipeLoadError = error.errorDescription
            }
        } catch {
            recipeLoadError = error.localizedDescription
        }
    }

    private func resetResults() {
        recipes = []
        recipePage = 1
        recipeTotalPages = nil
        recipeLoadError = nil
        isLoadingRecipes = false
        isLoadingMoreRecipes = false
        showingCachedRecipes = false
    }
}

private struct RecipeResultsTaskID: Equatable {
    let profileID: UUID?
    let filters: MealieRecipeFilters
    let refreshTrigger: Int
}

private struct RecipeSearchHeroCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let activeFilterCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(DesignSystem.Colors.accentDeep)
                .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                .background(DesignSystem.Colors.accentSoft.opacity(0.75), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Find exactly what sounds good")
                        .font(.headline)

                    Text("Search recipes by name, then refine with focused Mealie filters.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Label(String(localized: "Active filters: \(activeFilterCount)"), systemImage: "line.3.horizontal.decrease.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(.thinMaterial, in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(DesignSystem.Colors.separator.opacity(0.35))
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.top, DesignSystem.Spacing.sm)
        .padding(.bottom, DesignSystem.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Find exactly what sounds good. Search recipes by name, then refine with focused Mealie filters. Active filters: \(activeFilterCount)"))
        .animation(reduceMotion ? nil : DesignSystem.Motion.standard, value: activeFilterCount)
    }
}

private struct RecipeFilterField: View {
    let title: LocalizedStringKey
    let systemImage: String
    let placeholder: LocalizedStringKey
    @Binding var text: String
    let onSubmit: () -> Void

    private var tokens: [String] {
        recipeFilterTokens(from: text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
            }
            .font(.headline)

            TextField(placeholder, text: $text, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .lineLimit(1...2)
                .onSubmit(onSubmit)
                .accessibilityLabel(Text(title))

            if !tokens.isEmpty {
                FlowLayout(spacing: DesignSystem.Spacing.sm) {
                    ForEach(tokens, id: \.self) { token in
                        Text(token)
                            .font(.caption)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(DesignSystem.Colors.accentSoft, in: Capsule())
                            .foregroundStyle(DesignSystem.Colors.accentDeep)
                            .accessibilityLabel(token)
                    }
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }
}

private struct LoadingRecipeRow: View {
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ProgressView()
            Text(title)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
    }
}

private struct RecipeErrorRow: View {
    let errorMessage: String
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(errorMessage)
                .foregroundStyle(DesignSystem.Colors.destructive)
            Button("Try Again", action: onRetry)
                .frame(minHeight: DesignSystem.HitTarget.minimum)
        }
    }
}

private func recipeFilterTokens(from rawValue: String) -> [String] {
    rawValue
        .split { character in
            character == "," || character == " " || character == "\n"
        }
        .map(String.init)
}

private struct RecipeRow: View {
    let recipe: MealieRecipeSummary

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(systemName: "fork.knife")
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Colors.accentDeep)
                .frame(width: 36, height: 36)
                .background(DesignSystem.Colors.accentSoft.opacity(0.75), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                .accessibilityHidden(true)

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
                    Label(recipeYield, systemImage: "person.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
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

private struct ImportRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var env: AppEnvironment
    @State private var urlText = ""
    @State private var includeTags = true
    @State private var includeCategories = true
    @State private var isImporting = false
    @State private var errorMessage: String?

    let onImported: () async -> Void

    var body: some View {
        Form {
            Section {
                Text("Paste a recipe URL and Katsu will ask Mealie to import it.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Section("Recipe URL") {
                TextField("https://example.com/recipe", text: $urlText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .onSubmit(importRecipe)
                    .accessibilityLabel("Recipe URL")
            }

            Section("Import Options") {
                Toggle("Include tags", isOn: $includeTags)
                Toggle("Include categories", isOn: $includeCategories)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.destructive)
                }
            }

            Section {
                Button {
                    importRecipe()
                } label: {
                    if isImporting {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ProgressView()
                            Text("Importing recipe…")
                        }
                    } else {
                        Text("Import Recipe")
                    }
                }
                .disabled(isImporting || urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .frame(minHeight: DesignSystem.HitTarget.minimum)
            }
        }
        .navigationTitle("Import Recipe")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }

    private func importRecipe() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil, url.host != nil else {
            errorMessage = String(localized: "Enter a valid recipe URL.")
            return
        }
        guard let profile = env.activeProfile else { return }
        guard let token = try? env.credentialStore.loadToken(for: profile.id) else {
            errorMessage = AppError.unauthorized.errorDescription
            return
        }
        guard !isImporting else { return }

        errorMessage = nil
        isImporting = true
        Task {
            defer { isImporting = false }
            do {
                _ = try await env.apiClient.importRecipeFromURL(
                    serverURL: profile.serverURL,
                    token: token,
                    url: url,
                    includeTags: includeTags,
                    includeCategories: includeCategories
                )
                await onImported()
                dismiss()
            } catch let error as AppError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct RecipeDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    let recipe: MealieRecipeSummary

    @State private var detail: MealieRecipeDetail?
    @State private var userRating: MealieUserRatingSummary?
    @State private var isLoading = false
    @State private var isUpdatingRating = false
    @State private var loadError: String?
    @State private var ratingError: String?
    @State private var showingCachedDetail = false

    var body: some View {
        List {
            if isLoading && detail == nil {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ProgressView()
                    Text("Loading recipe…")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Loading recipe")
            } else if let loadError, detail == nil {
                Section {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text(loadError)
                            .foregroundStyle(DesignSystem.Colors.destructive)
                        Button("Try Again") {
                            Task { await loadDetail() }
                        }
                        .frame(minHeight: DesignSystem.HitTarget.minimum)
                    }
                }
            } else if let detail {
                if showingCachedDetail {
                    Section {
                        Label("Showing offline copy", systemImage: "wifi.slash")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Showing offline copy")
                    }
                }

                RecipeHeroSection(detail: detail, serverURL: env.activeProfile?.serverURL)

                if let recipeID = detail.recipeID {
                    RecipeRatingSection(
                        rating: userRating ?? MealieUserRatingSummary(recipeID: recipeID, rating: detail.rating, isFavorite: false),
                        isUpdating: isUpdatingRating,
                        errorMessage: ratingError,
                        onToggleFavorite: { await updateFavorite(!$0.isFavorite) },
                        onSetRating: { await updateRating($0) }
                    )
                }

                if !detail.recipeIngredient.isEmpty {
                    Section("Ingredients") {
                        ForEach(detail.recipeIngredient) { ingredient in
                            Text(ingredient.displayText)
                                .font(.body)
                                .accessibilityLabel(ingredient.displayText)
                        }
                    }
                }

                if let instructions = detail.recipeInstructions, !instructions.isEmpty {
                    Section("Instructions") {
                        ForEach(Array(instructions.enumerated()), id: \.element.id) { index, instruction in
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text(String(localized: "Step \(index + 1)"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(instruction.displayText)
                                    .font(.body)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(String(localized: "Step \(index + 1), \(instruction.displayText)"))
                        }
                    }
                }

                if let nutrition = detail.nutrition,
                   detail.settings?.showNutrition != false,
                   !nutrition.entries.isEmpty {
                    Section("Nutrition") {
                        ForEach(nutrition.entries) { entry in
                            LabeledContent(entry.label, value: entry.value)
                        }
                    }
                }
            }
        }
        .navigationTitle(detail?.displayName ?? recipe.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: recipe.slug) {
            await loadDetailIfNeeded()
        }
        .refreshable {
            await loadDetail()
        }
    }

    private func loadDetailIfNeeded() async {
        if detail == nil {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        guard let profile = env.activeProfile else { return }
        guard let token = try? env.credentialStore.loadToken(for: profile.id) else {
            loadError = AppError.unauthorized.errorDescription
            return
        }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let loadedDetail = try await env.apiClient.fetchRecipeDetail(
                serverURL: profile.serverURL,
                token: token,
                slug: recipe.slug
            )
            detail = loadedDetail
            if let recipeID = loadedDetail.recipeID {
                userRating = try await env.apiClient.fetchUserRating(
                    serverURL: profile.serverURL,
                    token: token,
                    recipeID: recipeID
                )
            }
            env.preferenceStore.cacheRecipeDetail(loadedDetail, profileID: profile.id)
            showingCachedDetail = false
            loadError = nil
        } catch let error as AppError {
            if error == .offline, let cached = env.preferenceStore.cachedRecipeDetail(profileID: profile.id, slug: recipe.slug) {
                detail = cached
                showingCachedDetail = true
                loadError = nil
            } else {
                loadError = error.errorDescription
            }
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func updateFavorite(_ isFavorite: Bool) async {
        await updateUserRating(rating: nil, isFavorite: isFavorite)
    }

    private func updateRating(_ rating: Double?) async {
        await updateUserRating(rating: rating, isFavorite: nil)
    }

    private func updateUserRating(rating: Double?, isFavorite: Bool?) async {
        guard let profile = env.activeProfile,
              let token = try? env.credentialStore.loadToken(for: profile.id),
              let detail,
              let recipeID = detail.recipeID else {
            ratingError = AppError.unauthorized.errorDescription
            return
        }
        guard !isUpdatingRating else { return }
        isUpdatingRating = true
        defer { isUpdatingRating = false }

        do {
            let currentUser = try await currentUser(profile: profile, token: token)
            try await env.apiClient.updateUserRating(
                serverURL: profile.serverURL,
                token: token,
                userID: currentUser.id,
                slug: detail.slug,
                rating: rating,
                isFavorite: isFavorite
            )
            let current = userRating ?? MealieUserRatingSummary(recipeID: recipeID, rating: detail.rating, isFavorite: false)
            userRating = MealieUserRatingSummary(
                recipeID: recipeID,
                rating: rating ?? current.rating,
                isFavorite: isFavorite ?? current.isFavorite
            )
            ratingError = nil
        } catch let error as AppError {
            ratingError = error.errorDescription
        } catch {
            ratingError = error.localizedDescription
        }
    }

    private func currentUser(profile: ServerProfile, token: MealieAuthToken) async throws -> MealieUser {
        if let currentUser = env.currentUser {
            return currentUser
        }
        let currentUser = try await env.apiClient.fetchCurrentUser(serverURL: profile.serverURL, token: token)
        env.currentUser = currentUser
        return currentUser
    }
}

private struct RecipeRatingSection: View {
    let rating: MealieUserRatingSummary
    let isUpdating: Bool
    let errorMessage: String?
    let onToggleFavorite: (MealieUserRatingSummary) async -> Void
    let onSetRating: (Double?) async -> Void

    var body: some View {
        Section("My Rating") {
            Button {
                Task { await onToggleFavorite(rating) }
            } label: {
                Label(rating.isFavorite ? "Remove Favorite" : "Add Favorite", systemImage: rating.isFavorite ? "heart.fill" : "heart")
                    .frame(maxWidth: .infinity, minHeight: DesignSystem.HitTarget.minimum, alignment: .leading)
            }
            .disabled(isUpdating)
            .accessibilityLabel(rating.isFavorite ? "Remove Favorite" : "Add Favorite")

            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        Task { await onSetRating(Double(value)) }
                    } label: {
                        Image(systemName: (rating.rating ?? 0) >= Double(value) ? "star.fill" : "star")
                            .font(.title3)
                            .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                    }
                    .buttonStyle(.plain)
                    .disabled(isUpdating)
                    .accessibilityLabel(String(localized: "Set rating to \(value) stars"))
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.destructive)
            }
        }
    }
}

private struct RecipeHeroSection: View {
    let detail: MealieRecipeDetail
    let serverURL: URL?

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                if let serverURL, let imageURL = detail.imageURL(serverURL: serverURL) {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, minHeight: 180)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
                        case .failure:
                            EmptyView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text(detail.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)

                    if let description = detail.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                RecipeMetadataView(detail: detail)

                let chips = (detail.recipeCategory ?? []) + (detail.tags ?? [])
                if !chips.isEmpty {
                    FlowLayout(spacing: DesignSystem.Spacing.sm) {
                        ForEach(chips) { chip in
                            Text(chip.name)
                                .font(.caption)
                                .padding(.horizontal, DesignSystem.Spacing.sm)
                                .padding(.vertical, DesignSystem.Spacing.xs)
                                .background(DesignSystem.Colors.accentSoft, in: Capsule())
                                .foregroundStyle(DesignSystem.Colors.accentDeep)
                                .accessibilityLabel(chip.name)
                        }
                    }
                }
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(heroAccessibilityLabel)
        }
    }

    private var heroAccessibilityLabel: String {
        [
            detail.displayName,
            detail.description,
            detail.recipeYield,
            detail.totalTime.map { String(localized: "Total time \($0)") },
            detail.rating.map { String(localized: "Rating \($0)") }
        ]
        .compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        .joined(separator: ", ")
    }
}

private struct RecipeMetadataView: View {
    let detail: MealieRecipeDetail

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            if let recipeYield = detail.recipeYield, !recipeYield.isEmpty {
                Label(recipeYield, systemImage: "fork.knife")
            }
            if let totalTime = detail.totalTime, !totalTime.isEmpty {
                Label(String(localized: "Total time: \(totalTime)"), systemImage: "clock")
            }
            if let prepTime = detail.prepTime, !prepTime.isEmpty {
                Label(String(localized: "Prep: \(prepTime)"), systemImage: "timer")
            }
            if let cookTime = detail.cookTime, !cookTime.isEmpty {
                Label(String(localized: "Cook: \(cookTime)"), systemImage: "flame")
            }
            if let rating = detail.rating {
                Label(String(localized: "Rating: \(rating, specifier: "%.1f")"), systemImage: "star.fill")
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, proposedWidth: proposal.width ?? 0)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if origin.x > bounds.minX && origin.x + size.width > bounds.maxX {
                origin.x = bounds.minX
                origin.y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: origin, proposal: ProposedViewSize(size))
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }

    private func rows(for subviews: Subviews, proposedWidth: CGFloat) -> [CGSize] {
        var rows: [CGSize] = []
        var current = CGSize.zero
        let maxWidth = proposedWidth > 0 ? proposedWidth : .greatestFiniteMagnitude

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if current.width > 0 && current.width + spacing + size.width > maxWidth {
                rows.append(current)
                current = size
            } else {
                current.width += current.width > 0 ? spacing + size.width : size.width
                current.height = max(current.height, size.height)
            }
        }
        if current.width > 0 || current.height > 0 {
            rows.append(current)
        }
        return rows
    }
}
