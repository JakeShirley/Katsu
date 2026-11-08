import SwiftUI

/// Full-screen placeholder for a feature the active Mealie server is too old
/// to support (CON-014).
struct ServerUpdateRequiredView: View {
    let feature: MealieFeature
    let serverVersion: String?

    var body: some View {
        ContentUnavailableView {
            Label("Update your Mealie server", systemImage: "arrow.up.circle")
        } description: {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(verbatim: feature.localizedName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(ServerUpdateCopy.requirement(for: feature, serverVersion: serverVersion))
                Text("Ask your Mealie admin to update the server.")
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Inline footer explaining why a control is hidden on an older server.
struct ServerUpdateNotice: View {
    let feature: MealieFeature
    let serverVersion: String?

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(verbatim: feature.localizedName)
                    .fontWeight(.semibold)
                Text(ServerUpdateCopy.requirement(for: feature, serverVersion: serverVersion))
            }
        } icon: {
            Image(systemName: "arrow.up.circle")
                .accessibilityHidden(true)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

enum ServerUpdateCopy {
    static func displayVersion(_ rawVersion: String?) -> String {
        guard let rawVersion, !rawVersion.isEmpty else {
            return String(localized: "an unknown version")
        }
        return MealieServerVersion(rawVersion)?.description ?? rawVersion
    }

    static func requirement(for feature: MealieFeature, serverVersion: String?) -> String {
        let required = feature.minimumVersion.description
        let current = displayVersion(serverVersion)
        return String(localized: "Requires Mealie \(required) or newer. This server runs \(current).")
    }
}
