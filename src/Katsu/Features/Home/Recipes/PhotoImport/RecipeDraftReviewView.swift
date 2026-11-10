import SwiftUI

/// Lets the user correct an on-device recipe draft before Katsu sends it to
/// Mealie as schema.org JSON.
struct RecipeDraftReviewView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var draft: RecipeDraft
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var attachPhotos = true
    @State private var usePhotoAsRecipeImage = false
    /// Set once Mealie has created the recipe, so a retry only re-sends photos.
    @State private var importedSlug: String?
    @State private var uploadedPhotoCount = 0
    @State private var recipeImageUploaded = false
    @FocusState private var focusedLineID: UUID?

    let recognizedText: String
    let notice: String?
    /// JPEG data for each source page, in reading order.
    let photos: [Data]
    let onImported: () async -> Void

    init(
        draft: RecipeDraft,
        recognizedText: String,
        notice: String?,
        photos: [Data],
        onImported: @escaping () async -> Void
    ) {
        _draft = State(initialValue: draft)
        self.recognizedText = recognizedText
        self.notice = notice
        self.photos = photos
        self.onImported = onImported
    }

    var body: some View {
        Form {
            if let notice {
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
                            Text(notice)
                                .font(.subheadline)
                            Text("Katsu filled in what it could from the recognized text. Review it carefully.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(DesignSystem.Colors.warning)
                            .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            Section("Recipe") {
                labeledField("Name") {
                    TextField("Recipe name", text: $draft.name)
                        .font(.headline)
                        .accessibilityLabel("Recipe name")
                }
                labeledField("Description") {
                    TextField(text: $draft.summary, prompt: Text(verbatim: ""), axis: .vertical) {
                        Text("Description")
                    }
                        .lineLimit(1...4)
                        .accessibilityLabel("Description")
                }
                labeledField("Servings") {
                    TextField(text: $draft.recipeYield, prompt: Text(verbatim: "")) {
                        Text("Servings")
                    }
                        .accessibilityLabel("Servings")
                }
            }

            Section("Times") {
                minutesField("Prep", value: $draft.prepMinutes)
                minutesField("Cook", value: $draft.cookMinutes)
                minutesField("Total", value: $draft.totalMinutes)
            }

            Section {
                ForEach($draft.ingredients) { $line in
                    TextField("Ingredient", text: $line.text, axis: .vertical)
                        .focused($focusedLineID, equals: line.id)
                        .accessibilityLabel("Ingredient")
                }
                .onDelete { draft.ingredients.remove(atOffsets: $0) }
                .onMove { draft.ingredients.move(fromOffsets: $0, toOffset: $1) }

                Button {
                    let line = RecipeDraft.Line(text: "")
                    draft.ingredients.append(line)
                    focusedLineID = line.id
                } label: {
                    Label("Add Ingredient", systemImage: "plus")
                }
                .frame(minHeight: DesignSystem.HitTarget.minimum)
            } header: {
                Text("Ingredients")
            } footer: {
                Text("Mealie can split quantities and units after import with its ingredient parser.")
            }

            Section("Steps") {
                ForEach(Array($draft.steps.enumerated()), id: \.element.id) { index, $line in
                    HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
                        Text(verbatim: "\(index + 1).")
                            .font(.body.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        TextField("Step", text: $line.text, axis: .vertical)
                            .focused($focusedLineID, equals: line.id)
                            .accessibilityLabel(Text("Step \(index + 1)"))
                    }
                }
                .onDelete { draft.steps.remove(atOffsets: $0) }
                .onMove { draft.steps.move(fromOffsets: $0, toOffset: $1) }

                Button {
                    let line = RecipeDraft.Line(text: "")
                    draft.steps.append(line)
                    focusedLineID = line.id
                } label: {
                    Label("Add Step", systemImage: "plus")
                }
                .frame(minHeight: DesignSystem.HitTarget.minimum)
            }

            Section("Notes") {
                TextField("Tips, variations, or storage", text: $draft.notes, axis: .vertical)
                    .lineLimit(2...6)
                    .accessibilityLabel("Notes")
            }

            if !photos.isEmpty {
                Section {
                    Toggle("Attach photos to recipe", isOn: $attachPhotos)
                    Toggle("Use first photo as recipe image", isOn: $usePhotoAsRecipeImage)
                } header: {
                    Text("Source Photos")
                } footer: {
                    Text("Attached photos are saved as recipe assets in Mealie so you can refer back to the original pages.")
                }
                .disabled(isImporting)
            }

            Section {
                DisclosureGroup("Recognized Text") {
                    Text(recognizedText)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } footer: {
                Text("Copy anything the reader missed from the original text.")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.destructive)
                }
            }

            Section {
                Button(action: importRecipe) {
                    if isImporting {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ProgressView()
                            Text("Importing recipe…")
                        }
                    } else if importedSlug != nil {
                        Text("Retry Photo Upload")
                    } else {
                        Text("Import to Mealie")
                    }
                }
                .disabled(isImporting || !draft.isImportable)
                .frame(minHeight: DesignSystem.HitTarget.minimum)

                if importedSlug != nil {
                    Button("Finish Without Photos") {
                        Task { await onImported() }
                    }
                    .disabled(isImporting)
                    .frame(minHeight: DesignSystem.HitTarget.minimum)
                }
            } footer: {
                if !draft.isImportable {
                    Text("Add a name and at least one ingredient or step.")
                }
            }
        }
        .navigationTitle("Review Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
        }
    }

    private func labeledField<Field: View>(_ title: LocalizedStringKey, @ViewBuilder field: () -> Field) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            field()
        }
    }

    private func minutesField(_ title: LocalizedStringKey, value: Binding<Int?>) -> some View {
        LabeledContent(title) {
            TextField("Minutes", text: Binding(
                get: { value.wrappedValue.map(String.init) ?? "" },
                set: { value.wrappedValue = Int($0.filter(\.isNumber)) }
            ))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 120)
            .accessibilityLabel(title)
            .accessibilityHint("Minutes")
        }
    }

    private func importRecipe() {
        guard let profile = env.activeProfile, !isImporting, draft.isImportable else { return }
        errorMessage = nil
        isImporting = true
        Task {
            defer { isImporting = false }
            let slug: String
            if let importedSlug {
                slug = importedSlug
            } else {
                do {
                    let json = try draft.schemaOrgJSON()
                    slug = try await env.withToken(for: profile) { token in
                        try await env.apiClient.importRecipeFromJSON(
                            serverURL: profile.serverURL,
                            token: token,
                            json: json
                        )
                    }
                    importedSlug = slug
                } catch {
                    errorMessage = Self.message(for: error)
                    return
                }
            }

            do {
                try await uploadPhotos(slug: slug, profile: profile)
            } catch {
                errorMessage = String(localized: "The recipe was imported, but its photos couldn't be uploaded.")
                return
            }
            await onImported()
        }
    }

    private func uploadPhotos(slug: String, profile: ServerProfile) async throws {
        if attachPhotos {
            while uploadedPhotoCount < photos.count {
                let pageNumber = uploadedPhotoCount + 1
                let data = photos[uploadedPhotoCount]
                try await env.withToken(for: profile) { token in
                    try await env.apiClient.uploadRecipeAsset(
                        serverURL: profile.serverURL,
                        token: token,
                        slug: slug,
                        name: String(localized: "Recipe Page \(pageNumber)"),
                        icon: "mdi-file-image",
                        fileExtension: "jpg",
                        data: data
                    )
                }
                uploadedPhotoCount += 1
            }
        }

        if usePhotoAsRecipeImage, !recipeImageUploaded, let first = photos.first {
            try await env.withToken(for: profile) { token in
                try await env.apiClient.updateRecipeImage(
                    serverURL: profile.serverURL,
                    token: token,
                    slug: slug,
                    fileExtension: "jpg",
                    data: first
                )
            }
            recipeImageUploaded = true
        }
    }

    private static func message(for error: Error) -> String {
        (error as? AppError)?.errorDescription ?? error.localizedDescription
    }
}
