import SwiftUI

/// Two-step onboarding: server URL → login. Once a session is established
/// the parent `RootView` navigates to `HomeView` automatically.
struct OnboardingFlowView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var validatedProfile: ServerProfile?
    @State private var serverInfo: MealieServerInfo?
    let onConnected: (() -> Void)?

    init(onConnected: (() -> Void)? = nil) {
        self.onConnected = onConnected
    }

    var body: some View {
        if let profile = validatedProfile {
            LoginView(profile: profile, serverInfo: serverInfo) {
                validatedProfile = nil
                serverInfo = nil
            } onConnected: {
                onConnected?()
            }
        } else {
            ServerURLEntryView { profile, info in
                serverInfo = info
                validatedProfile = profile
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
        .readableListContentWidth(AdaptiveLayout.formMaxWidth)
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
    let onConnected: () -> Void

    @State private var authMethod: ServerAuthMethod
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var apiToken: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(
        profile: ServerProfile,
        serverInfo: MealieServerInfo?,
        onBack: @escaping () -> Void,
        onConnected: @escaping () -> Void
    ) {
        self.profile = profile
        self.serverInfo = serverInfo
        self.onBack = onBack
        self.onConnected = onConnected
        _authMethod = State(initialValue: serverInfo?.prefersAPITokenSignIn == true ? .apiToken : .password)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Server", value: profile.displayName)
                if let version = serverInfo?.version {
                    LabeledContent("Version", value: version)
                }
            }

            ServerVersionWarningSection(serverVersion: serverInfo?.version)

            SignInCredentialFields(
                authMethod: $authMethod,
                username: $username,
                password: $password,
                apiToken: $apiToken,
                onSubmit: submit
            )

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(DesignSystem.Colors.destructive)
                        .font(.subheadline)
                }
            }

            Section {
                Button {
                    submit()
                } label: {
                    if isSubmitting {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ProgressView()
                            Text("Signing in…")
                        }
                    } else {
                        Text("Sign In")
                    }
                }
                .disabled(isSubmitting || !SignInCredentialFields.canSubmit(
                    authMethod: authMethod,
                    username: username,
                    password: password,
                    apiToken: apiToken
                ))
            }
        }
        .readableListContentWidth(AdaptiveLayout.formMaxWidth)
        .navigationTitle("Sign in")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Change Server", action: onBack)
            }
        }
        .onChange(of: authMethod) {
            errorMessage = nil
        }
    }

    private func submit() {
        guard !isSubmitting else { return }
        errorMessage = nil
        isSubmitting = true

        Task {
            defer { isSubmitting = false }
            do {
                try await env.signIn(
                    profile: profile,
                    method: authMethod,
                    username: username,
                    password: password,
                    apiToken: apiToken
                )
                onConnected()
            } catch let error as AppError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Shared sign-in fields

/// Password vs. long-lived API token (CON-013) sign-in fields, shared by
/// onboarding and the Settings re-authentication screen.
struct SignInCredentialFields: View {
    @Binding var authMethod: ServerAuthMethod
    @Binding var username: String
    @Binding var password: String
    @Binding var apiToken: String
    let onSubmit: () -> Void

    static func canSubmit(authMethod: ServerAuthMethod, username: String, password: String, apiToken: String) -> Bool {
        switch authMethod {
        case .password:
            !username.isEmpty && !password.isEmpty
        case .apiToken:
            MealieAuthToken(apiToken: apiToken) != nil
        }
    }

    var body: some View {
        Section {
            Picker("Sign-in method", selection: $authMethod) {
                Text("Password").tag(ServerAuthMethod.password)
                Text("API Token").tag(ServerAuthMethod.apiToken)
            }
            .pickerStyle(.segmented)
            .frame(minHeight: DesignSystem.HitTarget.minimum)
        }

        switch authMethod {
        case .password:
            Section("Sign in") {
                TextField("Username or email", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                SecureField("Password", text: $password)
                    .submitLabel(.go)
                    .onSubmit(onSubmit)
            }
        case .apiToken:
            Section {
                SecureField("Paste API token", text: $apiToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(onSubmit)
                    .accessibilityLabel("Mealie API token")
            } header: {
                Text("API Token")
            } footer: {
                Text("Create a long-lived token in Mealie under your profile's API Tokens page. Use this when your server signs in through a reverse proxy or doesn't allow password login.")
            }
        }
    }
}

// MARK: - Server version warning

/// Warns at sign-in when the server is older than the release Katsu needs
/// for every feature (CON-014). Renders nothing for current or unknown
/// versions.
struct ServerVersionWarningSection: View {
    let serverVersion: String?

    private var unsupportedFeatures: [MealieFeature] {
        MealieFeature.allCases.filter { !$0.isSupported(byServerVersion: serverVersion) }
    }

    var body: some View {
        if !unsupportedFeatures.isEmpty {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Update your Mealie server")
                            .font(.headline)
                        Text(versionMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(DesignSystem.Colors.warning)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var versionMessage: String {
        let current = ServerUpdateCopy.displayVersion(serverVersion)
        let recommended = MealieFeature.recommendedMinimumVersion.description
        let features = unsupportedFeatures.map(\.localizedName).formatted(.list(type: .and))
        return String(localized: "This server runs Mealie \(current). Katsu works best with Mealie \(recommended) or newer. Unavailable until you update: \(features).")
    }
}
