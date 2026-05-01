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
    @State private var showImportRecipe = false
    @State private var recipes: [MealieRecipeSummary] = []
    @State private var recipePage = 1
    @State private var recipeTotalPages: Int?
    @State private var recipeLoadError: String?
    @State private var isLoadingRecipes = false
    @State private var isLoadingMoreRecipes = false
    @State private var searchText = ""
    @State private var categoryFilter = ""
    @State private var tagFilter = ""
    @State private var householdFilter = ""

    private let recipesPerPage = 5
    private var filters: MealieRecipeFilters {
        MealieRecipeFilters(
            search: searchText,
            categories: tokens(from: categoryFilter),
            tags: tokens(from: tagFilter),
            households: tokens(from: householdFilter)
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Filter Recipes") {
                    TextField("Search recipes", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await refreshRecipes() } }
                        .accessibilityLabel("Search recipes")

                    TextField("Category slugs", text: $categoryFilter)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await refreshRecipes() } }
                        .accessibilityLabel("Category slugs")

                    TextField("Tag slugs", text: $tagFilter)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await refreshRecipes() } }
                        .accessibilityLabel("Tag slugs")

                    TextField("Household slugs", text: $householdFilter)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await refreshRecipes() } }
                        .accessibilityLabel("Household slugs")

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Button("Apply Filters") {
                            Task { await refreshRecipes() }
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: DesignSystem.HitTarget.minimum)

                        Button("Clear") {
                            clearFilters()
                        }
                        .disabled(filters.isEmpty)
                        .frame(minHeight: DesignSystem.HitTarget.minimum)
                    }
                }

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
                        await refreshRecipes()
                    }
                }
            }
            .task(id: env.activeProfile?.id) {
                await refreshRecipesIfNeeded()
            }
            .onChange(of: filters) { _, _ in
                Task { await refreshRecipes() }
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
            recipeLoadError = nil
        } catch let error as AppError {
            recipeLoadError = error.errorDescription
        } catch {
            recipeLoadError = error.localizedDescription
        }
    }

    private func clearFilters() {
        searchText = ""
        categoryFilter = ""
        tagFilter = ""
        householdFilter = ""
    }

    private func tokens(from rawValue: String) -> [String] {
        rawValue
            .split { character in
                character == "," || character == " " || character == "\n"
            }
            .map(String.init)
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
    @State private var isLoading = false
    @State private var loadError: String?

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
                RecipeHeroSection(detail: detail, serverURL: env.activeProfile?.serverURL)

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
            detail = try await env.apiClient.fetchRecipeDetail(
                serverURL: profile.serverURL,
                token: token,
                slug: recipe.slug
            )
            loadError = nil
        } catch let error as AppError {
            loadError = error.errorDescription
        } catch {
            loadError = error.localizedDescription
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
