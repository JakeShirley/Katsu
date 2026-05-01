import SwiftUI

struct ShoppingListsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var lists: [MealieShoppingListSummary] = []
    @State private var page = 1
    @State private var totalPages: Int?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?

    private let listsPerPage = 20

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ShoppingListsHeroCard(listCount: lists.count)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section("Lists") {
                    if isLoading && lists.isEmpty {
                        ShoppingLoadingRow(title: "Loading shopping lists...")
                    } else if let errorMessage, lists.isEmpty {
                        ShoppingErrorRow(errorMessage: errorMessage) {
                            Task { await loadLists() }
                        }
                    } else if lists.isEmpty {
                        ContentUnavailableView {
                            Label("No shopping lists", systemImage: "cart")
                        } description: {
                            Text("Create a shopping list in Mealie and it will appear here.")
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(lists) { list in
                            NavigationLink {
                                ShoppingListDetailView(summary: list)
                            } label: {
                                ShoppingListRow(list: list)
                            }
                            .onAppear {
                                if list.id == lists.last?.id {
                                    Task { await loadMoreListsIfNeeded() }
                                }
                            }
                        }

                        if isLoadingMore {
                            ShoppingLoadingRow(title: "Loading more shopping lists...")
                        } else if errorMessage != nil {
                            Button("Try Again") {
                                Task { await loadMoreListsIfNeeded(force: true) }
                            }
                            .frame(minHeight: DesignSystem.HitTarget.minimum)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Shopping Lists")
            .task(id: env.activeProfile?.id) {
                await loadListsIfNeeded()
            }
            .refreshable {
                await loadLists()
            }
        }
    }

    private var hasMoreLists: Bool {
        if let totalPages {
            return page < totalPages
        }
        return !lists.isEmpty
    }

    private func loadListsIfNeeded() async {
        if lists.isEmpty {
            await loadLists()
        }
    }

    private func loadLists() async {
        await loadListsPage(1, replacingExisting: true)
    }

    private func loadMoreListsIfNeeded(force: Bool = false) async {
        guard force || hasMoreLists else { return }
        await loadListsPage(page + 1, replacingExisting: false)
    }

    private func loadListsPage(_ page: Int, replacingExisting: Bool) async {
        guard let profile = env.activeProfile else { return }
        guard let token = try? env.credentialStore.loadToken(for: profile.id) else {
            errorMessage = AppError.unauthorized.errorDescription
            return
        }
        if replacingExisting {
            guard !isLoading else { return }
            isLoading = true
        } else {
            guard !isLoadingMore else { return }
            isLoadingMore = true
        }
        defer {
            isLoading = false
            isLoadingMore = false
        }

        do {
            let page = try await env.apiClient.fetchShoppingLists(
                serverURL: profile.serverURL,
                token: token,
                page: page,
                perPage: listsPerPage
            )
            self.page = page.page
            totalPages = page.totalPages ?? page.total.map { total in
                Int(ceil(Double(total) / Double(page.perPage)))
            }
            lists = replacingExisting ? page.items : lists + page.items
            errorMessage = nil
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ShoppingListsHeroCard: View {
    let listCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Image(systemName: "cart")
                .font(.title)
                .foregroundStyle(DesignSystem.Colors.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Shop from your Mealie lists")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Open a list to review what you need before heading to the store.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Label(String(localized: "Shopping lists: \(listCount)"), systemImage: "list.bullet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.accentSoft, in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(DesignSystem.Colors.separator.opacity(0.35))
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Shop from your Mealie lists. Open a list to review what you need before heading to the store. Shopping lists: \(listCount)"))
    }
}

private struct ShoppingListRow: View {
    let list: MealieShoppingListSummary

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(list.displayName)
                .font(.headline)
                .foregroundStyle(.primary)

            if !list.recipeReferences.isEmpty {
                Label(String(localized: "Recipes: \(list.recipeReferences.count)"), systemImage: "book.closed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if list.recipeReferences.isEmpty {
            return list.displayName
        }
        return String(localized: "\(list.displayName), recipes: \(list.recipeReferences.count)")
    }
}

private struct ShoppingListDetailView: View {
    @EnvironmentObject private var env: AppEnvironment
    let summary: MealieShoppingListSummary

    @State private var detail: MealieShoppingListDetail?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var actionErrorMessage: String?
    @State private var savingItemIDs: Set<String> = []
    @State private var isSavingNewItem = false
    @State private var addDraft: ShoppingItemAddDraft?

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
                                isSaving: savingItemIDs.contains(item.id)
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
        guard let token = try? env.credentialStore.loadToken(for: profile.id) else {
            errorMessage = AppError.unauthorized.errorDescription
            return
        }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            detail = try await env.apiClient.fetchShoppingListDetail(
                serverURL: profile.serverURL,
                token: token,
                listID: summary.id
            )
            actionErrorMessage = nil
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadRecipes() async throws -> [MealieRecipeSummary] {
        guard let profile = env.activeProfile else { return [] }
        guard let token = try? env.credentialStore.loadToken(for: profile.id) else {
            throw AppError.unauthorized
        }
        let page = try await env.apiClient.fetchRecipes(
            serverURL: profile.serverURL,
            token: token,
            page: 1,
            perPage: 100,
            filters: MealieRecipeFilters()
        )
        return page.items
    }

    private func saveNewItem(_ value: ShoppingItemAddValue) async {
        guard let profile = env.activeProfile else { return }
        guard let token = try? env.credentialStore.loadToken(for: profile.id) else {
            actionErrorMessage = AppError.unauthorized.errorDescription
            return
        }
        guard !isSavingNewItem else { return }

        isSavingNewItem = true
        actionErrorMessage = nil
        defer { isSavingNewItem = false }

        do {
            switch value.mode {
            case .manual:
                let collection = try await env.apiClient.createShoppingListItem(
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
                detail = detail?.applying(collection)
            case .recipe:
                guard let recipeID = value.recipeID else { return }
                detail = try await env.apiClient.addRecipeToShoppingList(
                    serverURL: profile.serverURL,
                    token: token,
                    listID: summary.id,
                    recipeID: recipeID,
                    add: MealieShoppingRecipeAdd(recipeIncrementQuantity: value.recipeQuantity)
                )
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
        guard let token = try? env.credentialStore.loadToken(for: profile.id) else {
            errorMessage = AppError.unauthorized.errorDescription
            return
        }

        let originalDetail = detail
        let optimisticItem = item.withChecked(!item.checked)
        detail = detail?.replacingItem(optimisticItem)
        savingItemIDs.insert(item.id)
        errorMessage = nil
        defer { savingItemIDs.remove(item.id) }

        do {
            let collection = try await env.apiClient.updateShoppingListItem(
                serverURL: profile.serverURL,
                token: token,
                itemID: item.id,
                item: MealieShoppingListItemUpdate(item: optimisticItem)
            )
            if let detail {
                self.detail = detail.applying(collection)
            }
        } catch let error as AppError {
            detail = originalDetail
            errorMessage = error.errorDescription
        } catch {
            detail = originalDetail
            errorMessage = error.localizedDescription
        }
    }
}

private struct ShoppingListStatusRow: View {
    let detail: MealieShoppingListDetail

    private var checkedCount: Int {
        detail.listItems.filter(\.checked).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(detail.displayName)
                .font(.headline)

            Label(String(localized: "Items: \(detail.listItems.count)"), systemImage: "checklist")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Label(String(localized: "Checked: \(checkedCount)"), systemImage: "checkmark.circle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "\(detail.displayName), items: \(detail.listItems.count), checked: \(checkedCount)"))
    }
}

private struct ShoppingItemToggleRow: View {
    let item: MealieShoppingListItem
    let isSaving: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.checked ? DesignSystem.Colors.accent : .secondary)
                    .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(item.displayName)
                        .font(.body)
                        .strikethrough(item.checked)
                        .foregroundStyle(item.checked ? .secondary : .primary)

                    if let quantityText = item.quantityText {
                        Text(quantityText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let note = item.note, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: DesignSystem.Spacing.sm)

                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel("Updating item")
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(item.checked ? "Marks this item unchecked" : "Marks this item checked")
    }

    private var accessibilityLabel: String {
        [
            item.displayName,
            item.checked ? String(localized: "Checked") : String(localized: "Unchecked"),
            item.quantityText,
            item.note
        ]
        .compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        .joined(separator: ", ")
    }
}

private enum ShoppingItemAddMode: String, CaseIterable, Identifiable {
    case manual
    case recipe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual: String(localized: "Manual Item")
        case .recipe: String(localized: "Recipe Ingredients")
        }
    }
}

private struct ShoppingItemAddDraft: Identifiable {
    let id = UUID()
    let listID: String
    let nextPosition: Int
}

private struct ShoppingItemAddValue {
    let mode: ShoppingItemAddMode
    let display: String
    let quantity: Double
    let note: String?
    let position: Int
    let recipeID: String?
    let recipeQuantity: Double
}

private struct ShoppingItemAddView: View {
    @Environment(\.dismiss) private var dismiss
    let draft: ShoppingItemAddDraft
    let isSaving: Bool
    let loadRecipes: () async throws -> [MealieRecipeSummary]
    let onSave: (ShoppingItemAddValue) async -> Void

    @State private var mode: ShoppingItemAddMode = .manual
    @State private var display = ""
    @State private var quantityText = "1"
    @State private var note = ""
    @State private var recipes: [MealieRecipeSummary] = []
    @State private var selectedRecipeID: String?
    @State private var recipeQuantityText = "1"
    @State private var isLoadingRecipes = false
    @State private var recipeErrorMessage: String?

    private var quantity: Double? {
        Double(quantityText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var recipeQuantity: Double? {
        Double(recipeQuantityText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var addableRecipes: [MealieRecipeSummary] {
        recipes.filter { $0.recipeID != nil }
    }

    private var isValid: Bool {
        switch mode {
        case .manual:
            return !display.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (quantity ?? 0) > 0
        case .recipe:
            return selectedRecipeID != nil && (recipeQuantity ?? 0) > 0
        }
    }

    var body: some View {
        Form {
            Section("Add Type") {
                Picker("Add Type", selection: $mode) {
                    ForEach(ShoppingItemAddMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            switch mode {
            case .manual:
                manualSection
            case .recipe:
                recipeSection
            }
        }
        .navigationTitle("Add Shopping Item")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .disabled(isSaving)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await save() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Add")
                    }
                }
                .disabled(isSaving || !isValid)
            }
        }
        .task {
            await loadRecipesIfNeeded()
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .recipe {
                Task { await loadRecipesIfNeeded() }
            }
        }
    }

    private var manualSection: some View {
        Section("Manual Item") {
            TextField("Item Name", text: $display)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .accessibilityLabel("Item Name")

            TextField("Quantity", text: $quantityText)
                .keyboardType(.decimalPad)
                .accessibilityLabel("Quantity")

            TextField("Notes", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .accessibilityLabel("Notes")
        }
    }

    private var recipeSection: some View {
        Section {
            if isLoadingRecipes && recipes.isEmpty {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ProgressView()
                    Text("Loading recipes")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Loading recipes")
            } else if let recipeErrorMessage, recipes.isEmpty {
                Text(recipeErrorMessage)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.destructive)
                Button("Try Again") {
                    Task { await loadRecipesIfNeeded(force: true) }
                }
                .frame(minHeight: DesignSystem.HitTarget.minimum)
            } else if addableRecipes.isEmpty {
                Text("No recipes available")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Recipe", selection: recipeSelection) {
                    Text("Choose Recipe").tag(Optional<String>.none)
                    ForEach(addableRecipes) { recipe in
                        Text(recipe.displayName).tag(recipe.recipeID)
                    }
                }

                TextField("Recipe Quantity", text: $recipeQuantityText)
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("Recipe Quantity")
            }
        } header: {
            Text("Recipe Ingredients")
        } footer: {
            Text("Adds the selected recipe's ingredients to this shopping list.")
        }
    }

    private var recipeSelection: Binding<String?> {
        Binding(
            get: { selectedRecipeID },
            set: { selectedRecipeID = $0 }
        )
    }

    private func save() async {
        let trimmedDisplay = display.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        await onSave(ShoppingItemAddValue(
            mode: mode,
            display: trimmedDisplay,
            quantity: quantity ?? 1,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            position: draft.nextPosition,
            recipeID: selectedRecipeID,
            recipeQuantity: recipeQuantity ?? 1
        ))
    }

    private func loadRecipesIfNeeded(force: Bool = false) async {
        guard force || recipes.isEmpty else { return }
        guard !isLoadingRecipes else { return }
        isLoadingRecipes = true
        recipeErrorMessage = nil
        defer { isLoadingRecipes = false }

        do {
            recipes = try await loadRecipes()
            if selectedRecipeID == nil {
                selectedRecipeID = addableRecipes.first?.recipeID
            }
        } catch let error as AppError {
            recipeErrorMessage = error.errorDescription
        } catch {
            recipeErrorMessage = error.localizedDescription
        }
    }
}

private struct ShoppingLoadingRow: View {
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

private struct ShoppingErrorRow: View {
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

private func shoppingItemSort(_ lhs: MealieShoppingListItem, _ rhs: MealieShoppingListItem) -> Bool {
    if lhs.checked != rhs.checked {
        return !lhs.checked
    }
    return lhs.position < rhs.position
}
