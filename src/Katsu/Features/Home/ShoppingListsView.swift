import SwiftUI

struct ShoppingListsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lists: [MealieShoppingListSummary] = []
    @State private var page = 1
    @State private var totalPages: Int?
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var isShowingAddList = false
    @State private var isSavingNewList = false
    @State private var addListErrorMessage: String?
    @State private var revealedListID: String?
    @State private var navigationListID: String?
    @State private var deleteErrorMessage: String?

    private let listsPerPage = 20

    var body: some View {
        if env.supports(.households) {
            shoppingListsStack
        } else {
            NavigationStack {
                ServerUpdateRequiredView(feature: .households, serverVersion: env.activeProfile?.version)
                    .navigationTitle("Shopping Lists")
            }
        }
    }

    private var shoppingListsStack: some View {
        NavigationStack {
            List {
                Section {
                    ShoppingListsHeroCard(listCount: lists.count)
                }
                .listRowInsets(EdgeInsets())

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
                            Text("Add a shopping list to Mealie and it will appear here.")
                        }
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(lists) { list in
                            shoppingListRow(for: list)
                                .listRowInsets(EdgeInsets())
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
            .readableListContentWidth()
            .navigationTitle("Shopping Lists")
            .toolbar { addToolbarItem }
            .navigationDestination(item: $navigationListID) { listID in
                if let summary = lists.first(where: { $0.id == listID }) {
                    ShoppingListDetailView(summary: summary)
                }
            }
            .sheet(isPresented: $isShowingAddList) {
                NavigationStack {
                    ShoppingListAddView(
                        isSaving: isSavingNewList,
                        errorMessage: addListErrorMessage,
                        onSave: saveNewList
                    )
                }
            }
            .alert(
                "Couldn't delete shopping list",
                isPresented: Binding(
                    get: { deleteErrorMessage != nil },
                    set: { if !$0 { deleteErrorMessage = nil } }
                ),
                presenting: deleteErrorMessage
            ) { _ in
                Button("OK", role: .cancel) { deleteErrorMessage = nil }
            } message: { message in
                Text(message)
            }
            .onChange(of: isShowingAddList) { _, isShowing in
                if isShowing {
                    addListErrorMessage = nil
                }
            }
            .contentMargins(.top, DesignSystem.Spacing.sm, for: .scrollContent)
            .task(id: env.activeProfile?.id) {
                await loadListsIfNeeded()
            }
            .refreshable {
                await loadLists()
            }
        }
    }

    @ViewBuilder
    private func shoppingListRow(for list: MealieShoppingListSummary) -> some View {
        SwipeToRemoveRow(
            isRevealed: Binding(
                get: { revealedListID == list.id },
                set: { isRevealed in
                    revealedListID = isRevealed ? list.id : nil
                }
            ),
            onRemove: { removeShoppingList(list) },
            contentBackground: nil
        ) {
            Button {
                if revealedListID != nil {
                    revealedListID = nil
                } else {
                    navigationListID = list.id
                }
            } label: {
                HStack(spacing: 0) {
                    ShoppingListRow(list: list)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.trailing, DesignSystem.Spacing.md)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAction(named: Text("Delete")) {
                removeShoppingList(list)
            }
        }
    }

    private var addToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                isShowingAddList = true
            } label: {
                Label("Add Shopping List", systemImage: "plus")
            }
            .accessibilityLabel("Add Shopping List")
            .disabled(isSavingNewList)
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
            let page = try await env.withToken(for: profile) { token in
                try await env.apiClient.fetchShoppingLists(
                    serverURL: profile.serverURL,
                    token: token,
                    page: page,
                    perPage: listsPerPage
                )
            }
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

    private func saveNewList(_ value: ShoppingListAddValue) async {
        guard let profile = env.activeProfile else { return }
        guard !isSavingNewList else { return }
        isSavingNewList = true
        addListErrorMessage = nil
        defer { isSavingNewList = false }

        do {
            let created = try await env.withToken(for: profile) { token in
                try await env.apiClient.createShoppingList(
                    serverURL: profile.serverURL,
                    token: token,
                    list: MealieShoppingListCreate(name: value.name)
                )
            }
            lists.removeAll { $0.id == created.id }
            lists.insert(created.summary, at: 0)
            errorMessage = nil
            isShowingAddList = false
        } catch let error as AppError {
            addListErrorMessage = error.errorDescription
        } catch {
            addListErrorMessage = error.localizedDescription
        }
    }

    private func removeShoppingList(_ list: MealieShoppingListSummary) {
        guard let profile = env.activeProfile else { return }

        // Optimistic removal — reuses the server-row pattern of acting
        // immediately and rolling back on failure.
        let previousLists = lists
        let removalAnimation: Animation? = reduceMotion ? nil : DesignSystem.Motion.standard
        withAnimation(removalAnimation) {
            lists.removeAll { $0.id == list.id }
            revealedListID = nil
        }

        Task {
            do {
                _ = try await env.withToken(for: profile) { token in
                    try await env.apiClient.deleteShoppingList(
                        serverURL: profile.serverURL,
                        token: token,
                        listID: list.id
                    )
                }
            } catch let error as AppError {
                withAnimation(removalAnimation) {
                    lists = previousLists
                }
                deleteErrorMessage = error.errorDescription
            } catch {
                withAnimation(removalAnimation) {
                    lists = previousLists
                }
                deleteErrorMessage = error.localizedDescription
            }
        }
    }
}
