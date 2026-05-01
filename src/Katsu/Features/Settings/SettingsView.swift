import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var confirmSignOut = false
    @State private var showAddServer = false

    private var profiles: [ServerProfile] {
        env.profileStore.allProfiles()
    }

    var body: some View {
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
    }

    private func serverAccessibilityLabel(for profile: ServerProfile) -> String {
        let status = profile.id == env.activeProfile?.id ? String(localized: "Active") : String(localized: "Inactive")
        return String(localized: "\(profile.displayName), \(profile.serverURL.absoluteString), \(status)")
    }
}
