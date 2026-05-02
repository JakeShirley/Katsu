import SwiftUI

struct RecipeMakingModeView: View {
    let detail: MealieRecipeDetail
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPage = 0

    private var pages: [RecipeMakingPage] {
        var pages = [RecipeMakingPage.ingredients(detail.recipeIngredient)]
        pages.append(contentsOf: (detail.recipeInstructions ?? []).enumerated().map { index, instruction in
            RecipeMakingPage.step(index: index + 1, instruction: instruction)
        })
        return pages
    }

    var body: some View {
        ZStack {
            DesignSystem.Colors.background
                .ignoresSafeArea()

            VStack(spacing: DesignSystem.Spacing.lg) {
                header
                progressStrip

                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        RecipeMakingCard(page: page, totalSteps: max(pages.count - 1, 0))
                            .tag(index)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .accessibilityElement(children: .contain)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(reduceMotion ? nil : DesignSystem.Motion.standard, value: selectedPage)

                navigationControls
            }
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
        .accessibilityAction(.escape) {
            dismiss()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Making Mode")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignSystem.Colors.accentDeep)
                    .textCase(.uppercase)

                Text(detail.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                    .background(DesignSystem.Colors.surface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close making mode")
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private var progressStrip: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index <= selectedPage ? DesignSystem.Colors.accent : DesignSystem.Colors.separator.opacity(0.45))
                    .frame(height: 4)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "Making mode page \(selectedPage + 1) of \(pages.count)"))
    }

    private var navigationControls: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button {
                movePage(by: -1)
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity, minHeight: DesignSystem.HitTarget.minimum)
            }
            .buttonStyle(.bordered)
            .disabled(selectedPage == 0)
            .accessibilityLabel("Previous making mode card")

            Button {
                if selectedPage == pages.count - 1 {
                    dismiss()
                } else {
                    movePage(by: 1)
                }
            } label: {
                Label(selectedPage == pages.count - 1 ? "Finish" : "Next", systemImage: selectedPage == pages.count - 1 ? "checkmark.circle.fill" : "chevron.right")
                    .frame(maxWidth: .infinity, minHeight: DesignSystem.HitTarget.minimum)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel(selectedPage == pages.count - 1 ? "Finish making mode" : "Next making mode card")
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }

    private func movePage(by offset: Int) {
        let nextPage = min(max(selectedPage + offset, 0), pages.count - 1)
        if reduceMotion {
            selectedPage = nextPage
        } else {
            withAnimation(DesignSystem.Motion.standard) {
                selectedPage = nextPage
            }
        }
    }
}

private enum RecipeMakingPage {
    case ingredients([MealieRecipeIngredient])
    case step(index: Int, instruction: MealieRecipeInstruction)
}

private struct RecipeMakingCard: View {
    let page: RecipeMakingPage
    let totalSteps: Int

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                switch page {
                case .ingredients(let ingredients):
                    ingredientsContent(ingredients)
                case .step(let index, let instruction):
                    stepContent(index: index, instruction: instruction)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignSystem.Spacing.xl)
        }
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
        .overlay {
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(DesignSystem.Colors.separator.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 18, y: 8)
    }

    private func ingredientsContent(_ ingredients: [MealieRecipeIngredient]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            cardEyebrow("Get Set")
            Text("Ingredients")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            if ingredients.isEmpty {
                ContentUnavailableView("No ingredients listed", systemImage: "list.bullet.clipboard")
            } else {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    ForEach(ingredients) { ingredient in
                        RecipeMakingIngredientRow(ingredient: ingredient)
                    }
                }
            }
        }
    }

    private func stepContent(index: Int, instruction: MealieRecipeInstruction) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            cardEyebrow(String(localized: "Step \(index) of \(totalSteps)"))
            Text(String(localized: "Step \(index)"))
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(instruction.displayText)
                .font(.title3)
                .lineSpacing(6)
                .foregroundStyle(.primary)
                .accessibilityLabel(String(localized: "Step \(index), \(instruction.displayText)"))
        }
    }

    private func cardEyebrow(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(DesignSystem.Colors.accentDeep)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(DesignSystem.Colors.accentSoft, in: Capsule())
    }
}

private struct RecipeMakingIngredientRow: View {
    let ingredient: MealieRecipeIngredient

    private var display: RecipeIngredientDisplay {
        RecipeIngredientDisplay(ingredient: ingredient)
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.md) {
            Image(systemName: "circle.fill")
                .font(.caption2)
                .foregroundStyle(DesignSystem.Colors.accent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(display.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let measurement = display.measurement {
                    Text(measurement)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.Colors.accentDeep)
                }

                if let note = display.note {
                    Text(note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(display.accessibilityLabel)
    }
}
