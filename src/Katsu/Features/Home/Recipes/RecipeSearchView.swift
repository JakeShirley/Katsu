import SwiftUI

struct RecipeSearchView: View {
    @StateObject private var recipeResultsState = RecipeResultsState()
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
                state: recipeResultsState,
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

func recipeFilterTokens(from rawValue: String) -> [String] {
    rawValue
        .split { character in
            character == "," || character == " " || character == "\n"
        }
        .map(String.init)
}
