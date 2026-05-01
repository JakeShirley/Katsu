import SwiftUI

struct MealPlansView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var entries: [MealieMealPlanEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var week: MealPlanWeek {
        MealPlanWeek(containing: Date())
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    MealPlanWeekSummaryCard(week: week, plannedCount: entries.count)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section("This Week") {
                    if isLoading && entries.isEmpty {
                        MealPlanLoadingRow()
                    } else if let errorMessage, entries.isEmpty {
                        MealPlanErrorRow(errorMessage: errorMessage) {
                            Task { await loadMealPlan() }
                        }
                    } else {
                        ForEach(week.days, id: \.dateString) { day in
                            MealPlanDayRow(day: day, entries: entriesByDate[day.dateString] ?? [])
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Meal Plans")
            .task(id: env.activeProfile?.id) {
                await loadMealPlan()
            }
            .refreshable {
                await loadMealPlan()
            }
        }
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
}

private struct MealPlanWeekSummaryCard: View {
    let week: MealPlanWeek
    let plannedCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Image(systemName: "calendar")
                .font(.title)
                .foregroundStyle(DesignSystem.Colors.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("This week's plan")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(week.displayRange)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Label(String(localized: "Planned meals: \(plannedCount)"), systemImage: "fork.knife")
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
        .accessibilityLabel(String(localized: "This week's plan, \(week.displayRange), planned meals: \(plannedCount)"))
    }
}

private struct MealPlanDayRow: View {
    let day: MealPlanDay
    let entries: [MealieMealPlanEntry]

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

                if entries.isEmpty {
                    Text("Open")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
