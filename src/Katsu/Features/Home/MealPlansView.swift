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
            .listRowBackground(Color.clear)

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
        guard let token = try? env.credentialStore.loadToken(for: profile.id) else {
            errorMessage = AppError.unauthorized.errorDescription
            return
        }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let page = try await env.apiClient.fetchMealPlanEntries(
                serverURL: profile.serverURL,
                token: token,
                startDate: week.startDateString,
                endDate: week.endDateString
            )
            entries = page.items
        } catch let error as AppError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func saveMealPlanEntry(_ value: MealPlanEditorValue, originalEntry: MealieMealPlanEntry?) async {
        guard let profile = env.activeProfile else { return }
        guard let token = try? env.credentialStore.loadToken(for: profile.id) else {
            actionErrorMessage = AppError.unauthorized.errorDescription
            return
        }
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
                let updated = try await env.apiClient.updateMealPlanEntry(
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
                replaceEntry(updated)
            } else {
                let created = try await env.apiClient.createMealPlanEntry(
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
        guard let token = try? env.credentialStore.loadToken(for: profile.id) else {
            actionErrorMessage = AppError.unauthorized.errorDescription
            return
        }
        guard !isSaving else { return }

        isSaving = true
        actionErrorMessage = nil
        defer { isSaving = false }

        do {
            _ = try await env.apiClient.deleteMealPlanEntry(serverURL: profile.serverURL, token: token, entryID: entry.id)
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
        guard let token = try? env.credentialStore.loadToken(for: profile.id) else {
            actionErrorMessage = AppError.unauthorized.errorDescription
            return
        }
        guard randomMealDateString == nil else { return }

        randomMealDateString = dateString
        actionErrorMessage = nil
        defer { randomMealDateString = nil }

        do {
            let created = try await env.apiClient.createRandomMealPlanEntry(
                serverURL: profile.serverURL,
                token: token,
                entry: MealieMealPlanRandomCreate(date: dateString, entryType: .dinner)
            )
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

private struct MealPlanWeekSummaryCard: View {
    let week: MealPlanWeek
    let plannedCount: Int

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(systemName: "calendar")
                .font(.title3)
                .foregroundStyle(DesignSystem.Colors.accentDeep)
                .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                .background(DesignSystem.Colors.accentSoft.opacity(0.75), in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("This week's plan")
                        .font(.headline)

                    Text(week.displayRange)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Label(String(localized: "Planned meals: \(plannedCount)"), systemImage: "fork.knife")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.accentDeep)
                    .lineLimit(1)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(DesignSystem.Colors.accentSoft.opacity(0.75), in: Capsule())
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
        .accessibilityLabel(String(localized: "This week's plan, \(week.displayRange), planned meals: \(plannedCount)"))
    }
}

private struct MealPlanDayRow: View {
    let day: MealPlanDay
    let entries: [MealieMealPlanEntry]
    let onAdd: () -> Void
    let onRandom: () -> Void
    let onEdit: (MealieMealPlanEntry) -> Void
    let onDelete: (MealieMealPlanEntry) -> Void
    let isSuggestingRandomMeal: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(day.weekday)
                        .font(.headline)
                    Text(day.monthDay)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Button(action: onRandom) {
                        if isSuggestingRandomMeal {
                            ProgressView()
                                .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                        } else {
                            Label("Surprise Me", systemImage: "sparkles")
                                .labelStyle(.iconOnly)
                                .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isSuggestingRandomMeal)
                    .accessibilityLabel(String(localized: "Suggest random dinner for \(day.weekday)"))

                    Button(action: onAdd) {
                        Label("Add", systemImage: "plus.circle")
                            .labelStyle(.iconOnly)
                            .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Add meal for \(day.weekday)"))
                }
            }

            if entries.isEmpty {
                Text("No meals planned")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    ForEach(entries.sorted(by: mealPlanEntrySort)) { entry in
                        MealPlanEntryPill(entry: entry)
                            .contextMenu {
                                Button {
                                    onEdit(entry)
                                } label: {
                                    Label("Edit Planned Meal", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    onDelete(entry)
                                } label: {
                                    Label("Remove Planned Meal", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    onDelete(entry)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }

                                Button {
                                    onEdit(entry)
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(DesignSystem.Colors.accent)
                            }
                    }
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if entries.isEmpty {
            return String(localized: "\(day.weekday), \(day.monthDay), no meals planned")
        }
        let meals = entries
            .sorted(by: mealPlanEntrySort)
            .map { String(localized: "\($0.entryType.displayName): \($0.displayTitle)") }
            .joined(separator: ", ")
        return String(localized: "\(day.weekday), \(day.monthDay), \(meals)")
    }
}

private struct MealPlanEditorDraft: Identifiable {
    let id: String
    let entry: MealieMealPlanEntry?
    let dateString: String
    let entryType: MealieMealPlanEntryType
    let title: String
    let text: String

    init(dateString: String) {
        self.id = "new-\(dateString)-\(UUID().uuidString)"
        self.entry = nil
        self.dateString = dateString
        self.entryType = .dinner
        self.title = ""
        self.text = ""
    }

    init(entry: MealieMealPlanEntry) {
        self.id = "edit-\(entry.id)"
        self.entry = entry
        self.dateString = entry.date
        self.entryType = entry.entryType
        self.title = entry.title ?? ""
        self.text = entry.text ?? ""
    }
}

private struct MealPlanEditorValue {
    let dateString: String
    let entryType: MealieMealPlanEntryType
    let title: String
    let text: String
}

private struct MealPlanEntryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let draft: MealPlanEditorDraft
    let week: MealPlanWeek
    let isSaving: Bool
    let onSave: (MealPlanEditorValue) async -> Void

    @State private var dateString: String
    @State private var entryType: MealieMealPlanEntryType
    @State private var title: String
    @State private var text: String

    init(draft: MealPlanEditorDraft, week: MealPlanWeek, isSaving: Bool, onSave: @escaping (MealPlanEditorValue) async -> Void) {
        self.draft = draft
        self.week = week
        self.isSaving = isSaving
        self.onSave = onSave
        _dateString = State(initialValue: draft.dateString)
        _entryType = State(initialValue: draft.entryType)
        _title = State(initialValue: draft.title)
        _text = State(initialValue: draft.text)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section("Planned Meal") {
                TextField("Title", text: $title)
                    .submitLabel(.done)
                    .accessibilityLabel("Title")

                TextField("Notes", text: $text, axis: .vertical)
                    .lineLimit(2...4)
                    .accessibilityLabel("Notes")
            }

            Section("Schedule") {
                Picker("Day", selection: $dateString) {
                    ForEach(week.days, id: \.dateString) { day in
                        Text(String(localized: "\(day.weekday), \(day.monthDay)")).tag(day.dateString)
                    }
                }

                Picker("Meal Type", selection: $entryType) {
                    ForEach(MealieMealPlanEntryType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
            }
        }
        .navigationTitle(draft.entry == nil ? "Add Planned Meal" : "Edit Planned Meal")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .disabled(isSaving)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task {
                        await onSave(MealPlanEditorValue(
                            dateString: dateString,
                            entryType: entryType,
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            text: text.trimmingCharacters(in: .whitespacesAndNewlines)
                        ))
                    }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .disabled(isSaving || !isValid)
            }
        }
    }
}

private struct MealPlanEntryPill: View {
    let entry: MealieMealPlanEntry

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Text(entry.entryType.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.accentDeep)
                .padding(.horizontal, DesignSystem.Spacing.sm)
                .padding(.vertical, DesignSystem.Spacing.xs)
                .background(DesignSystem.Colors.accentSoft, in: Capsule())

            Text(entry.displayTitle)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }
}

private struct MealPlanLoadingRow: View {
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ProgressView()
            Text("Loading meal plan…")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading meal plan")
    }
}

private struct MealPlanErrorRow: View {
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

private struct MealPlanWeek {
    let start: Date
    let days: [MealPlanDay]

    init(containing date: Date, calendar: Calendar = .current) {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        self.start = start
        self.days = (0..<7).map { offset in
            MealPlanDay(date: calendar.date(byAdding: .day, value: offset, to: start) ?? start)
        }
    }

    var startDateString: String { days.first?.dateString ?? mealPlanDateFormatter.string(from: start) }
    var endDateString: String { days.last?.dateString ?? startDateString }
    var todayDateString: String {
        let today = mealPlanDateFormatter.string(from: Date())
        return days.contains { $0.dateString == today } ? today : startDateString
    }

    var displayRange: String {
        guard let first = days.first, let last = days.last else { return "" }
        return String(localized: "\(first.monthDay) to \(last.monthDay)")
    }
}

private struct MealPlanDay {
    let date: Date

    var dateString: String { mealPlanDateFormatter.string(from: date) }
    var weekday: String { mealPlanWeekdayFormatter.string(from: date) }
    var monthDay: String { mealPlanMonthDayFormatter.string(from: date) }
}

private func mealPlanEntrySort(_ lhs: MealieMealPlanEntry, _ rhs: MealieMealPlanEntry) -> Bool {
    mealPlanEntryTypeSortIndex(lhs.entryType) < mealPlanEntryTypeSortIndex(rhs.entryType)
}

private func mealPlanEntryTypeSortIndex(_ entryType: MealieMealPlanEntryType) -> Int {
    switch entryType {
    case .breakfast: 0
    case .lunch: 1
    case .dinner: 2
    case .side: 3
    case .snack: 4
    case .drink: 5
    case .dessert: 6
    }
}

let mealPlanDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

private let mealPlanWeekdayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE"
    return formatter
}()

private let mealPlanMonthDayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()
