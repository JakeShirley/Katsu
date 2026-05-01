import Foundation
import SwiftUI

struct ChangelogView: View {
    @StateObject private var viewModel = ChangelogViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.entries.isEmpty {
                ProgressView("Loading changelog")
            } else if let error = viewModel.loadError {
                ContentUnavailableView(
                    "Changelog Unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if viewModel.entries.isEmpty {
                ContentUnavailableView(
                    "No Release Notes Yet",
                    systemImage: "doc.text",
                    description: Text("Release notes will appear here once the first version of Katsu ships.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.lg) {
                        ForEach(Array(viewModel.entries.enumerated()), id: \.element.id) { index, entry in
                            ReleaseCard(entry: entry, isLatest: index == 0)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.md)
                }
                .background(DesignSystem.Colors.background)
            }
        }
        .navigationTitle("Changelog")
        .task {
            await viewModel.load()
        }
    }
}

@MainActor
private final class ChangelogViewModel: ObservableObject {
    struct Entry: Identifiable, Equatable {
        let id = UUID()
        let version: String
        let date: Date?
        let compareURL: URL?
        let body: String

        static func == (lhs: Entry, rhs: Entry) -> Bool {
            lhs.id == rhs.id
        }
    }

    @Published private(set) var entries: [Entry] = []
    @Published private(set) var loadError: String?
    @Published private(set) var isLoading = false

    private var didLoad = false

    func load(bundle: Bundle = .main) async {
        guard !didLoad else { return }
        didLoad = true
        isLoading = true
        defer { isLoading = false }

        do {
            let markdown = try Self.readChangelog(from: bundle)
            entries = Self.parse(markdown: markdown)
        } catch {
            loadError = String(localized: "Could not load changelog: \(error.localizedDescription)")
        }
    }

    private static func readChangelog(from bundle: Bundle) throws -> String {
        guard let url = bundle.url(forResource: "CHANGELOG", withExtension: "md") else {
            throw ChangelogError.missingResource
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func parse(markdown: String) -> [Entry] {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var entries: [Entry] = []
        var currentHeading: String?
        var currentBody: [String] = []

        func flush() {
            guard let heading = currentHeading else { return }
            let body = currentBody
                .map(stripPlanTags)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let parsed = parseHeading(heading)
            entries.append(
                Entry(
                    version: parsed.version,
                    date: parsed.date,
                    compareURL: parsed.compareURL,
                    body: body
                )
            )
            currentBody.removeAll(keepingCapacity: true)
        }

        for line in lines {
            if let heading = releaseHeading(from: line) {
                flush()
                currentHeading = heading
            } else if currentHeading != nil {
                currentBody.append(line)
            }
        }
        flush()

        return entries
    }

    static func stripPlanTags(_ line: String) -> String {
        let pattern = #"\[[A-Z]+-[A-Z0-9]+\](?!\()\s?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return line
        }
        let range = NSRange(line.startIndex..., in: line)
        let stripped = regex.stringByReplacingMatches(in: line, range: range, withTemplate: "")
        return stripped.replacingOccurrences(
            of: #"  +"#,
            with: " ",
            options: .regularExpression
        )
    }

    private static func releaseHeading(from line: String) -> String? {
        let payload: String
        if line.hasPrefix("## ") {
            payload = String(line.dropFirst(3))
        } else if line.hasPrefix("# ") {
            payload = String(line.dropFirst(2))
        } else {
            return nil
        }

        let trimmed = payload.trimmingCharacters(in: .whitespaces)
        let looksLikeRelease = trimmed.range(of: #"\d"#, options: .regularExpression) != nil
            || trimmed.lowercased().hasPrefix("unreleased")
        return looksLikeRelease ? trimmed : nil
    }

    static func parseHeading(_ heading: String) -> (version: String, date: Date?, compareURL: URL?) {
        var working = heading

        var date: Date?
        if let match = working.range(of: #"\s*\((\d{4}-\d{2}-\d{2})\)\s*$"#, options: .regularExpression) {
            let dateString = String(working[match])
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "()"))
            date = isoDateFormatter.date(from: dateString)
            working = String(working[..<match.lowerBound]).trimmingCharacters(in: .whitespaces)
        }

        var compareURL: URL?
        var version = working
        if let match = working.range(of: #"^\[([^\]]+)\]\(([^)]+)\)\s*$"#, options: .regularExpression) {
            let raw = String(working[match])
            if let labelStart = raw.firstIndex(of: "["),
               let labelEnd = raw.firstIndex(of: "]"),
               let urlStart = raw.firstIndex(of: "("),
               let urlEnd = raw.lastIndex(of: ")"),
               labelStart < labelEnd,
               urlStart < urlEnd {
                version = String(raw[raw.index(after: labelStart)..<labelEnd])
                    .trimmingCharacters(in: .whitespaces)
                let urlString = String(raw[raw.index(after: urlStart)..<urlEnd])
                    .trimmingCharacters(in: .whitespaces)
                compareURL = URL(string: urlString)
            }
        }

        if version.isEmpty {
            version = String(localized: "Unreleased")
        }

        return (version, date, compareURL)
    }

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private enum ChangelogError: LocalizedError {
    case missingResource

    var errorDescription: String? {
        switch self {
        case .missingResource:
            String(localized: "CHANGELOG.md is not bundled with this build.")
        }
    }
}

private struct ReleaseCard: View {
    let entry: ChangelogViewModel.Entry
    let isLatest: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            header
            Divider()
            ChangelogEntryBody(markdown: entry.body)
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            DesignSystem.Colors.surface,
            in: RoundedRectangle(cornerRadius: DesignSystem.Radius.lg, style: .continuous)
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    VersionPill(version: entry.version, highlighted: isLatest)
                    if isLatest {
                        Text("Latest")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DesignSystem.Colors.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.accentSoft, in: Capsule())
                    }
                }

                if let dateLabel {
                    Text(dateLabel)
                        .font(.footnote)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }

            Spacer(minLength: DesignSystem.Spacing.sm)

            if let url = entry.compareURL {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                        .font(.title3)
                        .foregroundStyle(DesignSystem.Colors.accent)
                        .frame(minWidth: DesignSystem.HitTarget.minimum, minHeight: DesignSystem.HitTarget.minimum)
                }
                .accessibilityLabel(String(localized: "View release \(entry.version) on GitHub"))
            }
        }
    }

    private var dateLabel: String? {
        guard let date = entry.date else { return nil }
        return Self.dateFormatter.string(from: date)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()
}

private struct VersionPill: View {
    let version: String
    let highlighted: Bool

    var body: some View {
        Text(version)
            .font(.headline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(highlighted ? Color.white : DesignSystem.Colors.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                highlighted
                    ? AnyShapeStyle(DesignSystem.Colors.accent)
                    : AnyShapeStyle(Color(.tertiarySystemGroupedBackground)),
                in: Capsule()
            )
    }
}

private struct ChangelogEntryBody: View {
    let markdown: String

    var body: some View {
        if markdown.isEmpty {
            Text("No notes for this release.")
                .font(.subheadline)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        } else {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    SectionView(section: section)
                }
            }
        }
    }

    private var sections: [Section] {
        var sections: [Section] = []
        var currentTitle: String?
        var currentBullets: [Bullet] = []

        func flush() {
            guard !currentBullets.isEmpty || currentTitle != nil else { return }
            sections.append(Section(title: currentTitle ?? String(localized: "Notes"), bullets: currentBullets))
            currentBullets.removeAll(keepingCapacity: true)
        }

        for rawLine in markdown.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = String(rawLine).trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.hasPrefix("### ") {
                flush()
                currentTitle = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") {
                currentBullets.append(Bullet(rawLine: String(trimmed.dropFirst(2))))
            } else {
                currentBullets.append(Bullet(rawLine: trimmed))
            }
        }
        flush()

        return sections
    }

    struct Section: Identifiable {
        let id = UUID()
        let title: String
        let bullets: [Bullet]

        var iconName: String {
            switch title.lowercased() {
            case let title where title.contains("break"):
                "exclamationmark.octagon.fill"
            case let title where title.contains("feature"):
                "sparkles"
            case let title where title.contains("bug") || title.contains("fix"):
                "ladybug.fill"
            case let title where title.contains("perf"):
                "bolt.fill"
            case let title where title.contains("doc"):
                "book.fill"
            case let title where title.contains("refactor"):
                "arrow.triangle.2.circlepath"
            case let title where title.contains("revert"):
                "arrow.uturn.backward"
            case let title where title.contains("style"):
                "paintbrush.fill"
            case let title where title.contains("test"):
                "checkmark.seal.fill"
            case let title where title.contains("chore") || title.contains("build") || title.contains("ci"):
                "gearshape.fill"
            default:
                "circle.fill"
            }
        }

        var tint: Color {
            switch title.lowercased() {
            case let title where title.contains("break"):
                DesignSystem.Colors.destructive
            case let title where title.contains("feature"):
                DesignSystem.Colors.accent
            case let title where title.contains("bug") || title.contains("fix"):
                DesignSystem.Colors.warning
            case let title where title.contains("perf"):
                Color(.systemYellow)
            case let title where title.contains("doc"):
                Color(.systemBlue)
            case let title where title.contains("refactor"):
                Color(.systemPurple)
            case let title where title.contains("revert"):
                Color(.systemPink)
            default:
                DesignSystem.Colors.textSecondary
            }
        }
    }
}

private struct SectionView: View {
    let section: ChangelogEntryBody.Section

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: section.iconName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(section.tint)
                    .accessibilityHidden(true)
                Text(section.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                ForEach(section.bullets) { bullet in
                    BulletRow(bullet: bullet, tint: section.tint)
                }
            }
        }
    }
}

private struct BulletRow: View {
    let bullet: Bullet
    let tint: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
            Circle()
                .fill(tint.opacity(0.45))
                .frame(width: 5, height: 5)
                .padding(.top, 6)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(bullet.attributedMessage)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let scope = bullet.scope {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Text(scope)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemGroupedBackground), in: Capsule())

                        if let commit = bullet.commit {
                            CommitBadge(commit: commit)
                        }
                    }
                } else if let commit = bullet.commit {
                    CommitBadge(commit: commit)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct CommitBadge: View {
    let commit: Bullet.Commit

    var body: some View {
        Group {
            if let url = commit.url {
                Link(destination: url) { content }
            } else {
                content
            }
        }
        .accessibilityLabel(String(localized: "Commit \(commit.shortHash)"))
    }

    private var content: some View {
        HStack(spacing: 3) {
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .font(.caption2.weight(.semibold))
                .accessibilityHidden(true)
            Text(commit.shortHash)
                .font(.caption2.monospaced())
        }
        .foregroundStyle(DesignSystem.Colors.textSecondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
    }
}

private struct Bullet: Identifiable {
    let id = UUID()
    let scope: String?
    let message: String
    let commit: Commit?

    struct Commit {
        let shortHash: String
        let url: URL?
    }

    init(rawLine: String) {
        var line = rawLine.trimmingCharacters(in: .whitespaces)

        if let match = line.range(of: #"^\*\*([^*]+?)\*\*:?\s*"#, options: .regularExpression) {
            let raw = String(line[match])
            let scopeText = raw
                .replacingOccurrences(of: "*", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespaces)
            scope = scopeText.isEmpty ? nil : scopeText
            line.removeSubrange(match)
        } else {
            scope = nil
        }

        if let match = line.range(
            of: #"\s*\(\[([0-9a-f]{6,40})\]\(([^)]+)\)\)\s*$"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            let raw = String(line[match])
            let hash = raw.range(of: #"\[([0-9a-f]+)\]"#, options: [.regularExpression, .caseInsensitive])
                .map { String(raw[$0]).trimmingCharacters(in: CharacterSet(charactersIn: "[]")) } ?? ""
            let urlString = raw.range(of: #"\(([^)]+)\)\s*$"#, options: .regularExpression)
                .map { String(raw[$0]).trimmingCharacters(in: CharacterSet(charactersIn: "() ")) } ?? ""
            commit = Commit(shortHash: String(hash.prefix(7)), url: URL(string: urlString))
            line.removeSubrange(match)
        } else if let match = line.range(
            of: #"\s*\(([0-9a-f]{6,40})\)\s*$"#,
            options: [.regularExpression, .caseInsensitive]
        ) {
            let hash = String(line[match])
                .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "()")))
            commit = Commit(shortHash: String(hash.prefix(7)), url: nil)
            line.removeSubrange(match)
        } else {
            commit = nil
        }

        message = line.trimmingCharacters(in: .whitespaces)
    }

    var attributedMessage: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: message, options: options))
            ?? AttributedString(message)
    }
}

#Preview("Populated") {
    NavigationStack {
        ChangelogView()
    }
}
