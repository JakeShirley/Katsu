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
                            ShoppingItemReadOnlyRow(item: item)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(detail?.displayName ?? summary.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: summary.id) {
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
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
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

private struct ShoppingItemReadOnlyRow: View {
    let item: MealieShoppingListItem

    var body: some View {
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
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
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
