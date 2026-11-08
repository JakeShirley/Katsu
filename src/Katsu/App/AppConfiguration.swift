import Foundation

/// Parsed configuration sourced from process launch arguments and environment
/// variables. See `docs/DEVELOPMENT.md` for the full list of supported flags.
struct AppConfiguration: Equatable {
    var initialServerURL: URL?
    var useMockServer: Bool
    var debugAuthToken: String?
    var debugMockServerVersion: String?
    var openSettingsOnLaunch: Bool
    var openChangelogOnLaunch: Bool

    static let empty = AppConfiguration(
        initialServerURL: nil,
        useMockServer: false,
        debugAuthToken: nil,
        debugMockServerVersion: nil,
        openSettingsOnLaunch: false,
        openChangelogOnLaunch: false
    )

    static func fromProcess(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppConfiguration {
        var config = AppConfiguration.empty

        func argValue(_ flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag),
                  index + 1 < arguments.count else { return nil }
            let value = arguments[index + 1]
            return value.hasPrefix("-") ? nil : value
        }

        if let raw = argValue("-serverURL") ?? environment["KATSU_SERVER_URL"],
           let url = URL(string: raw), url.scheme != nil {
            config.initialServerURL = url
        }

        if arguments.contains("-debugUseMockServer") || environment["KATSU_USE_MOCK_SERVER"] == "1" {
            config.useMockServer = true
        }

        if let token = argValue("-debugAuthToken") ?? environment["KATSU_DEBUG_AUTH_TOKEN"],
           !token.isEmpty {
            config.debugAuthToken = token
        }

        if let version = argValue("-debugMockServerVersion") ?? environment["KATSU_MOCK_SERVER_VERSION"],
           !version.isEmpty {
            config.debugMockServerVersion = version
        }

        if arguments.contains("-debugShowSettings") {
            config.openSettingsOnLaunch = true
        }
        if arguments.contains("-debugShowChangelog") {
            config.openChangelogOnLaunch = true
        }

        return config
    }
}
