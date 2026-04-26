import SwiftUI

/// Two-step onboarding: server URL → login. Once a session is established
/// the parent `RootView` navigates to `HomeView` automatically.
struct OnboardingFlowView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var validatedProfile: ServerProfile?
    @State private var serverInfo: MealieServerInfo?

    var body: some View {
        NavigationStack {
            if let profile = validatedProfile {
                LoginView(profile: profile, serverInfo: serverInfo) {
                    validatedProfile = nil
                    serverInfo = nil
                }
            } else {
                ServerURLEntryView { profile, info in
                    serverInfo = info
                    validatedProfile = profile
                }
            }
        }
    }
}

// MARK: - Server URL entry

private struct ServerURLEntryView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var urlText: String = ""
    @State private var isValidating = false
    @State private var errorMessage: String?
    let onValidated: (ServerProfile, MealieServerInfo) -> Void

    var body: some View {
        Form {
            Section {
                Text("Connect to your Mealie server to get started.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Section("Server URL") {
                TextField("https://mealie.example.com", text: $urlText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .submitLabel(.go)
                    .onSubmit(validate)
                    .accessibilityLabel("Mealie server URL")
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }

            Section {
                Button {
                    validate()
                } label: {
                    if isValidating {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Connecting…")
                        }
                    } else {
                        Text("Continue")
                    }
                }
                .disabled(isValidating || urlText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Welcome to Katsu")
        .onAppear {
            if let preset = env.configuration.initialServerURL?.absoluteString,
               urlText.isEmpty {
                urlText = preset
            }
        }
    }

    private func validate() {
        let trimmed = urlText.trimmingCharacters(in: .whitespaces)
        guard let url = normalizedURL(from: trimmed) else {
            errorMessage = AppError.invalidURL.errorDescription
            return
        }
        urlText = url.absoluteString
        errorMessage = nil
        isValidating = true

        Task {
            defer { isValidating = false }
            do {
                let info = try await env.apiClient.fetchServerInfo(serverURL: url)
                let profile = ServerProfile(
                    displayName: url.host ?? trimmed,
                    serverURL: url,
                    version: info.version
                )
                onValidated(profile, info)
            } catch let error as AppError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func normalizedURL(from raw: String) -> URL? {
        var candidate = raw
        if !candidate.contains("://") {
            candidate = "https://" + candidate
        }
        guard let url = URL(string: candidate),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()),
              url.host != nil else {
            return nil
        }
        return url
    }
}

// MARK: - Login

private struct LoginView: View {
    @EnvironmentObject private var env: AppEnvironment
    let profile: ServerProfile
    let serverInfo: MealieServerInfo?
    let onBack: () -> Void

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                LabeledContent("Server", value: profile.displayName)
                if let version = serverInfo?.version {
                    LabeledContent("Version", value: version)
                }
            }

            Section("Sign in") {
                TextField("Username or email", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                SecureField("Password", text: $password)
                    .submitLabel(.go)
                    .onSubmit(submit)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                }
            }

            Section {
                Button {
                    submit()
                } label: {
                    if isSubmitting {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Signing in…")
                        }
                    } else {
                        Text("Sign In")
                    }
                }
                .disabled(isSubmitting || username.isEmpty || password.isEmpty)
            }
        }
        .navigationTitle("Sign in")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Change Server", action: onBack)
            }
        }
    }

    private func submit() {
        guard !password.isEmpty else {
            errorMessage = AppError.missingPassword.errorDescription
            return
        }
        errorMessage = nil
        isSubmitting = true

        Task {
            defer { isSubmitting = false }
            do {
                let token = try await env.apiClient.login(
                    serverURL: profile.serverURL,
                    username: username,
                    password: password
                )
                let user = try await env.apiClient.fetchCurrentUser(
                    serverURL: profile.serverURL,
                    token: token
                )
                var saved = profile
                saved.lastUsername = username
                env.adoptAuthenticatedSession(profile: saved, token: token, user: user)
            } catch let error as AppError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
