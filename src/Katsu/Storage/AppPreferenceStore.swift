import Foundation

protocol AppPreferenceStore: AnyObject {
    var tabLayout: [HomeTabLayoutItem] { get set }
    var useMockServer: Bool { get set }
    func cachedRecipeDetail(profileID: UUID, slug: String) -> MealieRecipeDetail?
    func cachedRecipeSummaries(profileID: UUID) -> [MealieRecipeSummary]
    func cacheRecipeDetail(_ detail: MealieRecipeDetail, profileID: UUID)
}

enum HomeTab: String, Codable, CaseIterable, Hashable, Identifiable {
    case recipes
    case shopping
    case settings
    case search
    case mealPlans

    var id: Self { self }

    var isRequired: Bool {
        self == .settings
    }

    static let defaultOrder: [HomeTab] = [.recipes, .shopping, .search, .mealPlans, .settings]
    static let defaultEnabled: Set<HomeTab> = [.recipes, .shopping, .settings]
}

struct HomeTabLayoutItem: Codable, Equatable, Identifiable {
    let tab: HomeTab
    var isEnabled: Bool

    var id: HomeTab { tab }

    static var defaultLayout: [HomeTabLayoutItem] {
        HomeTab.defaultOrder.map { tab in
            HomeTabLayoutItem(tab: tab, isEnabled: HomeTab.defaultEnabled.contains(tab))
        }
    }

    static func normalized(_ layout: [HomeTabLayoutItem]) -> [HomeTabLayoutItem] {
        var seenTabs = Set<HomeTab>()
        var normalized = [HomeTabLayoutItem]()

        for item in layout where !seenTabs.contains(item.tab) {
            seenTabs.insert(item.tab)
            normalized.append(HomeTabLayoutItem(tab: item.tab, isEnabled: item.isEnabled || item.tab.isRequired))
        }

        for item in defaultLayout where !seenTabs.contains(item.tab) {
            normalized.append(item)
        }

        return normalized
    }
}

final class UserDefaultsAppPreferenceStore: AppPreferenceStore {
    private let defaults: UserDefaults
    private let tabLayoutKey = "katsu.tabLayout"
    private let useMockKey = "katsu.useMockServer"
    private let recipeCachePrefix = "katsu.cachedRecipeDetail"
    private let recipeCacheIndexPrefix = "katsu.cachedRecipeDetailIndex"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var tabLayout: [HomeTabLayoutItem] {
        get {
            guard let data = defaults.data(forKey: tabLayoutKey),
                  let layout = try? decoder.decode([HomeTabLayoutItem].self, from: data) else {
                return HomeTabLayoutItem.defaultLayout
            }
            return HomeTabLayoutItem.normalized(layout)
        }
        set {
            guard let data = try? encoder.encode(HomeTabLayoutItem.normalized(newValue)) else { return }
            defaults.set(data, forKey: tabLayoutKey)
        }
    }

    var useMockServer: Bool {
        get { defaults.bool(forKey: useMockKey) }
        set { defaults.set(newValue, forKey: useMockKey) }
    }

    func cachedRecipeDetail(profileID: UUID, slug: String) -> MealieRecipeDetail? {
        guard let data = defaults.data(forKey: recipeCacheKey(profileID: profileID, slug: slug)) else { return nil }
        return try? decoder.decode(MealieRecipeDetail.self, from: data)
    }

    func cachedRecipeSummaries(profileID: UUID) -> [MealieRecipeSummary] {
        cachedSlugs(profileID: profileID).compactMap { slug in
            cachedRecipeDetail(profileID: profileID, slug: slug)?.summary
        }
    }

    func cacheRecipeDetail(_ detail: MealieRecipeDetail, profileID: UUID) {
        guard let data = try? encoder.encode(detail) else { return }
        defaults.set(data, forKey: recipeCacheKey(profileID: profileID, slug: detail.slug))
        var slugs = cachedSlugs(profileID: profileID).filter { $0 != detail.slug }
        slugs.insert(detail.slug, at: 0)
        defaults.set(Array(slugs.prefix(20)), forKey: recipeCacheIndexKey(profileID: profileID))
    }

    private func recipeCacheKey(profileID: UUID, slug: String) -> String {
        "\(recipeCachePrefix).\(profileID.uuidString).\(slug)"
    }

    private func recipeCacheIndexKey(profileID: UUID) -> String {
        "\(recipeCacheIndexPrefix).\(profileID.uuidString)"
    }

    private func cachedSlugs(profileID: UUID) -> [String] {
        defaults.stringArray(forKey: recipeCacheIndexKey(profileID: profileID)) ?? []
    }
}
