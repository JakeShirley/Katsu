import SwiftUI

struct ChangelogView: View {
    @State private var content: String = ""

    var body: some View {
        ScrollView {
            Text(content.isEmpty ? "No release notes yet." : content)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle("Changelog")
        .task {
            content = loadBundledChangelog()
        }
    }

    private func loadBundledChangelog() -> String {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return text
    }
}
