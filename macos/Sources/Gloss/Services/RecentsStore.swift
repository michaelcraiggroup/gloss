import Foundation
import SwiftData

/// Stateless helpers for the SwiftData-backed recents list (and the legacy
/// no-vault favorites bucket). Kept out of the views so ContentView/SidebarView
/// stay thin and every operation is unit-testable against an in-memory store.
///
/// Path discipline: every row is keyed on `canonicalPath` (standardized file
/// path) + `vaultPath` (see `RecentDocument`). Prefix checks test BOTH the
/// standardized and symlink-resolved forms of the root, because index-derived
/// URLs (wiki-links, backlinks, graph) arrive symlink-resolved while file-tree
/// URLs do not.
@MainActor
enum RecentsStore {

    // MARK: - Path canon

    /// THE key form for `RecentDocument.path`.
    static func canonicalPath(_ url: URL) -> String {
        url.standardizedFileURL.path
    }

    /// Canonical `RecentDocument.vaultPath` for a vault root; `""` when no vault.
    static func vaultKey(forRoot url: URL?) -> String {
        url.map { canonicalPath($0) } ?? ""
    }

    /// True when `path` lives under `root` in either its standardized or
    /// symlink-resolved form.
    static func isPath(_ path: String, underRoot root: URL) -> Bool {
        let standardized = canonicalPath(root)
        let resolved = root.resolvingSymlinksInPath().path
        let resolvedPath = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        return path.hasPrefix(standardized + "/")
            || path.hasPrefix(resolved + "/")
            || resolvedPath.hasPrefix(resolved + "/")
    }

    /// True for files under the app's temporary directory (guide sample docs
    /// etc.) which must never enter recents. Compares symlink-resolved prefixes:
    /// `temporaryDirectory` is `/var/folders/…` while resolved paths are
    /// `/private/var/folders/…`.
    static func isTemporary(_ url: URL) -> Bool {
        let resolved = url.resolvingSymlinksInPath().path
        let tmp = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().path
        return resolved == tmp || resolved.hasPrefix(tmp + "/")
    }

    // MARK: - Title / type derivation

    static func title(for url: URL) -> String {
        url.lastPathComponent
            .replacingOccurrences(of: ".md", with: "")
            .replacingOccurrences(of: ".markdown", with: "")
    }

    static func documentType(for url: URL) -> DocumentType {
        DocumentType.detect(
            filename: url.lastPathComponent,
            folderName: url.deletingLastPathComponent().lastPathComponent
        )
    }

    // MARK: - Recording

    /// Record an open of `url` in the `vaultKey` bucket: update-or-insert, and
    /// merge any duplicate (vaultPath, path) rows left behind by older builds
    /// (max lastOpened, OR isFavorite).
    static func record(url: URL, vaultKey: String, in context: ModelContext) {
        let path = canonicalPath(url)
        let rows = fetchRows(path: path, vaultKey: vaultKey, in: context)

        if let primary = rows.first {
            mergeExtras(rows, into: primary, in: context)
            primary.lastOpened = .now
            primary.documentType = documentType(for: url).rawValue
        } else {
            context.insert(RecentDocument(
                path: path,
                title: title(for: url),
                documentType: documentType(for: url).rawValue,
                vaultPath: vaultKey
            ))
        }
    }

    // MARK: - Legacy no-vault favorites bucket

    /// Toggle the favorite flag for `url` in the given bucket (SwiftData-backed;
    /// used for the no-vault `""` bucket once vault favorites live in
    /// `.gloss/favorites.json`).
    static func legacyToggleFavorite(url: URL, vaultKey: String, in context: ModelContext) {
        let path = canonicalPath(url)
        let rows = fetchRows(path: path, vaultKey: vaultKey, in: context)

        if let primary = rows.first {
            mergeExtras(rows, into: primary, in: context)
            primary.isFavorite.toggle()
        } else {
            context.insert(RecentDocument(
                path: path,
                title: title(for: url),
                documentType: documentType(for: url).rawValue,
                isFavorite: true,
                vaultPath: vaultKey
            ))
        }
    }

    static func legacyIsFavorite(url: URL, vaultKey: String, in context: ModelContext) -> Bool {
        let path = canonicalPath(url)
        let descriptor = FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.path == path && $0.vaultPath == vaultKey && $0.isFavorite }
        )
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    // MARK: - Vault-open lifecycle

    /// Claim pre-scoping rows (`vaultPath == ""`) whose file lives under `root`
    /// into the vault's bucket. Rows that collide with an existing
    /// (vaultKey, path) row are merged into it (max lastOpened, OR isFavorite)
    /// and deleted. Idempotent: claimed rows leave the `""` bucket.
    static func claimLegacyRows(root: URL, vaultKey: String, in context: ModelContext) {
        let legacyKey = ""
        let descriptor = FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.vaultPath == legacyKey }
        )
        guard let legacyRows = try? context.fetch(descriptor) else { return }

        for row in legacyRows where isPath(row.path, underRoot: root) {
            let existing = fetchRows(path: row.path, vaultKey: vaultKey, in: context)
            if let primary = existing.first {
                primary.lastOpened = max(primary.lastOpened, row.lastOpened)
                primary.isFavorite = primary.isFavorite || row.isFavorite
                context.delete(row)
            } else {
                row.vaultPath = vaultKey
            }
        }
    }

    /// Move favorite flags out of a vault bucket, returning the flagged file
    /// URLs so the caller can import them into the vault's favorites store.
    /// Rows stay behind as plain recents. Idempotent (flags are cleared).
    static func claimFavoriteFlags(vaultKey: String, in context: ModelContext) -> [URL] {
        let descriptor = FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.vaultPath == vaultKey && $0.isFavorite }
        )
        guard let rows = try? context.fetch(descriptor) else { return [] }
        for row in rows { row.isFavorite = false }
        return rows.map(\.url)
    }

    /// Drop non-favorite rows in the bucket whose file no longer exists.
    static func prune(vaultKey: String, in context: ModelContext) {
        let descriptor = FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.vaultPath == vaultKey && !$0.isFavorite }
        )
        guard let rows = try? context.fetch(descriptor) else { return }
        for row in rows where !FileManager.default.fileExists(atPath: row.path) {
            context.delete(row)
        }
    }

    /// The "Clear" action: drop every non-favorite row in the bucket.
    /// Favorites (only present in the `""` bucket once vault favorites live in
    /// the vault file) survive.
    static func clearRecents(vaultKey: String, in context: ModelContext) {
        let descriptor = FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.vaultPath == vaultKey && !$0.isFavorite }
        )
        guard let rows = try? context.fetch(descriptor) else { return }
        for row in rows { context.delete(row) }
    }

    // MARK: - Follow the file

    /// Rewrite rows after a rename/move of a file OR folder: exact match plus
    /// any rows under the old path prefix. Titles and document types are
    /// recomputed from the new location.
    static func handleRename(oldURL: URL, newURL: URL, vaultKey: String, in context: ModelContext) {
        let old = canonicalPath(oldURL)
        let new = canonicalPath(newURL)
        for row in fetchBucket(vaultKey, in: context) {
            let rewritten: String
            if row.path == old {
                rewritten = new
            } else if row.path.hasPrefix(old + "/") {
                rewritten = new + row.path.dropFirst(old.count)
            } else {
                continue
            }
            row.path = rewritten
            let url = URL(fileURLWithPath: rewritten)
            row.title = title(for: url)
            row.documentType = documentType(for: url).rawValue
        }
    }

    /// Remove rows for a deleted file OR folder (exact + prefix matches).
    static func handleDelete(url: URL, vaultKey: String, in context: ModelContext) {
        let old = canonicalPath(url)
        for row in fetchBucket(vaultKey, in: context)
        where row.path == old || row.path.hasPrefix(old + "/") {
            context.delete(row)
        }
    }

    // MARK: - Private

    private static func fetchRows(path: String, vaultKey: String, in context: ModelContext) -> [RecentDocument] {
        let descriptor = FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.path == path && $0.vaultPath == vaultKey }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private static func fetchBucket(_ vaultKey: String, in context: ModelContext) -> [RecentDocument] {
        let descriptor = FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.vaultPath == vaultKey }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Fold duplicate rows into `primary` and delete them.
    private static func mergeExtras(_ rows: [RecentDocument], into primary: RecentDocument, in context: ModelContext) {
        for extra in rows.dropFirst() {
            primary.lastOpened = max(primary.lastOpened, extra.lastOpened)
            primary.isFavorite = primary.isFavorite || extra.isFavorite
            context.delete(extra)
        }
    }
}
