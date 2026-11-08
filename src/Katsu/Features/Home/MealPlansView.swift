import SwiftUI

struct MealPlansView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var entries: [MealieMealPlanEntry] = []
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var actionErrorMessage: String?
    @State private var activeEditor: MealPlanEditorDraft?
    @State private var entryPendingDeletion: MealieMealPlanEntry?
    @State private var randomMealDateString: String?

    private var week: MealPlanWeek {
        MealPlanWeek(containing: Date())
    }

    var body: some View {
        if env.supports(.households) {
            mealPlansStack
        } else {
            NavigationStack {
                ServerUpdateRequiredView(feature: .households, serverVersion: env.activeProfile?.version)
                    .navigationTitle("Meal Plans")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private var mealPlansStack: some View {
        NavigationStack {
            mealPlanList
            .listStyle(.insetGrouped)
            .navigationTitle("Meal Plans")
            .navigationBarTitleDisplayMode(.inline)
            .contentMargins(.top, DesignSystem.Spacing.sm, for: .scrollContent)
            .toolbar { addToolbarItem }
            .sheet(item: $activeEditor) { draft in
                editorSheet(for: draft)
            }
            .confirmationDialog("Remove Planned Meal", isPresented: deleteDialogBinding, presenting: entryPendingDeletion, actions: deleteDialogActions, message: deleteDialogMessage)
            .task(id: env.activeProfile?.id) {
                await loadMealPlan()
            }
            .refreshable {
                await loadMealPlan()
            }
        }
    }

    private var mealPlanList: some View {
        List {
            Section {
                MealPlanWeekSummaryCard(week: week, plannedCount: entries.count)
            }
            .listRowInsets(EdgeInsets())

            Section("This Week") {
                weekRows
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

    @ViewBuilder
    private var weekRows: some View {
        if isLoading && entries.isEmpty {
            MealPlanLoadingRow()
        } else if let errorMessage, entries.isEmpty {
            MealPlanErrorRow(errorMessage: errorMessage) {
                Task { await loadMealPlan() }
            }
        } else {
            ForEach(week.days, id: \.dateString) { day in
                MealPlanDayRow(
                    day: day,
                    entries: entriesByDate[day.dateString] ?? [],
                    onAdd: { activeEditor = MealPlanEditorDraft(dateString: day.dateString) },
                    onRandom: { Task { await addRandomMealPlanEntry(on: day.dateString) } },
                    onEdit: { activeEditor = MealPlanEditorDraft(entry: $0) },
                    onDelete: { entryPendingDeletion = $0 },
                    isSuggestingRandomMeal: randomMealDateString == day.dateString
                )
            }
        }
    }

    private var addToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                activeEditor = MealPlanEditorDraft(dateString: week.todayDateString)
            } label: {
                Label("Add Planned Meal", systemImage: "plus")
            }
            .accessibilityLabel("Add Planned Meal")
        }
    }

    private var deleteDialogBinding: Binding<Bool> {
        Binding(
            get: { entryPendingDeletion != nil },
            set: { if !$0 { entryPendingDeletion = nil } }
        )
    }

    private func editorSheet(for draft: MealPlanEditorDraft) -> some View {
        NavigationStack {
            MealPlanEntryEditorView(
                draft: draft,
                week: week,
                isSaving: isSaving,
                onSave: { await saveMealPlanEntry($0, originalEntry: draft.entry) }
            )
        }
    }

    @ViewBuilder
    private func deleteDialogActions(entry: MealieMealPlanEntry) -> some View {
        Button("Remove Planned Meal", role: .destructive) {
            Task { await deleteMealPlanEntry(entry) }
        }
        Button("Cancel", role: .cancel) {}
    }

    private func deleteDialogMessage(entry: MealieMealPlanEntry) -> Text {
        Text(String(localized: "Remove \(entry.displayTitle) from this week's plan?"))
    }

    private var entriesByDate: [String: [MealieMealPlanEntry]] {
        Dictionary(grouping: entries, by: \.date)
    }

    private func loadMealPlan() async {
        guard let profile = env.activeProfile else { return }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let page = try await env.withToken(for: profile) { token in
                try await env.apiClient.fetchMealPlanEntries(
                    serverURL: profile.serverURL,
                    token: token,
                    startDate: week.startDateString,
                    endDate: week.endDateString
                )
            }
            entries = page.items
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveMealPlanEntry(_ value: MealPlanEditorValue, originalEntry: MealieMealPlanEntry?) async {
        guard let profile = env.activeProfile else { return }
        guard !isSaving else { return }

        isSaving = true
        actionErrorMessage = nil
        defer { isSaving = false }

        do {
            if let originalEntry {
                guard let groupID = originalEntry.groupID, let userID = originalEntry.userID else {
                    actionErrorMessage = String(localized: "This planned meal cannot be edited because Mealie did not return ownership details.")
                    return
                }
                let updated = try await env.withToken(for: profile) { token in
                    try await env.apiClient.updateMealPlanEntry(
                        serverURL: profile.serverURL,
                        token: token,
                        entryID: originalEntry.id,
                        entry: MealieMealPlanEntryUpdate(
                            date: value.dateString,
                            entryType: value.entryType,
                            title: value.title,
                            text: value.text,
                            recipeID: originalEntry.recipeID,
                            id: originalEntry.id,
                            groupID: groupID,
                            userID: userID
                        )
                    )
                }
                replaceEntry(updated)
            } else {
                let created = try await env.withToken(for: profile) { token in
                    try await env.apiClient.createMealPlanEntry(
                        serverURL: profile.serverURL,
                        token: token,
                        entry: MealieMealPlanEntryCreate(
                            date: value.dateString,
                            entryType: value.entryType,
                            title: value.title,
                            text: value.text,
                            recipeID: nil
                        )
                    )
                }
                replaceEntry(created)
            }
            activeEditor = nil
        } catch let error as AppError {
            actionErrorMessage = error.errorDescription
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    private func deleteMealPlanEntry(_ entry: MealieMealPlanEntry) async {
        guard let profile = env.activeProfile else { return }
        guard !isSaving else { return }

        isSaving = true
        actionErrorMessage = nil
        defer { isSaving = false }

        do {
            _ = try await env.withToken(for: profile) { token in
                try await env.apiClient.deleteMealPlanEntry(serverURL: profile.serverURL, token: token, entryID: entry.id)
            }
            entries.removeAll { $0.id == entry.id }
            entryPendingDeletion = nil
        } catch let error as AppError {
            actionErrorMessage = error.errorDescription
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    private func addRandomMealPlanEntry(on dateString: String) async {
        guard let profile = env.activeProfile else { return }
        guard randomMealDateString == nil else { return }

        randomMealDateString = dateString
        actionErrorMessage = nil
        defer { randomMealDateString = nil }

        do {
            let created = try await env.withToken(for: profile) { token in
                try await env.apiClient.createRandomMealPlanEntry(
                    serverURL: profile.serverURL,
                    token: token,
                    entry: MealieMealPlanRandomCreate(date: dateString, entryType: .dinner)
                )
            }
            replaceEntry(created)
        } catch let error as AppError {
            actionErrorMessage = error.errorDescription
        } catch {
            actionErrorMessage = error.localizedDescription
        }
    }

    private func replaceEntry(_ entry: MealieMealPlanEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
    }
}
