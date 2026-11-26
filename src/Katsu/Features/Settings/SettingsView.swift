import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var showAddServer = false
    @State private var profileToSignIn: ServerProfile?
    @State private var revealedServerID: UUID?

    private var profiles: [ServerProfile] {
        env.profileStore.allProfiles()
    }

    var body: some View {
        settingsForm
        .navigationTitle("Settings")
        .navigationDestination(isPresented: $showAddServer) {
            OnboardingFlowView {
                showAddServer = false
            }
        }
        .navigationDestination(item: $profileToSignIn) { profile in
            ReauthenticationView(profile: profile) {
                profileToSignIn = nil
            }
        }
    }

    private var settingsForm: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxl) {
                SettingsSection("Servers") {
                    SettingsGroup {
                        if profiles.isEmpty {
                            SettingsRowContent(
                                title: Text("No servers added"),
                                systemImage: "server.rack",
                                accessory: .none
                            )
                        } else {
                            ForEach(Array(profiles.enumerated()), id: \.element.id) { index, profile in
                                SwipeToRemoveRow(
                                    isRevealed: Binding(
                                        get: { revealedServerID == profile.id },
                                        set: { isRevealed in
                                            revealedServerID = isRevealed ? profile.id : nil
                                        }
                                    ),
                                    onRemove: { removeServer(profile) }
                                ) {
                                    Button {
                                        revealedServerID = nil
                                        env.switchToProfile(profile)
                                        showSignInIfNeeded(for: profile)
                                    } label: {
                                        SettingsRowContent(
                                            title: Text(verbatim: profile.displayName),
                                            subtitle: serverSubtitle(for: profile),
                                            systemImage: "server.rack",
                                            accessory: serverAccessory(for: profile)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(serverAccessibilityLabel(for: profile))
                                    .accessibilityAction(named: Text("Delete")) {
                                        removeServer(profile)
                                    }
                                }

                                if index < profiles.count - 1 {
                                    SettingsDivider()
                                }
                            }
                        }

                        SettingsDivider()

                        Button {
                            showAddServer = true
                        } label: {
                            SettingsRowContent(
                                title: Text("Add Server"),
                                systemImage: "plus.circle",
                                accessory: .chevron
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                SettingsSection("Offline Recipes") {
                    SettingsGroup {
                        NavigationLink {
                            StorageSettingsView()
                        } label: {
                            SettingsRowContent(
                                title: Text("Storage"),
                                systemImage: "internaldrive",
                                accessory: .chevron
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                SettingsSection("Layout") {
                    SettingsGroup {
                        NavigationLink {
                            LayoutSettingsView()
                        } label: {
                            SettingsRowContent(
                                title: Text("Tabs"),
                                systemImage: "rectangle.3.group",
                                accessory: .chevron
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                AppVersionFooter()

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "sparkles")
                        .accessibilityHidden(true)
                    Text("Made with Copilot")
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Made with Copilot"))
                .frame(maxWidth: .infinity)
            }
            .readableContentWidth()
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .background(DesignSystem.Colors.background)
        .scrollContentBackground(.hidden)
    }

    private func serverAccessibilityLabel(for profile: ServerProfile) -> String {
        let status = profile.id == env.activeProfile?.id ? String(localized: "Active") : String(localized: "Inactive")
        if env.authenticationIssueProfileIDs.contains(profile.id) {
            let issue = String(localized: "Sign in needed")
            return String(localized: "\(profile.displayName), \(profile.serverURL.absoluteString), \(status), \(issue)")
        }
        return String(localized: "\(profile.displayName), \(profile.serverURL.absoluteString), \(status)")
    }

    private func serverSubtitle(for profile: ServerProfile) -> Text {
        if env.authenticationIssueProfileIDs.contains(profile.id) {
            return Text("Sign in needed")
        }
        return Text(verbatim: profile.serverURL.absoluteString)
    }

    private func serverAccessory(for profile: ServerProfile) -> SettingsRowAccessory {
        if env.authenticationIssueProfileIDs.contains(profile.id) {
            return .warning
        }
        return profile.id == env.activeProfile?.id ? .checkmark : .none
    }

    private func showSignInIfNeeded(for profile: ServerProfile) {
        if env.authenticationIssueProfileIDs.contains(profile.id) {
            profileToSignIn = profile
        }
    }

    private func removeServer(_ profile: ServerProfile) {
        env.removeServer(profile)
        if !env.hasServerProfiles {
            dismiss()
        }
    }
}

private struct LayoutSettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var tabLayout = HomeTabLayoutItem.defaultLayout

    var body: some View {
        List {
            Section("Tabs") {
                ForEach($tabLayout) { $item in
                    if item.tab.isRequired {
                        HomeTabLayoutRow(item: item)
                            .accessibilityLabel(Text(item.tab.title))
                    } else {
                        Toggle(isOn: Binding(
                            get: { item.isEnabled },
                            set: { isEnabled in
                                item.isEnabled = isEnabled
                                saveLayout()
                            }
                        )) {
                            HomeTabLayoutRow(item: item)
                        }
                        .accessibilityLabel(Text(item.tab.title))
                    }
                }
                .onMove { source, destination in
                    tabLayout.move(fromOffsets: source, toOffset: destination)
                    saveLayout()
                }
            }
        }
        .listStyle(.insetGrouped)
        .readableListContentWidth()
        .background(DesignSystem.Colors.background)
        .scrollContentBackground(.hidden)
        .navigationTitle("Layout")
        .environment(\.editMode, .constant(.active))
        .onAppear {
            tabLayout = HomeTabLayoutItem.normalized(env.tabLayout)
        }
        .onChange(of: env.tabLayout) { _, newLayout in
            let normalizedLayout = HomeTabLayoutItem.normalized(newLayout)
            if tabLayout != normalizedLayout {
                tabLayout = normalizedLayout
            }
        }
    }

    private func saveLayout() {
        tabLayout = HomeTabLayoutItem.normalized(tabLayout)
        env.updateTabLayout(tabLayout)
    }
}

private struct HomeTabLayoutRow: View {
    let item: HomeTabLayoutItem

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: item.tab.systemImage)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                .background(DesignSystem.Colors.background, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(item.tab.title)
                    .font(.body)
            }
        }
        .frame(minHeight: DesignSystem.HitTarget.minimum)
    }
}

private struct StorageSettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var confirmClearOfflineRecipes = false

    private var cacheSizeText: String {
        ByteCountFormatter.string(fromByteCount: env.allRecipeCacheSnapshot.byteCount, countStyle: .file)
    }

    private var lastSyncText: String {
        guard let lastUpdated = env.allRecipeCacheSnapshot.lastUpdated else {
            return String(localized: "Never")
        }
        return lastUpdated.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxl) {
                SettingsSection("Offline Recipes") {
                    SettingsGroup {
                        SettingsRowContent(
                            title: Text("Recipes Cached"),
                            systemImage: "book.closed",
                            accessory: .value(env.allRecipeCacheSnapshot.recipeCount.formatted())
                        )

                        SettingsDivider()

                        SettingsRowContent(
                            title: Text("Storage Used"),
                            systemImage: "internaldrive",
                            accessory: .value(cacheSizeText)
                        )

                        SettingsDivider()

                        SettingsRowContent(
                            title: Text("Last Updated"),
                            systemImage: "clock.arrow.circlepath",
                            accessory: .value(lastSyncText)
                        )

                        SettingsDivider()

                        Button(role: .destructive) {
                            confirmClearOfflineRecipes = true
                        } label: {
                            SettingsRowContent(
                                title: Text("Clear Offline Recipes"),
                                systemImage: "trash",
                                accessory: .none,
                                isDestructive: true
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(env.allRecipeCacheSnapshot.byteCount == 0)
                    }

                    Button {
                        Task { await env.syncOfflineRecipes(force: true) }
                    } label: {
                        ZStack(alignment: .bottomLeading) {
                            Label("Download Recipes", systemImage: "arrow.down.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: DesignSystem.HitTarget.minimum)

                            if env.isSyncingOfflineRecipes {
                                ProgressView(value: env.offlineRecipeSyncProgress ?? 0, total: 1)
                                    .progressViewStyle(.linear)
                                    .tint(.white)
                                    .padding(.horizontal, DesignSystem.Spacing.lg)
                                    .padding(.bottom, DesignSystem.Spacing.xs)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(env.activeProfile == nil || env.isSyncingOfflineRecipes)
                    .accessibilityLabel(env.isSyncingOfflineRecipes ? downloadProgressAccessibilityLabel : String(localized: "Download Recipes"))
                }
            }
            .readableContentWidth()
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .background(DesignSystem.Colors.background)
        .scrollContentBackground(.hidden)
        .navigationTitle("Storage")
        .task(id: env.activeProfile?.id) {
            env.refreshAllRecipeCacheSnapshot()
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

    private var downloadProgressText: String {
        guard let progress = env.offlineRecipeSyncProgress else {
            return String(localized: "Downloading recipes…")
        }
        return progress.formatted(.percent.precision(.fractionLength(0)))
    }

    private var downloadProgressAccessibilityLabel: String {
        String(localized: "Downloading recipes, \(downloadProgressText)")
    }
}

private struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DesignSystem.Spacing.lg)

            content
        }
    }
}

private struct SettingsGroup<Content: View>: View {
    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity)
        .background(
            DesignSystem.Colors.surface,
            in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg * 1.5, style: .continuous)
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.lg * 1.5, style: .continuous))
    }
}

private struct SettingsRowContent: View {
    let title: Text
    var subtitle: Text?
    let systemImage: String
    let accessory: SettingsRowAccessory
    var isDestructive = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: systemImage)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(rowTint)
                .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)
                .background(DesignSystem.Colors.background, in: RoundedRectangle(cornerRadius: DesignSystem.Radius.md, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                title
                    .font(.body)
                    .foregroundStyle(rowTint)

                if let subtitle {
                    subtitle
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: DesignSystem.Spacing.md)

            accessoryView
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: DesignSystem.HitTarget.minimum + DesignSystem.Spacing.xl)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var rowTint: Color {
        isDestructive ? DesignSystem.Colors.destructive : DesignSystem.Colors.textPrimary
    }

    @ViewBuilder private var accessoryView: some View {
        switch accessory {
        case .none:
            EmptyView()
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        case .checkmark:
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.accent)
                .accessibilityHidden(true)
        case .warning:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.destructive)
                .accessibilityHidden(true)
        case .value(let value):
            Text(verbatim: value)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

private enum SettingsRowAccessory {
    case none
    case chevron
    case checkmark
    case warning
    case value(String)
}

private struct ReauthenticationView: View {
    @EnvironmentObject private var env: AppEnvironment
    let profile: ServerProfile
    let onConnected: () -> Void

    @State private var authMethod: ServerAuthMethod
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var apiToken: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(profile: ServerProfile, onConnected: @escaping () -> Void) {
        self.profile = profile
        self.onConnected = onConnected
        _authMethod = State(initialValue: profile.resolvedAuthMethod)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Server", value: profile.displayName)
                Text(introText)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

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
        .onAppear {
            username = profile.lastUsername ?? username
        }
        .onChange(of: authMethod) {
            errorMessage = nil
        }
    }

    private var introText: LocalizedStringKey {
        switch profile.resolvedAuthMethod {
        case .password:
            "Sign in again to restore syncing with this Mealie server. Offline recipes stay available on this device."
        case .apiToken:
            "Your API token was rejected. Paste a new token to restore syncing with this Mealie server. Offline recipes stay available on this device."
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

private struct AppVersionFooter: View {
    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let shortVersion = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "Katsu \(shortVersion) (\(build))"
    }

    var body: some View {
        NavigationLink {
            ChangelogView()
        } label: {
            Text(verbatim: versionText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: DesignSystem.HitTarget.minimum)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("App version \(versionText), opens changelog"))
        .accessibilityAddTraits(.isButton)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, DesignSystem.Spacing.lg + DesignSystem.HitTarget.minimum + DesignSystem.Spacing.md)
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
