import SwiftUI

struct ShoppingListDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let summary: MealieShoppingListSummary

    @State private var detail: MealieShoppingListDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var actionErrorMessage: String?
    @State private var savingItemIDs: Set<String> = []
    @State private var fadingItemIDs: Set<String> = []
    @State private var isSavingNewItem = false
    @State private var addDraft: ShoppingItemAddDraft?

    private var itemUpdateAnimation: Animation? {
        reduceMotion ? nil : DesignSystem.Motion.standard
    }

    var body: some View {
        List {
            if isLoading && detail == nil {
                ShoppingLoadingRow(title: "Loading shopping list...")
            } else if let errorMessage, detail == nil {
                Section {
                    ShoppingErrorRow(errorMessage: errorMessage) {
                        Task { await loadDetail() }
                    }
                }
            } else if let detail {
                Section {
                    ShoppingListStatusRow(detail: detail)
                }

                Section("Items") {
                    if detail.listItems.isEmpty {
                        ContentUnavailableView {
                            Label("No shopping items", systemImage: "cart")
                        } description: {
                            Text("Items added in Mealie will appear here.")
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(detail.listItems.sorted(by: shoppingItemSort)) { item in
                            ShoppingItemToggleRow(
                                item: item,
                                isSaving: savingItemIDs.contains(item.id),
                                isFading: fadingItemIDs.contains(item.id)
                            ) {
                                Task { await toggle(item) }
                            }
                        }
                    }
                }

                if let actionErrorMessage {
                    Section {
                        Text(actionErrorMessage)
                            .font(.subheadline)
                            .foregroundStyle(DesignSystem.Colors.destructive)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(detail?.displayName ?? summary.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { addToolbarItem }
        .sheet(item: $addDraft) { draft in
            NavigationStack {
                ShoppingItemAddView(
                    draft: draft,
                    isSaving: isSavingNewItem,
                    loadRecipes: loadRecipes,
                    onSave: saveNewItem
                )
            }
        }
        .task(id: summary.id) {
            await loadDetailIfNeeded()
        }
        .refreshable {
            await loadDetail()
        }
    }

    private var addToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                addDraft = ShoppingItemAddDraft(listID: summary.id, nextPosition: (detail?.listItems.map(\.position).max() ?? -1) + 1)
            } label: {
                Label("Add Shopping Item", systemImage: "plus")
            }
            .disabled(detail == nil)
            .accessibilityLabel("Add Shopping Item")
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
        errorMessage = nil
        defer { isLoading = false }

        do {
            detail = try await env.withToken(for: profile) { token in
                try await env.apiClient.fetchShoppingListDetail(
                    serverURL: profile.serverURL,
                    token: token,
                    listID: summary.id
                )
            }
            actionErrorMessage = nil
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadRecipes() async throws -> [MealieRecipeSummary] {
        guard let profile = env.activeProfile else { return [] }
        let page = try await env.withToken(for: profile) { token in
            try await env.apiClient.fetchRecipes(
                serverURL: profile.serverURL,
                token: token,
                page: 1,
                perPage: 100,
                filters: MealieRecipeFilters()
            )
        }
        return page.items
    }

    private func saveNewItem(_ value: ShoppingItemAddValue) async {
        guard let profile = env.activeProfile else { return }
        guard !isSavingNewItem else { return }

        isSavingNewItem = true
        actionErrorMessage = nil
        defer { isSavingNewItem = false }

        do {
            switch value.mode {
            case .manual:
                let collection = try await env.withToken(for: profile) { token in
                    try await env.apiClient.createShoppingListItem(
                        serverURL: profile.serverURL,
                        token: token,
                        item: MealieShoppingListItemCreate(
                            shoppingListID: summary.id,
                            checked: false,
                            quantity: value.quantity,
                            note: value.note,
                            display: value.display,
                            position: value.position,
                            recipeReferences: []
                        )
                    )
                }
                applyDetailUpdate(detail?.applying(collection))
            case .recipe:
                guard let recipeID = value.recipeID else { return }
                let updatedDetail = try await env.withToken(for: profile) { token in
                    try await env.apiClient.addRecipeToShoppingList(
                        serverURL: profile.serverURL,
                        token: token,
                        listID: summary.id,
                        recipeID: recipeID,
                        add: MealieShoppingRecipeAdd(recipeIncrementQuantity: value.recipeQuantity)
                    )
                }
                applyDetailUpdate(updatedDetail)
            }
            addDraft = nil
        } catch let error as AppError {
            actionErrorMessage = error.errorDescription
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    private func toggle(_ item: MealieShoppingListItem) async {
        guard !savingItemIDs.contains(item.id) else { return }
        guard let profile = env.activeProfile else { return }

        let originalDetail = detail
        let optimisticItem = item.withChecked(!item.checked)
        if optimisticItem.checked && !reduceMotion {
            withAnimation(DesignSystem.Motion.standard) {
                _ = fadingItemIDs.insert(item.id)
            }
            try? await Task.sleep(nanoseconds: 180_000_000)
        }
        applyDetailUpdate(detail?.replacingItem(optimisticItem))
        savingItemIDs.insert(item.id)
        errorMessage = nil
        defer {
            savingItemIDs.remove(item.id)
            fadingItemIDs.remove(item.id)
        }

        do {
            let collection = try await env.withToken(for: profile) { token in
                try await env.apiClient.updateShoppingListItem(
                    serverURL: profile.serverURL,
                    token: token,
                    itemID: item.id,
                    item: MealieShoppingListItemUpdate(item: optimisticItem)
                )
            }
            if let detail {
                applyDetailUpdate(detail.applying(collection))
            }
        } catch let error as AppError {
            applyDetailUpdate(originalDetail)
            errorMessage = error.errorDescription
        } catch {
            applyDetailUpdate(originalDetail)
            errorMessage = error.localizedDescription
        }
    }

    private func applyDetailUpdate(_ updatedDetail: MealieShoppingListDetail?) {
        if let itemUpdateAnimation {
            withAnimation(itemUpdateAnimation) {
                detail = updatedDetail
            }
        } else {
            detail = updatedDetail
        }
    }
}
