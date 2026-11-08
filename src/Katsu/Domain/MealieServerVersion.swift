import Foundation

/// Semantic version reported by `GET /api/app/about`. Mealie releases report
/// strings like `v3.30.0`; `nightly`/`develop` builds report non-semver
/// strings, which Katsu treats as the newest release so features are never
/// gated on a development server.
struct MealieServerVersion: Comparable, Hashable, CustomStringConvertible {
    let major: Int
    let minor: Int
    let patch: Int

    init(major: Int, minor: Int = 0, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Parses `v3.30.0`, `3.30`, `v2.5.0-mock`, or `3.30.0+build`. Returns
    /// `nil` for non-semver strings such as `nightly` or `develop`.
    init?(_ rawValue: String) {
        var trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.first == "v" || trimmed.first == "V" {
            trimmed.removeFirst()
        }
        let core = trimmed.prefix { $0.isNumber || $0 == "." }
        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...3).contains(parts.count),
              let major = Int(parts[0]) else {
            return nil
        }
        let minor = parts.count > 1 ? Int(parts[1]) : 0
        let patch = parts.count > 2 ? Int(parts[2]) : 0
        guard let minor, let patch else { return nil }
        self.init(major: major, minor: minor, patch: patch)
    }

    var description: String {
        "v\(major).\(minor).\(patch)"
    }

    static func < (lhs: MealieServerVersion, rhs: MealieServerVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

/// Katsu capabilities that depend on a minimum Mealie server release. Check
/// support through `AppEnvironment.supports(_:)` before showing UI that calls
/// the gated endpoints.
enum MealieFeature: CaseIterable {
    /// Meal plans and shopping lists under `/api/households/...`.
    case households
    /// `snack`, `drink`, and `dessert` meal plan entry types.
    case extendedMealPlanEntryTypes
    /// `includeCategories` when importing a recipe from a URL.
    case importRecipeCategories

    var minimumVersion: MealieServerVersion {
        switch self {
        case .households:
            MealieServerVersion(major: 2)
        case .extendedMealPlanEntryTypes:
            MealieServerVersion(major: 3, minor: 7)
        case .importRecipeCategories:
            MealieServerVersion(major: 3, minor: 10)
        }
    }

    var localizedName: String {
        switch self {
        case .households:
            String(localized: "Meal plans and shopping lists")
        case .extendedMealPlanEntryTypes:
            String(localized: "Snack, drink, and dessert meal types")
        case .importRecipeCategories:
            String(localized: "Importing recipe categories")
        }
    }

    /// Returns `true` when `rawVersion` is missing or unparseable so that
    /// unknown and development servers aren't locked out.
    func isSupported(byServerVersion rawVersion: String?) -> Bool {
        guard let rawVersion, let version = MealieServerVersion(rawVersion) else {
            return true
        }
        return version >= minimumVersion
    }

    /// Oldest Mealie release that supports every feature Katsu uses.
    static var recommendedMinimumVersion: MealieServerVersion {
        allCases.map(\.minimumVersion).max() ?? MealieServerVersion(major: 2)
    }
}
