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
    @Environment(\.deviceFold) private var deviceFold
    @Environment(\.isSplitViewSidebarVisible) private var isSplitViewSidebarVisible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var geometry: DetailGeometry?

    private let sectionSpacing = DesignSystem.Spacing.xl

    var body: some View {
        content
            .onGeometryChange(for: DetailGeometry.self) { proxy in
                DetailGeometry(
                    size: proxy.size,
                    safeAreaInsets: proxy.safeAreaInsets,
                    globalMinX: proxy.frame(in: .global).minX
                )
            } action: { newGeometry in
                updateGeometry(newGeometry)
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

    /// The detail view's size and safe-area insets, used to size the
    /// spread's pages, plus its global position for aligning them with a
    /// fold. Sizes come from layout rather than the global frame, which can
    /// be stale after a rotation.
    private struct DetailGeometry: Equatable {
        var size: CGSize
        var safeAreaInsets: EdgeInsets
        var globalMinX: CGFloat
    }

    private var isTwoPage: Bool {
        guard !isSplitViewSidebarVisible else { return false }
        return geometry.map { AdaptiveLayout.isTwoPage(width: $0.size.width) } ?? false
    }

    /// Animates the pages into their new arrangement when the width crosses
    /// the two-page breakpoint, such as when a split view's sidebar slides in
    /// or out. Other size changes (and the first measurement) apply
    /// immediately.
    private func updateGeometry(_ newGeometry: DetailGeometry) {
        let nextIsTwoPage = !isSplitViewSidebarVisible
            && AdaptiveLayout.isTwoPage(width: newGeometry.size.width)
        let crossesBreakpoint = geometry != nil && nextIsTwoPage != isTwoPage
        if crossesBreakpoint, !reduceMotion {
            withAnimation(DesignSystem.Motion.emphasized) {
                geometry = newGeometry
            }
        } else {
            geometry = newGeometry
        }
    }

    /// Column widths and gutter for the two-page spread. The pages split at a
    /// vertical fold (iPhone Duo in book posture) when one crosses the view,
    /// keeping clear of its reserved region. On a full-screen unfolded display
    /// without a split-view sidebar, the split aligns with the screen center
    /// across small hardware safe-area insets; inside a split-view detail
    /// column (such as iPad) it splits evenly across the detail column itself.
    private func spreadColumns(in geometry: DetailGeometry) -> (leading: CGFloat, trailing: CGFloat, gutter: CGFloat) {
        let width = geometry.size.width
        let insets = geometry.safeAreaInsets
        let margin = AdaptiveLayout.twoPageMargin
        let minimumPage = AdaptiveLayout.twoPageMinimumWidth / 3

        // Positions are local to the view's safe area.
        var splitX = width / 2
        var innerMargin = margin
        if let fold = deviceFold, fold.orientation == .vertical {
            let foldX = fold.frame.midX - geometry.globalMinX
            if foldX >= minimumPage, width - foldX >= minimumPage {
                splitX = foldX
                innerMargin = max(fold.frame.width / 2, margin)
            }
        } else if geometry.globalMinX <= 1, max(insets.leading, insets.trailing) < 120 {
            let centeredSplitX = (width + insets.trailing - insets.leading) / 2
            if centeredSplitX >= minimumPage, width - centeredSplitX >= minimumPage {
                splitX = centeredSplitX
            }
        }

        let leading = max(0, splitX - innerMargin - margin)
        let trailing = max(0, width - margin - (splitX + innerMargin))
        return (leading, trailing, innerMargin * 2)
    }

    @ViewBuilder
    private var content: some View {
        if let detail {
            ScrollView {
                pages(detail)
                    .padding(.horizontal, AdaptiveLayout.twoPageMargin)
                    .padding(.vertical, DesignSystem.Spacing.lg)
            }
            // The pages' widths are derived from this view's measured size,
            // so its ideal width must not come from them; otherwise a
            // container that sizes detail to fit (such as a split view
            // collapsing on rotation) would keep the old width.
            .frame(minWidth: 0, idealWidth: 0, maxWidth: .infinity)
            .background(DesignSystem.Colors.background)
        } else {
            List {
                if isLoading {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ProgressView()
                        Text("Loading recipe…")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Loading recipe")
                } else if let loadError {
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
                }
            }
        }
    }

    /// The recipe as two "pages": overview and ingredients, then steps and
    /// nutrition. On wide layouts they sit side by side as a cookbook spread;
    /// otherwise the second page follows the first. Switching between the
    /// two arrangements with `AnyLayout` keeps every section's identity, so
    /// sections glide to their new positions instead of being rebuilt.
    private func pages(_ detail: MealieRecipeDetail) -> some View {
        let columns = isTwoPage ? geometry.map(spreadColumns(in:)) : nil
        let layout = columns.map { AnyLayout(HStackLayout(alignment: .top, spacing: $0.gutter)) }
            ?? AnyLayout(VStackLayout(spacing: sectionSpacing))

        return layout {
            VStack(spacing: sectionSpacing) {
                offlineNotice
                overviewSections(detail)
                ingredientsSection(detail)
            }
            .frame(width: columns?.leading)

            VStack(spacing: sectionSpacing) {
                instructionsSection(detail)
                nutritionSection(detail)
                if columns != nil, !detail.hasInstructions, !detail.hasVisibleNutrition {
                    ContentUnavailableView {
                        Label("No instructions", systemImage: "list.number")
                    } description: {
                        Text("This recipe doesn't have any steps yet.")
                    }
                }
            }
            .frame(width: columns?.trailing)
        }
        .frame(maxWidth: isTwoPage ? .infinity : AdaptiveLayout.readableContentMaxWidth)
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : DesignSystem.Motion.emphasized, value: isTwoPage)
    }

    @ViewBuilder
    private var offlineNotice: some View {
        if showingCachedDetail {
            RecipeDetailCard {
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
            RecipeDetailCard(title: "Ingredients") {
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
            RecipeDetailCard(title: "Instructions") {
                ForEach(Array(instructions.enumerated()), id: \.element.id) { index, instruction in
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(String(localized: "Step \(index + 1)"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(instruction.displayText)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
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
            RecipeDetailCard(title: "Nutrition") {
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
