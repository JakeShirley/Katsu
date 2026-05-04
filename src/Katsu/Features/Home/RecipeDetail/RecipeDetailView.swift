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
        .fullScreenCover(isPresented: $isShowingMakingMode) {
            if let detail {
                RecipeMakingModeView(detail: detail, ingredientScaleFactor: ingredientScaleFactor(for: detail))
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
        guard let token = try? env.credentialStore.loadToken(for: profile.id) else {
            env.markAuthenticationIssue(for: profile)
            showCachedDetailOrError(AppError.unauthorized, profile: profile)
            return
        }
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let rawData = try await env.apiClient.fetchRecipeDetailData(
                serverURL: profile.serverURL,
                token: token,
                slug: recipe.slug
            )
            let loadedDetail = try JSONDecoder().decode(MealieRecipeDetail.self, from: rawData)
            detail = loadedDetail
            adjustedServings = loadedDetail.defaultServings
            if let recipeID = loadedDetail.recipeID {
                userRating = try await env.apiClient.fetchUserRating(
                    serverURL: profile.serverURL,
                    token: token,
                    recipeID: recipeID
                )
            }
            await env.cacheLoadedRecipeOffline(loadedDetail, rawData: rawData, profile: profile, token: token)
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
