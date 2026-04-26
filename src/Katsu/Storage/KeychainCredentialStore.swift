import Foundation
import Security

protocol CredentialStore: AnyObject {
    func saveToken(_ token: MealieAuthToken, for profileID: UUID) throws
    func loadToken(for profileID: UUID) throws -> MealieAuthToken?
    func deleteToken(for profileID: UUID) throws
}

/// Keychain-backed token storage. Tokens are scoped per server profile so
/// switching servers doesn't leak credentials between accounts.
final class KeychainCredentialStore: CredentialStore {
    private let service: String

    init(service: String = "org.odinseye.katsu.tokens") {
        self.service = service
    }

    func saveToken(_ token: MealieAuthToken, for profileID: UUID) throws {
        let data = try JSONEncoder().encode(token)
        let account = profileID.uuidString

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw AppError.unknown("Keychain add failed (\(addStatus))")
            }
        } else if updateStatus != errSecSuccess {
            throw AppError.unknown("Keychain update failed (\(updateStatus))")
        }
    }

    func loadToken(for profileID: UUID) throws -> MealieAuthToken? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileID.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return try? JSONDecoder().decode(MealieAuthToken.self, from: data)
        case errSecItemNotFound:
            return nil
        default:
            throw AppError.unknown("Keychain read failed (\(status))")
        }
    }

    func deleteToken(for profileID: UUID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: profileID.uuidString
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw AppError.unknown("Keychain delete failed (\(status))")
        }
    }
}
