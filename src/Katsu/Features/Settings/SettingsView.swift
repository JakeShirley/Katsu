import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var confirmSignOut = false
    @State private var confirmClearOfflineRecipes = false
    @State private var showAddServer = false

    private var profiles: [ServerProfile] {
        env.profileStore.allProfiles()
    }

    private var cacheSizeText: String {
        ByteCountFormatter.string(fromByteCount: env.recipeCacheSnapshot.byteCount, countStyle: .file)
    }

    private var lastSyncText: String {
        guard let lastUpdated = env.recipeCacheSnapshot.lastUpdated else {
            return String(localized: "Never")
        }
        return lastUpdated.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        settingsForm
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .confirmationDialog(
            "Sign out and remove this server from this device?",
            isPresented: $confirmSignOut,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                env.signOut()
                if !env.hasServerProfiles {
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .navigationDestination(isPresented: $showAddServer) {
            OnboardingFlowView {
                showAddServer = false
            }
        }
        .task(id: env.activeProfile?.id) {
            env.refreshRecipeCacheSnapshot()
        }
        .background {
            DestructiveConfirmationPresenter(
                isPresented: $confirmClearOfflineRecipes,
                title: String(localized: "Clear offline recipes from this device?"),
                message: String(localized: "Recipes will stay on your Mealie server, but cached copies and images on this device will be removed."),
                destructiveTitle: String(localized: "Clear Offline Recipes"),
                onConfirm: env.clearOfflineRecipes
            )
            .frame(width: 0, height: 0)
        }
    }

    private var settingsForm: some View {
        Form {
            Section("Servers") {
                if profiles.isEmpty {
                    Text("No servers added")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(profiles) { profile in
                        Button {
                            env.switchToProfile(profile)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.md) {
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text(profile.displayName)
                                        .foregroundStyle(.primary)
                                    Text(profile.serverURL.absoluteString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if profile.id == env.activeProfile?.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(DesignSystem.Colors.accent)
                                        .accessibilityHidden(true)
                                }
                            }
                            .frame(minHeight: DesignSystem.HitTarget.minimum)
                        }
                        .accessibilityLabel(serverAccessibilityLabel(for: profile))
                    }
                }

                Button {
                    showAddServer = true
                } label: {
                    Label("Add Server", systemImage: "plus.circle")
                        .frame(minHeight: DesignSystem.HitTarget.minimum)
                }
            }

            Section("Offline Recipes") {
                LabeledContent("Recipes Cached", value: env.recipeCacheSnapshot.recipeCount.formatted())
                LabeledContent("Storage Used", value: cacheSizeText)
                LabeledContent("Last Updated", value: lastSyncText)

                if env.isSyncingOfflineRecipes {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ProgressView()
                        Text("Syncing offline recipes…")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Syncing offline recipes")
                }

                Button {
                    Task { await env.syncOfflineRecipes(force: true) }
                } label: {
                    Label("Sync Offline Recipes", systemImage: "arrow.triangle.2.circlepath")
                        .frame(minHeight: DesignSystem.HitTarget.minimum)
                }
                .disabled(env.activeProfile == nil || env.isSyncingOfflineRecipes)

                Button(role: .destructive) {
                    confirmClearOfflineRecipes = true
                } label: {
                    Label("Clear Offline Recipes", systemImage: "trash")
                        .frame(minHeight: DesignSystem.HitTarget.minimum)
                }
                .disabled(env.recipeCacheSnapshot.byteCount == 0)
            }

            Section("About") {
                NavigationLink("Changelog") {
                    ChangelogView()
                }
                LabeledContent("App", value: "Katsu")
                LabeledContent("Bundle", value: Bundle.main.bundleIdentifier ?? "—")
            }

            Section {
                Button(role: .destructive) {
                    confirmSignOut = true
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(minHeight: DesignSystem.HitTarget.minimum)
                }
            }
        }
    }

    private func serverAccessibilityLabel(for profile: ServerProfile) -> String {
        let status = profile.id == env.activeProfile?.id ? String(localized: "Active") : String(localized: "Inactive")
        return String(localized: "\(profile.displayName), \(profile.serverURL.absoluteString), \(status)")
    }
}

private struct DestructiveConfirmationPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let destructiveTitle: String
    let onConfirm: () -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ viewController: UIViewController, context: Context) {
        guard isPresented, viewController.presentedViewController == nil else { return }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: destructiveTitle, style: .destructive) { _ in
            isPresented = false
            onConfirm()
        })
        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel) { _ in
            isPresented = false
        })

        viewController.present(alert, animated: true)
    }
}
