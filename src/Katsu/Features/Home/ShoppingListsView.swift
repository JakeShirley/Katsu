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
            .navigationBarTitleDisplayMode(.inline)
            .contentMargins(.top, DesignSystem.Spacing.sm, for: .scrollContent)
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
