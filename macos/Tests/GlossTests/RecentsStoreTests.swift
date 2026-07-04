import Testing
import Foundation
import SwiftData
@testable import Gloss

@Suite("RecentsStore")
@MainActor
struct RecentsStoreTests {

    /// NOTE: callers must keep the container alive for the test's duration —
    /// `ModelContext` does not retain it, and a deallocated container traps.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: RecentDocument.self, configurations: config)
    }

    private func allRows(_ context: ModelContext) throws -> [RecentDocument] {
        try context.fetch(FetchDescriptor<RecentDocument>())
    }

    /// On-disk directory for tests that need real files (prune/rename).
    private func makeDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-recents-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    @discardableResult
    private func touch(_ dir: URL, _ relative: String) throws -> URL {
        let url = dir.appendingPathComponent(relative)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data("# test\n".utf8).write(to: url)
        return url
    }

    // MARK: - Path canon

    @Test("vaultKey is empty without a root and standardizes with one")
    func vaultKeyForms() {
        #expect(RecentsStore.vaultKey(forRoot: nil) == "")
        let dotted = URL(fileURLWithPath: "/Users/x/vaults/../vaults/notes")
        #expect(RecentsStore.vaultKey(forRoot: dotted) == "/Users/x/vaults/notes")
    }

    @Test("isTemporary detects the resolved temp directory")
    func isTemporaryDetectsResolvedTempDir() {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("guide.md")
        #expect(RecentsStore.isTemporary(tmpFile))
        // Resolved form (/private/var/…) must also be caught.
        #expect(RecentsStore.isTemporary(tmpFile.resolvingSymlinksInPath()))
        #expect(!RecentsStore.isTemporary(URL(fileURLWithPath: "/Users/x/notes/a.md")))
    }

    // MARK: - Recording

    @Test("record inserts with the vault key")
    func recordInsertsWithVaultKey() throws {
        let container = try makeContainer()
        let context = container.mainContext
        RecentsStore.record(url: URL(fileURLWithPath: "/vault/a.md"), vaultKey: "/vault", in: context)

        let rows = try allRows(context)
        #expect(rows.count == 1)
        #expect(rows.first?.vaultPath == "/vault")
        #expect(rows.first?.path == "/vault/a.md")
        #expect(rows.first?.title == "a")
    }

    @Test("record updates lastOpened instead of duplicating")
    func recordUpdatesLastOpenedNotDuplicates() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let url = URL(fileURLWithPath: "/vault/a.md")
        RecentsStore.record(url: url, vaultKey: "/vault", in: context)
        let firstOpened = try #require(try allRows(context).first).lastOpened

        RecentsStore.record(url: url, vaultKey: "/vault", in: context)
        let rows = try allRows(context)
        #expect(rows.count == 1)
        #expect(rows.first!.lastOpened >= firstOpened)
    }

    @Test("record merges pre-existing duplicate rows")
    func recordMergesPreexistingDuplicateRows() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let old = Date(timeIntervalSinceNow: -1000)
        context.insert(RecentDocument(path: "/vault/a.md", title: "a", lastOpened: old, vaultPath: "/vault"))
        context.insert(RecentDocument(path: "/vault/a.md", title: "a", lastOpened: old, isFavorite: true, vaultPath: "/vault"))
        try context.save()

        RecentsStore.record(url: URL(fileURLWithPath: "/vault/a.md"), vaultKey: "/vault", in: context)
        let rows = try allRows(context)
        #expect(rows.count == 1)
        #expect(rows.first?.isFavorite == true)   // OR-merged from the duplicate
    }

    @Test("record standardizes the path")
    func recordUsesStandardizedPath() throws {
        let container = try makeContainer()
        let context = container.mainContext
        RecentsStore.record(url: URL(fileURLWithPath: "/vault/x/../a.md"), vaultKey: "/vault", in: context)
        RecentsStore.record(url: URL(fileURLWithPath: "/vault/a.md"), vaultKey: "/vault", in: context)

        let rows = try allRows(context)
        #expect(rows.count == 1)
        #expect(rows.first?.path == "/vault/a.md")
    }

    @Test("same path in two vault buckets stays independent")
    func samePathTwoBucketsIndependent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let url = URL(fileURLWithPath: "/outer/inner/a.md")
        RecentsStore.record(url: url, vaultKey: "/outer", in: context)
        RecentsStore.record(url: url, vaultKey: "/outer/inner", in: context)
        #expect(try allRows(context).count == 2)
    }

    // MARK: - Claim migration

    @Test("claim sets vaultPath on plain legacy recents under the root")
    func claimSetsVaultPathOnPlainRecents() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(RecentDocument(path: "/vault/a.md", title: "a"))
        context.insert(RecentDocument(path: "/vault/sub/b.md", title: "b"))
        try context.save()

        RecentsStore.claimLegacyRows(root: URL(fileURLWithPath: "/vault"), vaultKey: "/vault", in: context)
        let rows = try allRows(context)
        #expect(rows.allSatisfy { $0.vaultPath == "/vault" })
    }

    @Test("claim merges into an existing vault row keeping the newer date")
    func claimMergesIntoExistingVaultRowKeepingNewerDate() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let older = Date(timeIntervalSinceNow: -1000)
        let newer = Date()
        context.insert(RecentDocument(path: "/vault/a.md", title: "a", lastOpened: newer))          // legacy ""
        context.insert(RecentDocument(path: "/vault/a.md", title: "a", lastOpened: older, vaultPath: "/vault"))
        try context.save()

        RecentsStore.claimLegacyRows(root: URL(fileURLWithPath: "/vault"), vaultKey: "/vault", in: context)
        let rows = try allRows(context)
        #expect(rows.count == 1)
        #expect(rows.first?.vaultPath == "/vault")
        #expect(rows.first?.lastOpened == newer)
    }

    @Test("claim ignores rows outside the root")
    func claimIgnoresRowsOutsideRoot() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(RecentDocument(path: "/elsewhere/a.md", title: "a"))
        try context.save()

        RecentsStore.claimLegacyRows(root: URL(fileURLWithPath: "/vault"), vaultKey: "/vault", in: context)
        #expect(try allRows(context).first?.vaultPath == "")
    }

    @Test("claim is idempotent")
    func claimIsIdempotent() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(RecentDocument(path: "/vault/a.md", title: "a", isFavorite: true))
        try context.save()
        let root = URL(fileURLWithPath: "/vault")

        RecentsStore.claimLegacyRows(root: root, vaultKey: "/vault", in: context)
        let after = try allRows(context).map { ($0.path, $0.vaultPath, $0.isFavorite) }
        RecentsStore.claimLegacyRows(root: root, vaultKey: "/vault", in: context)
        let again = try allRows(context).map { ($0.path, $0.vaultPath, $0.isFavorite) }
        #expect(after.count == again.count)
        #expect(after.elementsEqual(again, by: ==))
    }

    @Test("claimFavoriteFlags returns flagged URLs and clears flags")
    func claimFavoriteFlagsReturnsURLsAndClearsFlags() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(RecentDocument(path: "/vault/a.md", title: "a", isFavorite: true, vaultPath: "/vault"))
        context.insert(RecentDocument(path: "/vault/b.md", title: "b", vaultPath: "/vault"))
        context.insert(RecentDocument(path: "/other/c.md", title: "c", isFavorite: true, vaultPath: "/other"))
        try context.save()

        let urls = RecentsStore.claimFavoriteFlags(vaultKey: "/vault", in: context)
        #expect(urls.map(\.path) == ["/vault/a.md"])
        let rows = try allRows(context)
        #expect(rows.first { $0.path == "/vault/a.md" }?.isFavorite == false)
        #expect(rows.first { $0.path == "/other/c.md" }?.isFavorite == true)   // other bucket untouched
    }

    // MARK: - Prune & clear

    @Test("prune deletes missing files only in the given bucket")
    func pruneDeletesMissingFilesOnlyInVaultBucket() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let dir = try makeDir()
        let real = try touch(dir, "real.md")
        let key = RecentsStore.vaultKey(forRoot: dir)

        RecentsStore.record(url: real, vaultKey: key, in: context)
        context.insert(RecentDocument(path: dir.appendingPathComponent("gone.md").path, title: "gone", vaultPath: key))
        context.insert(RecentDocument(path: "/other/also-gone.md", title: "other", vaultPath: "/other"))
        try context.save()

        RecentsStore.prune(vaultKey: key, in: context)
        let rows = try allRows(context)
        #expect(rows.count == 2)
        #expect(rows.contains { $0.title == "real" })
        #expect(rows.contains { $0.vaultPath == "/other" })   // other bucket spared
    }

    @Test("prune spares favorites")
    func pruneSparesFavorites() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(RecentDocument(path: "/nowhere/fav.md", title: "fav", isFavorite: true, vaultPath: "/nowhere"))
        try context.save()

        RecentsStore.prune(vaultKey: "/nowhere", in: context)
        #expect(try allRows(context).count == 1)
    }

    @Test("clear deletes only non-favorites for the key")
    func clearDeletesOnlyNonFavoritesForKey() throws {
        let container = try makeContainer()
        let context = container.mainContext
        context.insert(RecentDocument(path: "/vault/a.md", title: "a", vaultPath: "/vault"))
        context.insert(RecentDocument(path: "/vault/b.md", title: "b", vaultPath: "/vault"))
        context.insert(RecentDocument(path: "/loose.md", title: "loose", isFavorite: true))   // "" bucket favorite
        context.insert(RecentDocument(path: "/other/c.md", title: "c", vaultPath: "/other"))
        try context.save()

        RecentsStore.clearRecents(vaultKey: "/vault", in: context)
        let rows = try allRows(context)
        #expect(rows.count == 2)
        #expect(rows.contains { $0.title == "loose" })
        #expect(rows.contains { $0.title == "c" })
    }

    // MARK: - Follow the file

    @Test("rename rewrites the exact row and regenerates title + type")
    func renameRewritesExactRowAndRegeneratesTitle() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let old = URL(fileURLWithPath: "/vault/old-note.md")
        let new = URL(fileURLWithPath: "/vault/README.md")
        RecentsStore.record(url: old, vaultKey: "/vault", in: context)

        RecentsStore.handleRename(oldURL: old, newURL: new, vaultKey: "/vault", in: context)
        let row = try #require(try allRows(context).first)
        #expect(row.path == "/vault/README.md")
        #expect(row.title == "README")
        #expect(row.documentType == RecentsStore.documentType(for: new).rawValue)
    }

    @Test("folder rename rewrites prefixed rows")
    func renameRewritesPrefixRows() throws {
        let container = try makeContainer()
        let context = container.mainContext
        RecentsStore.record(url: URL(fileURLWithPath: "/vault/docs/inner/a.md"), vaultKey: "/vault", in: context)
        RecentsStore.record(url: URL(fileURLWithPath: "/vault/docs-extra/b.md"), vaultKey: "/vault", in: context)

        RecentsStore.handleRename(
            oldURL: URL(fileURLWithPath: "/vault/docs"),
            newURL: URL(fileURLWithPath: "/vault/documents"),
            vaultKey: "/vault",
            in: context
        )
        let paths = try allRows(context).map(\.path).sorted()
        // "docs-extra" must NOT match the "docs" prefix.
        #expect(paths == ["/vault/docs-extra/b.md", "/vault/documents/inner/a.md"])
    }

    @Test("delete removes exact and prefixed rows")
    func deleteRemovesExactAndPrefixRows() throws {
        let container = try makeContainer()
        let context = container.mainContext
        RecentsStore.record(url: URL(fileURLWithPath: "/vault/docs/a.md"), vaultKey: "/vault", in: context)
        RecentsStore.record(url: URL(fileURLWithPath: "/vault/docs/deep/b.md"), vaultKey: "/vault", in: context)
        RecentsStore.record(url: URL(fileURLWithPath: "/vault/keep.md"), vaultKey: "/vault", in: context)

        RecentsStore.handleDelete(url: URL(fileURLWithPath: "/vault/docs"), vaultKey: "/vault", in: context)
        let rows = try allRows(context)
        #expect(rows.count == 1)
        #expect(rows.first?.path == "/vault/keep.md")
    }

    // MARK: - Legacy favorites bucket

    @Test("legacy toggle writes standardized paths into the given bucket")
    func legacyToggleWritesBucketStandardized() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let dotted = URL(fileURLWithPath: "/loose/x/../a.md")

        RecentsStore.legacyToggleFavorite(url: dotted, vaultKey: "", in: context)
        let row = try #require(try allRows(context).first)
        #expect(row.path == "/loose/a.md")
        #expect(row.vaultPath == "")
        #expect(row.isFavorite)
        #expect(RecentsStore.legacyIsFavorite(url: URL(fileURLWithPath: "/loose/a.md"), vaultKey: "", in: context))

        RecentsStore.legacyToggleFavorite(url: dotted, vaultKey: "", in: context)
        #expect(!RecentsStore.legacyIsFavorite(url: dotted, vaultKey: "", in: context))
    }
}
