import Foundation

protocol AppPreferenceStore: AnyObject {
    var useMockServer: Bool { get set }
}

final class UserDefaultsAppPreferenceStore: AppPreferenceStore {
    private let defaults: UserDefaults
    private let useMockKey = "katsu.useMockServer"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var useMockServer: Bool {
        get { defaults.bool(forKey: useMockKey) }
        set { defaults.set(newValue, forKey: useMockKey) }
    }
}
