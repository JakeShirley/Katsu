import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.dismiss) private var dismiss
    @State private var confirmClearOfflineRecipes = false
    @State private var showAddServer = false
    @State private var revealedServerID: UUID?

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
                                    } label: {
                                        SettingsRowContent(
                                            title: Text(verbatim: profile.displayName),
                                            subtitle: Text(verbatim: profile.serverURL.absoluteString),
                                            systemImage: "server.rack",
                                            accessory: profile.id == env.activeProfile?.id ? .checkmark : .none
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
                        SettingsRowContent(
                            title: Text("Recipes Cached"),
                            systemImage: "book.closed",
                            accessory: .value(env.recipeCacheSnapshot.recipeCount.formatted())
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

                        if env.isSyncingOfflineRecipes {
                            SettingsDivider()

                            HStack(spacing: DesignSystem.Spacing.md) {
                                ProgressView()
                                    .frame(width: DesignSystem.HitTarget.minimum, height: DesignSystem.HitTarget.minimum)

                                Text("Syncing offline recipes…")
                                    .foregroundStyle(.secondary)

                                Spacer(minLength: DesignSystem.Spacing.md)
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Syncing offline recipes")
                        }

                        SettingsDivider()

                        Button {
                            Task { await env.syncOfflineRecipes(force: true) }
                        } label: {
                            SettingsRowContent(
                                title: Text("Sync Offline Recipes"),
                                systemImage: "arrow.triangle.2.circlepath",
                                accessory: .chevron
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(env.activeProfile == nil || env.isSyncingOfflineRecipes)

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
                        .disabled(env.recipeCacheSnapshot.byteCount == 0)
                    }
                }

                SettingsSection("About") {
                    SettingsGroup {
                        NavigationLink {
                            ChangelogView()
                        } label: {
                            SettingsRowContent(
                                title: Text("Changelog"),
                                systemImage: "sparkles",
                                accessory: .chevron
                            )
                        }
                        .buttonStyle(.plain)

                        SettingsDivider()

                        SettingsRowContent(
                            title: Text("App"),
                            systemImage: "app.badge",
                            accessory: .value("Katsu")
                        )

                        SettingsDivider()

                        SettingsRowContent(
                            title: Text("Bundle"),
                            systemImage: "shippingbox",
                            accessory: .value(Bundle.main.bundleIdentifier ?? "—")
                        )
                    }
                }

            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .background(DesignSystem.Colors.background)
        .scrollContentBackground(.hidden)
    }

    private func serverAccessibilityLabel(for profile: ServerProfile) -> String {
        let status = profile.id == env.activeProfile?.id ? String(localized: "Active") : String(localized: "Inactive")
        return String(localized: "\(profile.displayName), \(profile.serverURL.absoluteString), \(status)")
    }

    private func removeServer(_ profile: ServerProfile) {
        env.removeServer(profile)
        if !env.hasServerProfiles {
            dismiss()
        }
    }
}

private struct SwipeToRemoveRow<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var isRevealed: Bool
    let onRemove: () -> Void
    @ViewBuilder let content: Content

    @State private var dragTranslation: CGFloat = 0

    private let actionWidth: CGFloat = 112

    init(isRevealed: Binding<Bool>, onRemove: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self._isRevealed = isRevealed
        self.onRemove = onRemove
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            Button(role: .destructive, action: onRemove) {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "trash")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 70, height: 42)
                        .background(DesignSystem.Colors.destructive, in: Capsule())
                        .scaleEffect(actionScale)

                    Text("Delete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .opacity(actionLabelOpacity)
                }
                .frame(width: actionWidth)
                .frame(minHeight: DesignSystem.HitTarget.minimum + DesignSystem.Spacing.xl)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete")
            .accessibilityHidden(!isRevealed)
            .opacity(actionOpacity)

            content
                .frame(maxWidth: .infinity)
                .background(DesignSystem.Colors.surface)
                .offset(x: rowOffset)
                .highPriorityGesture(removeRevealGesture)
                .animation(reduceMotion ? nil : DesignSystem.Motion.standard, value: isRevealed)
                .animation(reduceMotion ? nil : DesignSystem.Motion.standard, value: dragTranslation)
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var rowOffset: CGFloat {
        let baseOffset = isRevealed ? -actionWidth : 0
        return min(0, max(-actionWidth, baseOffset + dragTranslation))
    }

    private var actionProgress: CGFloat {
        min(1, max(0, abs(rowOffset) / actionWidth))
    }

    private var actionScale: CGFloat {
        0.72 + (actionProgress * 0.28)
    }

    private var actionOpacity: CGFloat {
        min(1, max(0, (actionProgress - 0.15) / 0.85))
    }

    private var actionLabelOpacity: CGFloat {
        min(1, max(0, (actionProgress - 0.35) / 0.65))
    }

    private var removeRevealGesture: some Gesture {
        DragGesture(minimumDistance: DesignSystem.Spacing.sm)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let baseOffset = isRevealed ? -actionWidth : 0
                dragTranslation = min(0, max(-actionWidth, baseOffset + value.translation.width)) - baseOffset
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    dragTranslation = 0
                    return
                }
                let baseOffset = isRevealed ? -actionWidth : 0
                let projectedOffset = baseOffset + value.translation.width + (value.predictedEndTranslation.width - value.translation.width) * 0.25
                isRevealed = projectedOffset < -actionWidth / 2
                dragTranslation = 0
            }
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
    case value(String)
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
