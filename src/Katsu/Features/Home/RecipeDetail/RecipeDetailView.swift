import SwiftUI

struct RecipeDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    let recipe: MealieRecipeSummary

    @State private var detail: MealieRecipeDetail?
    @State private var userRating: MealieUserRatingSummary?
    @State private var isLoading = false
    @State private var isUpdatingRating = false
    @State private var loadError: String?
    @State private var ratingError: String?
    @State private var showingCachedDetail = false
    @State private var isShowingMakingMode = false
    @State private var adjustedServings: Double?
    @Environment(\.bookFoldX) private var bookFoldX
    @State private var isTwoPage = false

    var body: some View {
        content
            .onTwoPageWidthChange { isTwoPage = $0 }
            .navigationTitle(detail?.displayName ?? recipe.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .task(id: recipe.slug) {
                await loadDetailIfNeeded()
            }
            .refreshable {
                await loadDetail()
            }
            .fullScreenCover(isPresented: $isShowingMakingMode) {
                if let detail {
                    RecipeMakingModeView(detail: detail, ingredientScaleFactor: ingredientScaleFactor(for: detail))
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if isTwoPage || bookFoldX != nil, let detail {
            // Two-page "cookbook spread": overview and ingredients on the left
            // page, steps on the right, split at the iPhone Duo hinge so each
            // side scrolls independently while cooking. Pages are exact halves
            // of the full screen width so the split lands on the hinge even
            // when system chrome (the unfolded Duo's status/tab column) insets
            // one edge. Each page adds that edge's safe-area inset to its outer
            // margin, and both pages get matching inner margins so content
            // keeps a clear gutter on both sides of the fold.
            GeometryReader { proxy in
                let insets = proxy.safeAreaInsets
                let pageWidth = (proxy.size.width + insets.leading + insets.trailing) / 2
                let margin = AdaptiveLayout.twoPageMargin

                HStack(spacing: 0) {
                    List {
                        offlineNotice
                        overviewSections(detail)
                        ingredientsSection(detail)
                    }
                    .contentMargins(.leading, margin + insets.leading, for: .scrollContent)
                    .contentMargins(.trailing, margin, for: .scrollContent)
                    .frame(width: pageWidth)

                    List {
                        instructionsSection(detail)
                        nutritionSection(detail)
                        if !detail.hasInstructions && !detail.hasVisibleNutrition {
                            ContentUnavailableView {
                                Label("No instructions", systemImage: "list.number")
                            } description: {
                                Text("This recipe doesn't have any steps yet.")
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .contentMargins(.leading, margin, for: .scrollContent)
                    .contentMargins(.trailing, margin + insets.trailing, for: .scrollContent)
                    .frame(width: pageWidth)
                }
                .overlay {
                    HStack { Divider() }
                        .ignoresSafeArea(edges: .bottom)
                }
                .ignoresSafeArea(.container, edges: .horizontal)
            }
            .background(DesignSystem.Colors.background)
        } else {
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
                    offlineNotice
                    overviewSections(detail)
                    ingredientsSection(detail)
                    instructionsSection(detail)
                    nutritionSection(detail)
                }
            }
        }
    }

    @ViewBuilder
    private var offlineNotice: some View {
        if showingCachedDetail {
            Section {
                Label("Showing offline copy", systemImage: "wifi.slash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Showing offline copy")
            }
        }
    }

    @ViewBuilder
    private func overviewSections(_ detail: MealieRecipeDetail) -> some View {
        RecipeHeroSection(
            detail: detail,
            adjustedServings: $adjustedServings,
            profileID: env.activeProfile?.id,
            serverURL: env.activeProfile?.serverURL,
            onStartMaking: { isShowingMakingMode = true }
        )

        if let recipeID = detail.recipeID {
            RecipeRatingSection(
                rating: userRating ?? MealieUserRatingSummary(recipeID: recipeID, rating: detail.rating, isFavorite: false),
                isUpdating: isUpdatingRating,
                errorMessage: ratingError,
                onToggleFavorite: { await updateFavorite(!$0.isFavorite) },
                onSetRating: { await updateRating($0) }
            )
        }
    }

    @ViewBuilder
    private func ingredientsSection(_ detail: MealieRecipeDetail) -> some View {
        if !detail.recipeIngredient.isEmpty {
            Section("Ingredients") {
                if detail.defaultServings != nil || detail.recipeYield?.nilIfBlank != nil {
                    RecipeServingsMetric(detail: detail, adjustedServings: $adjustedServings)
                }

                ForEach(detail.recipeIngredient) { ingredient in
                    RecipeIngredientRow(ingredient: ingredient, scaleFactor: ingredientScaleFactor(for: detail))
                }
            }
        }
    }

    @ViewBuilder
    private func instructionsSection(_ detail: MealieRecipeDetail) -> some View {
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
    }

    @ViewBuilder
    private func nutritionSection(_ detail: MealieRecipeDetail) -> some View {
        if detail.hasVisibleNutrition, let nutrition = detail.nutrition {
            Section("Nutrition") {
                ForEach(nutrition.entries) { entry in
                    LabeledContent(entry.label, value: entry.value)
                }
            }
        }
    }

    private func loadDetailIfNeeded() async {
        if detail == nil {
            await loadDetail()
        }
    }

    private func loadDetail() async {
        guard let profile = env.activeProfile else { return }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            var usedToken: MealieAuthToken?
            let rawData = try await env.withToken(for: profile) { token in
                usedToken = token
                return try await env.apiClient.fetchRecipeDetailData(
                    serverURL: profile.serverURL,
                    token: token,
                    slug: recipe.slug
                )
            }
            let loadedDetail = try JSONDecoder().decode(MealieRecipeDetail.self, from: rawData)
            detail = loadedDetail
            adjustedServings = loadedDetail.defaultServings
            if let recipeID = loadedDetail.recipeID, let usedToken {
                let loadedRating = try await env.apiClient.fetchUserRating(
                    serverURL: profile.serverURL,
                    token: usedToken,
                    recipeID: recipeID
                )
                userRating = loadedRating
                env.recordFavorite(loadedRating.isFavorite, recipeID: recipeID, profile: profile)
            }
            if let usedToken {
                await env.cacheLoadedRecipeOffline(loadedDetail, rawData: rawData, profile: profile, token: usedToken)
            }
            showingCachedDetail = false
            loadError = nil
            env.clearAuthenticationIssue(for: profile)
        } catch let error as AppError {
            if error == .unauthorized {
                env.markAuthenticationIssue(for: profile)
            } else if error != .offline {
                env.clearAuthenticationIssue(for: profile)
            }
            showCachedDetailOrError(error, profile: profile)
        } catch {
            loadError = error.localizedDescription
        }
    }

    private func showCachedDetailOrError(_ error: AppError, profile: ServerProfile) {
        if (error == .offline || error == .unauthorized),
           let cached = env.recipeOfflineCache.cachedRecipeDetail(profileID: profile.id, slug: recipe.slug) {
            detail = cached
            adjustedServings = cached.defaultServings
            showingCachedDetail = true
            loadError = nil
        } else {
            loadError = error.errorDescription
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
              let detail,
              let recipeID = detail.recipeID else {
            ratingError = AppError.unauthorized.errorDescription
            return
        }
        guard !isUpdatingRating else { return }
        isUpdatingRating = true
        defer { isUpdatingRating = false }

        do {
            try await env.withToken(for: profile) { token in
                let currentUser = try await env.resolveCurrentUser(profile: profile, token: token)
                try await env.apiClient.updateUserRating(
                    serverURL: profile.serverURL,
                    token: token,
                    userID: currentUser.id,
                    slug: detail.slug,
                    rating: rating,
                    isFavorite: isFavorite
                )
            }
            let current = userRating ?? MealieUserRatingSummary(recipeID: recipeID, rating: detail.rating, isFavorite: false)
            userRating = MealieUserRatingSummary(
                recipeID: recipeID,
                rating: rating ?? current.rating,
                isFavorite: isFavorite ?? current.isFavorite
            )
            if let isFavorite {
                env.recordFavorite(isFavorite, recipeID: recipeID, profile: profile)
            }
            ratingError = nil
        } catch let error as AppError {
            ratingError = error.errorDescription
        } catch {
            ratingError = error.localizedDescription
        }
    }

    private func ingredientScaleFactor(for detail: MealieRecipeDetail) -> Double {
        guard detail.canAdjustServings,
              let defaultServings = detail.defaultServings,
              defaultServings > 0,
              let adjustedServings,
              adjustedServings > 0 else {
            return 1
        }
        return adjustedServings / defaultServings
    }
}

private extension MealieRecipeDetail {
    var hasInstructions: Bool {
        !(recipeInstructions?.isEmpty ?? true)
    }

    var hasVisibleNutrition: Bool {
        guard let nutrition, settings?.showNutrition != false else { return false }
        return !nutrition.entries.isEmpty
    }
}
