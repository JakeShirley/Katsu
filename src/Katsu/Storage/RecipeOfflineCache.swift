import Foundation

struct RecipeOfflineCacheSnapshot: Equatable {
    let recipeCount: Int
    let byteCount: Int64
    let lastUpdated: Date?

    static let empty = RecipeOfflineCacheSnapshot(recipeCount: 0, byteCount: 0, lastUpdated: nil)
}

protocol RecipeOfflineCache: AnyObject, Sendable {
    func cachedRecipeDetail(profileID: UUID, slug: String) -> MealieRecipeDetail?
    func cachedRecipeSummaries(profileID: UUID) -> [MealieRecipeSummary]
    func cacheRecipeDetail(_ detail: MealieRecipeDetail, rawData: Data, profileID: UUID)
    func localImageURL(profileID: UUID, recipeID: String, slug: String, fileName: String) -> URL?
    func cacheMedia(_ data: Data, profileID: UUID, recipeID: String, slug: String, fileName: String, kind: RecipeOfflineMediaKind)
    func snapshot(profileID: UUID) -> RecipeOfflineCacheSnapshot
    func cachedFavoriteRecipeIDs(profileID: UUID) -> Set<String>
    func cacheFavoriteRecipeIDs(_ recipeIDs: Set<String>, profileID: UUID)
    func clear(profileID: UUID)
}

enum RecipeOfflineMediaKind: String, Codable, Sendable {
    case image = "images"
    case asset = "assets"
}

final class FileRecipeOfflineCache: RecipeOfflineCache, @unchecked Sendable {
    private let fileManager: FileManager
    private let rootURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let baseURL = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        self.rootURL = (baseURL ?? fileManager.temporaryDirectory).appendingPathComponent("OfflineRecipes", isDirectory: true)
        encoder.outputFormatting = [.sortedKeys]
    }

    func cachedRecipeDetail(profileID: UUID, slug: String) -> MealieRecipeDetail? {
        guard let data = try? Data(contentsOf: recipeDirectory(profileID: profileID, slug: slug).appendingPathComponent("detail.json")) else {
            return cachedRecipeSummaries(profileID: profileID)
                .first { $0.slug == slug || $0.id == slug }
                .flatMap { summary in cachedRecipeDetail(profileID: profileID, slug: summary.slug) }
        }
        return try? decoder.decode(MealieRecipeDetail.self, from: data)
    }

    func cachedRecipeSummaries(profileID: UUID) -> [MealieRecipeSummary] {
        cachedRecipeRecords(profileID: profileID).map(\.detail.summary)
    }

    func cacheRecipeDetail(_ detail: MealieRecipeDetail, rawData: Data, profileID: UUID) {
        let directory = recipeDirectory(profileID: profileID, slug: detail.slug)
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try rawData.write(to: directory.appendingPathComponent("detail.json"), options: .atomic)
            let manifest = RecipeOfflineManifest(
                recipeID: detail.recipeID,
                slug: detail.slug,
                displayName: detail.displayName,
                updatedAt: Date()
            )
            let manifestData = try encoder.encode(manifest)
            try manifestData.write(to: directory.appendingPathComponent("manifest.json"), options: .atomic)
        } catch {
            return
        }
    }

    func localImageURL(profileID: UUID, recipeID: String, slug: String, fileName: String) -> URL? {
        let url = mediaURL(profileID: profileID, slug: slug, fileName: fileName, kind: .image)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func cacheMedia(_ data: Data, profileID: UUID, recipeID: String, slug: String, fileName: String, kind: RecipeOfflineMediaKind) {
        let url = mediaURL(profileID: profileID, slug: slug, fileName: fileName, kind: kind)
        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            return
        }
    }

    func snapshot(profileID: UUID) -> RecipeOfflineCacheSnapshot {
        let profileURL = profileDirectory(profileID: profileID)
        guard fileManager.fileExists(atPath: profileURL.path) else { return .empty }
        let records = cachedRecipeRecords(profileID: profileID)
        return RecipeOfflineCacheSnapshot(
            recipeCount: records.count,
            byteCount: byteCount(at: profileURL),
            lastUpdated: records.compactMap(\.manifest.updatedAt).max()
        )
    }

    func cachedFavoriteRecipeIDs(profileID: UUID) -> Set<String> {
        guard let data = try? Data(contentsOf: favoritesURL(profileID: profileID)),
              let recipeIDs = try? decoder.decode([String].self, from: data) else { return [] }
        return Set(recipeIDs)
    }

    func cacheFavoriteRecipeIDs(_ recipeIDs: Set<String>, profileID: UUID) {
        let url = favoritesURL(profileID: profileID)
        do {
            try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(recipeIDs.sorted()).write(to: url, options: .atomic)
        } catch {
            return
        }
    }

    func clear(profileID: UUID) {
        try? fileManager.removeItem(at: profileDirectory(profileID: profileID))
    }

    private func cachedRecipeRecords(profileID: UUID) -> [RecipeOfflineRecord] {
        let profileURL = profileDirectory(profileID: profileID)
        guard let directories = try? fileManager.contentsOfDirectory(
            at: profileURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return directories.compactMap { directory -> RecipeOfflineRecord? in
            guard let values = try? directory.resourceValues(forKeys: [.isDirectoryKey]), values.isDirectory == true else { return nil }
            guard let detailData = try? Data(contentsOf: directory.appendingPathComponent("detail.json")),
                  let detail = try? decoder.decode(MealieRecipeDetail.self, from: detailData) else { return nil }
            let manifestData = try? Data(contentsOf: directory.appendingPathComponent("manifest.json"))
            let manifest = manifestData.flatMap { try? decoder.decode(RecipeOfflineManifest.self, from: $0) }
                ?? RecipeOfflineManifest(recipeID: detail.recipeID, slug: detail.slug, displayName: detail.displayName, updatedAt: nil)
            return RecipeOfflineRecord(detail: detail, manifest: manifest)
        }
        .sorted { lhs, rhs in
            switch (lhs.manifest.updatedAt, rhs.manifest.updatedAt) {
            case let (left?, right?): left > right
            case (_?, nil): true
            case (nil, _?): false
            case (nil, nil): lhs.detail.displayName < rhs.detail.displayName
            }
        }
    }

    private func byteCount(at url: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }

    private func profileDirectory(profileID: UUID) -> URL {
        rootURL.appendingPathComponent(profileID.uuidString, isDirectory: true)
    }

    // Stored beside the per-recipe directories; `cachedRecipeRecords` only
    // reads directories, so this file never looks like a recipe.
    private func favoritesURL(profileID: UUID) -> URL {
        profileDirectory(profileID: profileID).appendingPathComponent("favorites.json")
    }

    private func recipeDirectory(profileID: UUID, slug: String) -> URL {
        profileDirectory(profileID: profileID).appendingPathComponent(safePathComponent(slug), isDirectory: true)
    }

    private func mediaURL(profileID: UUID, slug: String, fileName: String, kind: RecipeOfflineMediaKind) -> URL {
        recipeDirectory(profileID: profileID, slug: slug)
            .appendingPathComponent(kind.rawValue, isDirectory: true)
            .appendingPathComponent(safePathComponent(fileName))
    }

    private func safePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return value.unicodeScalars.map { allowed.contains($0) ? String($0) : "-" }.joined()
    }
}

private struct RecipeOfflineRecord {
    let detail: MealieRecipeDetail
    let manifest: RecipeOfflineManifest
}

private struct RecipeOfflineManifest: Codable {
    let recipeID: String?
    let slug: String
    let displayName: String
    let updatedAt: Date?
}
