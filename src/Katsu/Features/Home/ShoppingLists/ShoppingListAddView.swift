import SwiftUI

struct ShoppingListAddView: View {
    @Environment(\.dismiss) private var dismiss
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (ShoppingListAddValue) async -> Void

    @State private var name = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        !trimmedName.isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField("List Name", text: $name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit { Task { await save() } }
                    .accessibilityLabel("List Name")
            } header: {
                Text("List Details")
            } footer: {
                Text("Name the list you want to add to Mealie.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.destructive)
                }
            }
        }
        .navigationTitle("Add Shopping List")
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
    }

    private func save() async {
        guard isValid else { return }
        await onSave(ShoppingListAddValue(name: trimmedName))
    }
}
