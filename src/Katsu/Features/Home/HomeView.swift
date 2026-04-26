import SwiftUI

/// v0 home screen. Shows who's signed in and to which server. Recipe / meal
/// plan / shopping list features land in later milestones — see
/// `docs/MEALIE_IOS_PROJECT_PLAN.md`.
struct HomeView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var showSettings = false
    @State private var loadError: String?
    @State private var isLoadingUser = false

    var body: some View {
        NavigationStack {
            List {
                if let profile = env.activeProfile {
                    Section("Connected Server") {
                        LabeledContent("Name", value: profile.displayName)
                        LabeledContent("URL", value: profile.serverURL.absoluteString)
                        if let version = profile.version {
                            LabeledContent("Version", value: version)
                        }
                    }
                }

                Section("Signed in as") {
                    if let user = env.currentUser {
                        LabeledContent("Username", value: user.username)
                        if let name = user.fullName, !name.isEmpty {
                            LabeledContent("Name", value: name)
                        }
                        if let email = user.email {
                            LabeledContent("Email", value: email)
                        }
                        if user.admin == true {
                            Label("Administrator", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(DesignSystem.accent)
                        }
                    } else if isLoadingUser {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Loading account…")
                        }
                    } else if let loadError {
                        Text(loadError).foregroundStyle(.red)
                    } else {
                        Text("Not loaded yet").foregroundStyle(.secondary)
                    }
                }

                Section {
                    Text("Recipes, meal plans, and shopping lists are coming soon.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Katsu")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .task(id: env.activeProfile?.id) {
                await refreshUserIfNeeded()
            }
            .refreshable {
                await refreshUser(force: true)
            }
            .onAppear {
                if env.configuration.openSettingsOnLaunch {
                    showSettings = true
                }
            }
        }
    }

    private func refreshUserIfNeeded() async {
        if env.currentUser == nil {
            await refreshUser(force: true)
        }
    }

    private func refreshUser(force: Bool) async {
        guard let profile = env.activeProfile else { return }
        guard let token = try? env.credentialStore.loadToken(for: profile.id) else {
            loadError = AppError.unauthorized.errorDescription
            return
        }
        isLoadingUser = true
        defer { isLoadingUser = false }
        do {
            let user = try await env.apiClient.fetchCurrentUser(
                serverURL: profile.serverURL,
                token: token
            )
            env.currentUser = user
            loadError = nil
        } catch let error as AppError {
            loadError = error.errorDescription
        } catch {
            loadError = error.localizedDescription
        }
    }
}
