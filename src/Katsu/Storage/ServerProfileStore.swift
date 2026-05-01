import Foundation

protocol ServerProfileStore: AnyObject {
    func allProfiles() -> [ServerProfile]
    func activeProfile() -> ServerProfile?
    func activeProfileID() -> UUID?
    func setActiveProfileID(_ id: UUID?)
    func upsert(_ profile: ServerProfile)
    func remove(id: UUID)
}

final class UserDefaultsServerProfileStore: ServerProfileStore {
    private let defaults: UserDefaults
    private let profilesKey = "katsu.serverProfiles"
    private let activeIDKey = "katsu.activeServerProfileID"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func allProfiles() -> [ServerProfile] {
        guard let data = defaults.data(forKey: profilesKey),
              let profiles = try? decoder.decode([ServerProfile].self, from: data) else {
            return []
        }
        return profiles
    }

    func activeProfile() -> ServerProfile? {
        guard let id = activeProfileID() else {
            return nil
        }
        return allProfiles().first(where: { $0.id == id })
    }

    func activeProfileID() -> UUID? {
        guard let raw = defaults.string(forKey: activeIDKey) else {
            return nil
        }
        return UUID(uuidString: raw)
    }

    func setActiveProfileID(_ id: UUID?) {
        if let id {
            defaults.set(id.uuidString, forKey: activeIDKey)
        } else {
            defaults.removeObject(forKey: activeIDKey)
        }
    }

    func upsert(_ profile: ServerProfile) {
        var profiles = allProfiles()
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        save(profiles)
    }

    func remove(id: UUID) {
        var profiles = allProfiles()
        profiles.removeAll { $0.id == id }
        save(profiles)
        if activeProfile()?.id == id || activeProfile() == nil {
            setActiveProfileID(profiles.first?.id)
        }
    }

    private func save(_ profiles: [ServerProfile]) {
        if let data = try? encoder.encode(profiles) {
            defaults.set(data, forKey: profilesKey)
        }
    }
}
