import SwiftUI

struct MealPlanWeekSummaryCard: View {
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

struct MealPlanDayRow: View {
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

struct MealPlanLoadingRow: View {
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ProgressView()
            Text("Loading meal plan…")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading meal plan")
    }
}

struct MealPlanErrorRow: View {
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
