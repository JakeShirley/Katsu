import Foundation

/// Unified user-facing error type. Every networking failure should be mapped
/// into one of these so error UI can stay consistent across features.
enum AppError: LocalizedError, Equatable {
    case offline
    case unauthorized
    case forbidden
    case tlsTrust
    case rateLimited
    case server(status: Int)
    case invalidServerResponse
    case invalidURL
    case missingPassword
    case missingAPIToken
    case invalidAPIToken
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .offline:
            return String(localized: "The Mealie server appears to be offline or unreachable.")
        case .unauthorized:
            return String(localized: "Your session has expired. Sign in again to continue.")
        case .forbidden:
            return String(localized: "Your account doesn't have permission for this action.")
        case .tlsTrust:
            return String(localized: "The server's secure connection could not be trusted.")
        case .rateLimited:
            return String(localized: "The server is receiving too many requests. Try again in a moment.")
        case .server(let status):
            return String(localized: "The server returned HTTP \(status).")
        case .invalidServerResponse:
            return String(localized: "The server returned an unexpected response.")
        case .invalidURL:
            return String(localized: "Enter a valid Mealie server URL.")
        case .missingPassword:
            return String(localized: "Password is required.")
        case .missingAPIToken:
            return String(localized: "API token is required.")
        case .invalidAPIToken:
            return String(localized: "Mealie didn't accept this API token. Check that the whole token was copied and that it hasn't been deleted.")
        case .unknown(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .offline:
            return String(localized: "Confirm the Mealie server is running and reachable from this device.")
        case .unauthorized:
            return String(localized: "Sign in again with your Mealie credentials.")
        case .invalidURL:
            return String(localized: "Include the scheme and host, for example https://mealie.example.com.")
        default:
            return nil
        }
    }
}
