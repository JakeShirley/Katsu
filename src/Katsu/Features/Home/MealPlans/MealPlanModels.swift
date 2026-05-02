import Foundation

struct MealPlanEditorDraft: Identifiable {
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

struct MealPlanEditorValue {
    let dateString: String
    let entryType: MealieMealPlanEntryType
    let title: String
    let text: String
}

struct MealPlanWeek {
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

struct MealPlanDay {
    let date: Date

    var dateString: String { mealPlanDateFormatter.string(from: date) }
    var weekday: String { mealPlanWeekdayFormatter.string(from: date) }
    var monthDay: String { mealPlanMonthDayFormatter.string(from: date) }
}

func mealPlanEntrySort(_ lhs: MealieMealPlanEntry, _ rhs: MealieMealPlanEntry) -> Bool {
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
