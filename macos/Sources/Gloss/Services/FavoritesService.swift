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
/// `.gloss/index.sqlite`). `.gloss` is hard-excluded from the file pipeline
/// (tree, indexer); the watchers make exactly one exception — favorites.json
/// changes post `.glossFavoritesFileChanged` so sync deliveries from another
/// device reload here (`reloadFromDisk` never writes, so echoes can't loop).
///
/// **Container vaults are two-writer**: favorites.json syncs, and another
/// device may write between our read and our write. Mutations there run as a
/// coordinated read-transform-write (`NSFileCoordinator`, `.forMerging`):
/// the user's *intent* (favorite X / unfavorite X / rename / delete) is
/// applied to the FRESH on-disk state inside one coordination block — remote
/// additions survive, local removals stick. iCloud conflict versions are
/// resolved by union (favorites resurrect rather than vanish).
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
        // Intent comes from what the user SAW (in-memory state), then applies
        // to fresh disk state — if another device favorited the same file in
        // the meantime, the user's tap still means what the screen showed.
        let favored = !entries.contains { $0.relativePath == rel }
        mutate { entries in
            Self.applySetFavorite(rel, favored: favored, addedAt: .now, in: &entries)
        }
    }

    /// Bulk entry point for the one-time claim migration of SwiftData
    /// favorites. Dedupes against existing entries; saves at most once.
    func importFavorites(urls: [URL]) {
        let rels = urls.compactMap { relativePath(for: $0) }
        guard !rels.isEmpty else { return }
        mutate { entries in
            Self.applyImport(rels, addedAt: .now, in: &entries)
        }
    }

    /// Follow a rename/move of a file OR folder (exact + prefix rewrite).
    func handleRename(oldURL: URL, newURL: URL) {
        guard let oldRel = relativePath(for: oldURL) else { return }
        guard let newRel = relativePath(for: newURL) else {
            // Moved out of the vault — treat as removal.
            handleDelete(url: oldURL)
            return
        }
        mutate { entries in
            Self.applyRename(oldRel: oldRel, newRel: newRel, in: &entries)
        }
    }

    /// Remove entries for a deleted file OR folder (exact + prefix matches).
    func handleDelete(url: URL) {
        guard let rel = relativePath(for: url) else { return }
        mutate { entries in
            Self.applyDelete(rel, in: &entries)
        }
    }

    /// Re-stat every favorite. Cheap (favorites are few); called from the
    /// vault watcher so "missing" dimming heals when sync delivers a file.
    func refreshExistence() {
        rebuildItems()
    }

    /// Sync delivered another device's favorites.json (the watchers'
    /// `.glossFavoritesFileChanged` passthrough) — adopt it. Reload writes
    /// nothing (conflict resolution aside), so watcher echoes can't loop.
    func reloadFromDisk() {
        guard let rootURL else { return }
        let url = Self.fileURL(for: rootURL)
        if UbiquityVaultStore.isUbiquitousPath(rootURL) {
            resolveConflictVersions(at: url)
        }
        entries = Self.load(from: url)
        rebuildItems()
    }

    // MARK: - Pure mutation transforms (two-writer tested)

    nonisolated static func applySetFavorite(
        _ rel: String, favored: Bool, addedAt: Date,
        in entries: inout [FavoritesFile.Entry]
    ) -> Bool {
        if favored {
            guard !entries.contains(where: { $0.relativePath == rel }) else { return false }
            entries.append(.init(relativePath: rel, addedAt: addedAt))
            return true
        }
        let before = entries.count
        entries.removeAll { $0.relativePath == rel }
        return entries.count != before
    }

    nonisolated static func applyImport(
        _ rels: [String], addedAt: Date,
        in entries: inout [FavoritesFile.Entry]
    ) -> Bool {
        var added = false
        for rel in rels where !entries.contains(where: { $0.relativePath == rel }) {
            entries.append(.init(relativePath: rel, addedAt: addedAt))
            added = true
        }
        return added
    }

    nonisolated static func applyRename(
        oldRel: String, newRel: String,
        in entries: inout [FavoritesFile.Entry]
    ) -> Bool {
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
        return changed
    }

    nonisolated static func applyDelete(
        _ rel: String,
        in entries: inout [FavoritesFile.Entry]
    ) -> Bool {
        let before = entries.count
        entries.removeAll {
            $0.relativePath == rel || $0.relativePath.hasPrefix(rel + "/")
        }
        return entries.count != before
    }

    /// Conflict-version union: with two whole states and no operations, union
    /// is the safe lossy choice — a favorite resurrects rather than vanishes.
    /// Earliest addedAt wins per path; result sorted for stable output.
    nonisolated static func union(_ lists: [[FavoritesFile.Entry]]) -> [FavoritesFile.Entry] {
        var byPath: [String: FavoritesFile.Entry] = [:]
        for list in lists {
            for entry in list {
                if let existing = byPath[entry.relativePath] {
                    if entry.addedAt < existing.addedAt { byPath[entry.relativePath] = entry }
                } else {
                    byPath[entry.relativePath] = entry
                }
            }
        }
        return byPath.values.sorted { $0.relativePath < $1.relativePath }
    }

    /// The one favorites-file test the watchers use for the passthrough.
    nonisolated static func pathsIncludeFavoritesFile(_ paths: [String]) -> Bool {
        paths.contains { $0.hasSuffix("/.gloss/favorites.json") }
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

    struct FavoritesFile: Codable {
        struct Entry: Codable, Equatable {
            var relativePath: String
            var addedAt: Date
        }

        var version: Int
        var favorites: [Entry]
    }

    /// Every mutation funnels through here. Local vaults keep the original
    /// transform-memory-then-write behavior. Container vaults run the
    /// transform against FRESH disk state inside one `NSFileCoordinator`
    /// block — read, apply intent, write — so a write from another device
    /// between our last load and this tap is preserved, and whatever state
    /// sync delivered is adopted locally even when the transform no-ops.
    private func mutate(_ transform: (inout [FavoritesFile.Entry]) -> Bool) {
        guard let rootURL else { return }
        let fileURL = Self.fileURL(for: rootURL)

        if UbiquityVaultStore.isUbiquitousPath(rootURL) {
            resolveConflictVersions(at: fileURL)
            let coordinator = NSFileCoordinator(filePresenter: nil)
            var coordinationError: NSError?
            coordinator.coordinate(
                writingItemAt: fileURL, options: .forMerging, error: &coordinationError
            ) { destination in
                var disk = Self.load(from: destination)
                let changed = transform(&disk)
                entries = disk
                if changed {
                    Self.write(entries: disk, to: destination)
                }
            }
            if coordinationError != nil {
                // Coordination refused (rare) — fall back to the local path so
                // the user's action is never silently dropped.
                guard transform(&entries) else { return }
                Self.write(entries: entries, to: fileURL)
            }
        } else {
            guard transform(&entries) else { return }
            Self.write(entries: entries, to: fileURL)
        }
        rebuildItems()
    }

    /// Union all unresolved iCloud conflict versions into the current file,
    /// then mark them resolved. Terminates: the resolved write produces no
    /// new conflicts, and reloads without conflicts write nothing.
    private func resolveConflictVersions(at url: URL) {
        guard let conflicts = NSFileVersion.unresolvedConflictVersionsOfItem(at: url),
              !conflicts.isEmpty else { return }
        var lists = [Self.load(from: url)]
        for version in conflicts {
            lists.append(Self.load(from: version.url))
        }
        let merged = Self.union(lists)
        Self.write(entries: merged, to: url)
        for version in conflicts { version.isResolved = true }
        try? NSFileVersion.removeOtherVersionsOfItem(at: url)
        entries = merged
    }

    private static func fileURL(for root: URL) -> URL {
        root.appendingPathComponent(".gloss").appendingPathComponent("favorites.json")
    }

    nonisolated static func load(from url: URL) -> [FavoritesFile.Entry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        // Best-effort decode: unknown future fields are ignored by Codable,
        // and a corrupt file yields an empty list without being rewritten.
        return (try? decoder.decode(FavoritesFile.self, from: data))?.favorites ?? []
    }

    nonisolated private static func write(entries: [FavoritesFile.Entry], to url: URL) {
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
