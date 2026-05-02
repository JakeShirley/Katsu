import SwiftUI

struct MealPlanEntryEditorView: View {
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
