import Foundation

protocol AppPreferenceStore: AnyObject {
    var useMockServer: Bool { get set }
    func cachedRecipeDetail(profileID: UUID, slug: String) -> MealieRecipeDetail?
    func cachedRecipeSummaries(profileID: UUID) -> [MealieRecipeSummary]
    func cacheRecipeDetail(_ detail: MealieRecipeDetail, profileID: UUID)
}

final class UserDefaultsAppPreferenceStore: AppPreferenceStore {
    private let defaults: UserDefaults
    private let useMockKey = "katsu.useMockServer"
    private let recipeCachePrefix = "katsu.cachedRecipeDetail"
    private let recipeCacheIndexPrefix = "katsu.cachedRecipeDetailIndex"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
