import SwiftUI

struct RecipeHeroSection: View {
    @EnvironmentObject private var env: AppEnvironment
    let detail: MealieRecipeDetail
    let profileID: UUID?
    let serverURL: URL?
    let onStartMaking: () -> Void
    @State private var isShowingImageViewer = false

    private var localImageURL: URL? {
        guard let profileID, let recipeID = detail.recipeID else { return nil }
        return env.recipeOfflineCache.localImageURL(profileID: profileID, recipeID: recipeID, slug: detail.slug, fileName: "min-original.webp")
    }

    private var displayImageURL: URL? {
        if let localImageURL { return localImageURL }
        guard let serverURL else { return nil }
        return detail.imageURL(serverURL: serverURL)
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                if let imageURL = displayImageURL {
                    Button {
                        isShowingImageViewer = true
                    } label: {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 180)
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg))
                            case .failure:
                                EmptyView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Open recipe photo for \(detail.displayName)"))
                    .accessibilityHint("Opens a full-screen image viewer")
                    .fullScreenCover(isPresented: $isShowingImageViewer) {
                        RecipeImageViewer(imageURL: imageURL, title: detail.displayName)
                    }
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text(detail.displayName)
                            .font(.title2)
                            .fontWeight(.semibold)

                        if let description = detail.description, !description.isEmpty {
                            Text(description)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    RecipeMetadataView(detail: detail)

                    let chips = (detail.recipeCategory ?? []) + (detail.tags ?? [])
                    if !chips.isEmpty {
                        FlowLayout(spacing: DesignSystem.Spacing.sm) {
                            ForEach(chips) { chip in
                                Text(chip.name)
                                    .font(.caption)
                                    .padding(.horizontal, DesignSystem.Spacing.sm)
                                    .padding(.vertical, DesignSystem.Spacing.xs)
                                    .background(DesignSystem.Colors.accentSoft, in: Capsule())
                                    .foregroundStyle(DesignSystem.Colors.accentDeep)
                                    .accessibilityLabel(chip.name)
                            }
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(heroAccessibilityLabel)

                Button(action: onStartMaking) {
                    Label("Start Making", systemImage: "play.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: DesignSystem.HitTarget.minimum)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Start making mode")
            }
            .padding(.vertical, DesignSystem.Spacing.xs)
        }
    }

    private var heroAccessibilityLabel: String {
        [
            detail.displayName,
            detail.description,
            detail.recipeYield,
            detail.totalTime.flatMap(recipeReadableDuration).map { String(localized: "Total time \($0)") },
            detail.rating.map { String(localized: "Rating \($0)") }
        ]
        .compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        .joined(separator: ", ")
    }
}
