import SwiftUI

struct ShoppingItemAddView: View {
    @Environment(\.dismiss) private var dismiss
    let draft: ShoppingItemAddDraft
    let isSaving: Bool
    let loadRecipes: () async throws -> [MealieRecipeSummary]
    let onSave: (ShoppingItemAddValue) async -> Void

    @State private var mode: ShoppingItemAddMode = .manual
    @State private var display = ""
    @State private var quantityText = "1"
    @State private var note = ""
    @State private var recipes: [MealieRecipeSummary] = []
    @State private var selectedRecipeID: String?
    @State private var recipeQuantityText = "1"
    @State private var isLoadingRecipes = false
    @State private var recipeErrorMessage: String?

    private var quantity: Double? {
        Double(quantityText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var recipeQuantity: Double? {
        Double(recipeQuantityText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var addableRecipes: [MealieRecipeSummary] {
        recipes.filter { $0.recipeID != nil }
    }

    private var isValid: Bool {
        switch mode {
        case .manual:
            return !display.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (quantity ?? 0) > 0
        case .recipe:
            return selectedRecipeID != nil && (recipeQuantity ?? 0) > 0
        }
    }

    var body: some View {
        Form {
            Section("Add Type") {
                Picker("Add Type", selection: $mode) {
                    ForEach(ShoppingItemAddMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            switch mode {
            case .manual:
                manualSection
            case .recipe:
                recipeSection
            }
        }
        .navigationTitle("Add Shopping Item")
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
        .task {
            await loadRecipesIfNeeded()
        }
        .onChange(of: mode) { _, newMode in
            if newMode == .recipe {
                Task { await loadRecipesIfNeeded() }
            }
        }
    }

    private var manualSection: some View {
        Section("Manual Item") {
            TextField("Item Name", text: $display)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .accessibilityLabel("Item Name")

            TextField("Quantity", text: $quantityText)
                .keyboardType(.decimalPad)
                .accessibilityLabel("Quantity")

            TextField("Notes", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .accessibilityLabel("Notes")
        }
    }

    private var recipeSection: some View {
        Section {
            if isLoadingRecipes && recipes.isEmpty {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ProgressView()
                    Text("Loading recipes")
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Loading recipes")
            } else if let recipeErrorMessage, recipes.isEmpty {
                Text(recipeErrorMessage)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.destructive)
                Button("Try Again") {
                    Task { await loadRecipesIfNeeded(force: true) }
                }
                .frame(minHeight: DesignSystem.HitTarget.minimum)
            } else if addableRecipes.isEmpty {
                Text("No recipes available")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Recipe", selection: recipeSelection) {
                    Text("Choose Recipe").tag(Optional<String>.none)
                    ForEach(addableRecipes) { recipe in
                        Text(recipe.displayName).tag(recipe.recipeID)
                    }
                }

                TextField("Recipe Quantity", text: $recipeQuantityText)
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("Recipe Quantity")
            }
        } header: {
            Text("Recipe Ingredients")
        } footer: {
            Text("Adds the selected recipe's ingredients to this shopping list.")
        }
    }

    private var recipeSelection: Binding<String?> {
        Binding(
            get: { selectedRecipeID },
            set: { selectedRecipeID = $0 }
        )
    }

    private func save() async {
        let trimmedDisplay = display.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        await onSave(ShoppingItemAddValue(
            mode: mode,
            display: trimmedDisplay,
            quantity: quantity ?? 1,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            position: draft.nextPosition,
            recipeID: selectedRecipeID,
            recipeQuantity: recipeQuantity ?? 1
        ))
    }

    private func loadRecipesIfNeeded(force: Bool = false) async {
        guard force || recipes.isEmpty else { return }
        guard !isLoadingRecipes else { return }
        isLoadingRecipes = true
        recipeErrorMessage = nil
        defer { isLoadingRecipes = false }

        do {
            recipes = try await loadRecipes()
            if selectedRecipeID == nil {
                selectedRecipeID = addableRecipes.first?.recipeID
            }
        } catch let error as AppError {
            recipeErrorMessage = error.errorDescription
        } catch {
            recipeErrorMessage = error.localizedDescription
        }
    }
}
