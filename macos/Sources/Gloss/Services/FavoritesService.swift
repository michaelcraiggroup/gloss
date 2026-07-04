import Foundation
import Observation

/// A favorited document inside the open vault, derived from
/// `.gloss/favorites.json` at load time. Title and type are computed from the
/// filename — nothing is denormalized on disk, so entries survive machine
/// moves and vault renames.
struct FavoriteItem: Identifiable, Equatable {
    let relativePath: String
    let url: URL
    let title: String
    let documentType: DocumentType
    var fileExists: Bool

    var id: String { relativePath }
}

/// Vault-owned favorites, persisted at `<vaultRoot>/.gloss/favorites.json` as
/// vault-relative paths so they travel with the folder (same precedent as
/// `.gloss/index.sqlite`). `.gloss` is hard-excluded from the watcher, tree,
/// and indexer, so saves never echo back into the event pipeline.
///
/// When no vault is open (or a URL is outside the vault), favorites fall back
/// to the SwiftData `""` bucket — see `RecentsStore.legacyToggleFavorite`.
@Observable @MainActor
final class FavoritesService {

    private(set) var rootURL: URL?
    /// Sorted by title (localizedStandardCompare).
    private(set) var favorites: [FavoriteItem] = []

    private var entries: [FavoritesFile.Entry] = []
    private var resolvedRootPath: String?

    // MARK: - Lifecycle

    /// Point the service at a vault root (loads the vault file) or `nil`
    /// (clears state on Close Folder). Never writes during load — a corrupt or
    /// half-synced file is only rewritten by the next explicit mutation.
    func configure(rootURL: URL?) {
        guard let rootURL else {
            self.rootURL = nil
            resolvedRootPath = nil
            entries = []
            favorites = []
            return
        }
        let standardized = rootURL.standardizedFileURL
        self.rootURL = standardized
        resolvedRootPath = standardized.resolvingSymlinksInPath().path
        entries = Self.load(from: Self.fileURL(for: standardized))
        rebuildItems()
    }

    // MARK: - Queries

    /// Whether this service owns favorite state for `url`: a vault is open and
    /// the URL resolves to a path inside it.
    func handles(_ url: URL) -> Bool {
        relativePath(for: url) != nil
    }

    func isFavorite(_ url: URL) -> Bool {
        guard let rel = relativePath(for: url) else { return false }
        return entries.contains { $0.relativePath == rel }
    }

    // MARK: - Mutations

    func toggle(_ url: URL) {
        guard let rel = relativePath(for: url) else { return }
        if let index = entries.firstIndex(where: { $0.relativePath == rel }) {
            entries.remove(at: index)
        } else {
            entries.append(.init(relativePath: rel, addedAt: .now))
        }
        save()
        rebuildItems()
    }

    /// Bulk entry point for the one-time claim migration of SwiftData
    /// favorites. Dedupes against existing entries; saves at most once.
    func importFavorites(urls: [URL]) {
        var added = false
        for url in urls {
            guard let rel = relativePath(for: url),
                  !entries.contains(where: { $0.relativePath == rel }) else { continue }
            entries.append(.init(relativePath: rel, addedAt: .now))
            added = true
        }
        guard added else { return }
        save()
        rebuildItems()
    }

    /// Follow a rename/move of a file OR folder (exact + prefix rewrite).
    func handleRename(oldURL: URL, newURL: URL) {
        guard let oldRel = relativePath(for: oldURL) else { return }
        guard let newRel = relativePath(for: newURL) else {
            // Moved out of the vault — treat as removal.
            handleDelete(url: oldURL)
            return
        }
        var changed = false
        entries = entries.map { entry in
            if entry.relativePath == oldRel {
                changed = true
                return .init(relativePath: newRel, addedAt: entry.addedAt)
            }
            if entry.relativePath.hasPrefix(oldRel + "/") {
                changed = true
                return .init(
                    relativePath: newRel + entry.relativePath.dropFirst(oldRel.count),
                    addedAt: entry.addedAt
                )
            }
            return entry
        }
        guard changed else { return }
        save()
        rebuildItems()
    }

    /// Remove entries for a deleted file OR folder (exact + prefix matches).
    func handleDelete(url: URL) {
        guard let rel = relativePath(for: url) else { return }
        let before = entries.count
        entries.removeAll {
            $0.relativePath == rel || $0.relativePath.hasPrefix(rel + "/")
        }
        guard entries.count != before else { return }
        save()
        rebuildItems()
    }

    /// Re-stat every favorite. Cheap (favorites are few); called from the
    /// vault watcher so "missing" dimming heals when sync delivers a file.
    func refreshExistence() {
        rebuildItems()
    }

    // MARK: - Paths

    /// Vault-relative path for `url`, trying the standardized root prefix
    /// first, then the symlink-resolved one (index-derived URLs arrive
    /// resolved). `nil` when no vault is open or the URL is outside it.
    private func relativePath(for url: URL) -> String? {
        guard let rootURL else { return nil }
        let path = url.standardizedFileURL.path
        let rootPath = rootURL.path
        if path.hasPrefix(rootPath + "/") {
            return String(path.dropFirst(rootPath.count + 1))
        }
        if let resolvedRootPath {
            let resolved = url.resolvingSymlinksInPath().path
            if resolved.hasPrefix(resolvedRootPath + "/") {
                return String(resolved.dropFirst(resolvedRootPath.count + 1))
            }
        }
        return nil
    }

    // MARK: - Persistence

    private struct FavoritesFile: Codable {
        struct Entry: Codable, Equatable {
            var relativePath: String
            var addedAt: Date
        }

        var version: Int
        var favorites: [Entry]
    }

    private static func fileURL(for root: URL) -> URL {
        root.appendingPathComponent(".gloss").appendingPathComponent("favorites.json")
    }

    private static func load(from url: URL) -> [FavoritesFile.Entry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Best-effort decode: unknown future fields are ignored by Codable,
        // and a corrupt file yields an empty list without being rewritten.
        return (try? decoder.decode(FavoritesFile.self, from: data))?.favorites ?? []
    }

    private func save() {
        guard let rootURL else { return }
        let url = Self.fileURL(for: rootURL)
        // A toggle can race ahead of the async index build that normally
        // creates `.gloss/`, so create it here too.
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(FavoritesFile(version: 1, favorites: entries)) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private func rebuildItems() {
        guard let rootURL else {
            favorites = []
            return
        }
        favorites = entries.map { entry in
            let url = rootURL.appendingPathComponent(entry.relativePath)
            return FavoriteItem(
                relativePath: entry.relativePath,
                url: url,
                title: RecentsStore.title(for: url),
                documentType: RecentsStore.documentType(for: url),
                fileExists: FileManager.default.fileExists(atPath: url.path)
            )
        }
        .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
}
