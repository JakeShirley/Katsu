import SwiftUI

struct ImportRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var env: AppEnvironment
    @State private var urlText = ""
    @State private var includeTags = true
    @State private var includeCategories = true
    @State private var isImporting = false
    @State private var errorMessage: String?

    let onImported: () async -> Void

    private var supportsCategories: Bool {
        env.supports(.importRecipeCategories)
    }

    var body: some View {
        Form {
            Section {
                Text("Paste a recipe URL and Katsu will ask Mealie to import it.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Section("Recipe URL") {
                TextField("https://example.com/recipe", text: $urlText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .onSubmit(importRecipe)
                    .accessibilityLabel("Recipe URL")
            }

            Section {
                Toggle("Include tags", isOn: $includeTags)
                if supportsCategories {
                    Toggle("Include categories", isOn: $includeCategories)
                }
            } header: {
                Text("Import Options")
            } footer: {
                if !supportsCategories {
                    ServerUpdateNotice(feature: .importRecipeCategories, serverVersion: env.activeProfile?.version)
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.Colors.destructive)
                }
            }

            Section {
                Button {
                    importRecipe()
                } label: {
                    if isImporting {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ProgressView()
                            Text("Importing recipe…")
                        }
                    } else {
                        Text("Import Recipe")
                    }
                }
                .disabled(isImporting || urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .frame(minHeight: DesignSystem.HitTarget.minimum)
            }
        }
        .navigationTitle("Import Recipe")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
    }

    private func importRecipe() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil, url.host != nil else {
            errorMessage = String(localized: "Enter a valid recipe URL.")
            return
        }
        guard let profile = env.activeProfile else { return }
        guard !isImporting else { return }

        errorMessage = nil
        isImporting = true
        Task {
            defer { isImporting = false }
            do {
                _ = try await env.withToken(for: profile) { token in
                    try await env.apiClient.importRecipeFromURL(
                        serverURL: profile.serverURL,
                        token: token,
                        url: url,
                        includeTags: includeTags,
                        includeCategories: supportsCategories && includeCategories
                    )
                }
                await onImported()
                dismiss()
            } catch let error as AppError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
