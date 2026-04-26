import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var confirmSignOut = false

    var body: some View {
        Form {
            if let profile = env.activeProfile {
                Section("Active Server") {
                    LabeledContent("Name", value: profile.displayName)
                    LabeledContent("URL", value: profile.serverURL.absoluteString)
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
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
