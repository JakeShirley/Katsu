import Foundation

final class URLSessionMealieAPIClient: MealieAPIClient, @unchecked Sendable {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    func fetchServerInfo(serverURL: URL) async throws -> MealieServerInfo {
        let request = URLRequest(url: serverURL.appendingPathComponent("api/app/about"))
        return try await perform(request)
    }

    func login(serverURL: URL, username: String, password: String) async throws -> MealieAuthToken {
        var request = URLRequest(url: serverURL.appendingPathComponent("api/auth/token"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let body = formEncode([
            "username": username,
            "password": password
        ])
        request.httpBody = body.data(using: .utf8)
        return try await perform(request)
    }

    func fetchCurrentUser(serverURL: URL, token: MealieAuthToken) async throws -> MealieUser {
        var request = URLRequest(url: serverURL.appendingPathComponent("api/users/self"))
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
    }

    // MARK: - Helpers

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            throw map(urlError: urlError)
        } catch {
            throw AppError.unknown(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AppError.invalidServerResponse
        }

        switch http.statusCode {
        case 200..<300:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw AppError.invalidServerResponse
            }
        case 401:
            throw AppError.unauthorized
        case 403:
            throw AppError.forbidden
        case 429:
            throw AppError.rateLimited
        default:
            throw AppError.server(status: http.statusCode)
        }
    }

    private func map(urlError: URLError) -> AppError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
             .cannotFindHost, .timedOut, .dnsLookupFailed:
            return .offline
        case .secureConnectionFailed, .serverCertificateUntrusted,
             .serverCertificateHasBadDate, .serverCertificateNotYetValid,
             .serverCertificateHasUnknownRoot, .clientCertificateRejected,
             .clientCertificateRequired:
            return .tlsTrust
        case .badURL, .unsupportedURL:
            return .invalidURL
        default:
            return .unknown(urlError.localizedDescription)
        }
    }

    private func formEncode(_ pairs: [String: String]) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=")
        return pairs
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
    }
}
