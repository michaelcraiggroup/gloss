import Foundation
import Testing
@testable import Gloss

/// The two-writer semantics for synced favorites.json: the user's INTENT
/// applies to FRESH disk state (remote additions survive, local removals
/// stick), conflict versions union, and the watcher passthrough detects
/// exactly the favorites file.
@Suite("Favorites two-writer merge")
struct FavoritesMergeTests {
    private typealias Entry = FavoritesService.FavoritesFile.Entry

    private func entry(_ rel: String, at seconds: TimeInterval = 0) -> Entry {
        Entry(relativePath: rel, addedAt: Date(timeIntervalSince1970: seconds))
    }

    // MARK: - Intent-on-fresh-state (the core two-writer property)

    @Test func remoteAdditionSurvivesLocalAdd() {
        // Disk state has what device B added; our stale memory never saw it.
        var disk = [entry("from-device-b.md")]
        let changed = FavoritesService.applySetFavorite(
            "local-add.md", favored: true, addedAt: .now, in: &disk)
        #expect(changed)
        #expect(Set(disk.map(\.relativePath)) == ["from-device-b.md", "local-add.md"])
    }

    @Test func localRemovalSticksDespiteDiskStillHavingIt() {
        var disk = [entry("keep.md"), entry("unfavorite-me.md")]
        let changed = FavoritesService.applySetFavorite(
            "unfavorite-me.md", favored: false, addedAt: .now, in: &disk)
        #expect(changed)
        #expect(disk.map(\.relativePath) == ["keep.md"])
    }

    @Test func intentIsIdempotentAgainstConcurrentSameChange() {
        // Both devices favorited the same file: applying "favored" to fresh
        // state that already has it is a no-op, not a duplicate.
        var disk = [entry("both.md")]
        let changed = FavoritesService.applySetFavorite(
            "both.md", favored: true, addedAt: .now, in: &disk)
        #expect(!changed)
        #expect(disk.count == 1)
    }

    @Test func renameAndDeleteTransformFreshState() {
        var disk = [entry("dir/a.md"), entry("dir/sub/b.md"), entry("other.md")]
        #expect(FavoritesService.applyRename(oldRel: "dir", newRel: "moved", in: &disk))
        #expect(Set(disk.map(\.relativePath)) == ["moved/a.md", "moved/sub/b.md", "other.md"])
        #expect(FavoritesService.applyDelete("moved", in: &disk))
        #expect(disk.map(\.relativePath) == ["other.md"])
    }

    @Test func importDedupes() {
        var disk = [entry("existing.md")]
        let changed = FavoritesService.applyImport(
            ["existing.md", "new.md"], addedAt: .now, in: &disk)
        #expect(changed)
        #expect(disk.count == 2)
        #expect(!FavoritesService.applyImport(["existing.md"], addedAt: .now, in: &disk))
    }

    // MARK: - Conflict-version union

    @Test func unionKeepsEveryPathWithEarliestAddedAt() {
        let merged = FavoritesService.union([
            [entry("a.md", at: 100), entry("b.md", at: 50)],
            [entry("b.md", at: 10), entry("c.md", at: 30)],
        ])
        #expect(merged.map(\.relativePath) == ["a.md", "b.md", "c.md"])
        #expect(merged.first { $0.relativePath == "b.md" }?.addedAt
            == Date(timeIntervalSince1970: 10))
    }

    // MARK: - Watcher passthrough detection

    @Test func passthroughDetectsOnlyTheFavoritesFile() {
        #expect(FavoritesService.pathsIncludeFavoritesFile(
            ["/v/.gloss/favorites.json"]))
        #expect(FavoritesService.pathsIncludeFavoritesFile(
            ["/v/note.md", "/v/.gloss/favorites.json"]))
        #expect(!FavoritesService.pathsIncludeFavoritesFile(
            ["/v/note.md", "/v/.gloss/index.sqlite", "/v/.gloss/config.json"]))
        #expect(!FavoritesService.pathsIncludeFavoritesFile(
            ["/v/favorites.json"]))   // not inside .gloss — a user's own file
    }

    // MARK: - Reload adopts external writes (local-vault integration)

    @Test @MainActor func reloadFromDiskAdoptsExternalWrite() throws {
        let vault = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-fav-merge-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: vault.appendingPathComponent(".gloss"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: vault) }
        try "# n".write(
            to: vault.appendingPathComponent("synced.md"), atomically: true, encoding: .utf8)

        let service = FavoritesService()
        service.configure(rootURL: vault)
        #expect(service.favorites.isEmpty)

        // "Another device" writes the file behind our back.
        let json = """
        {"version":1,"favorites":[{"relativePath":"synced.md","addedAt":"2026-08-08T00:00:00Z"}]}
        """
        try json.write(
            to: vault.appendingPathComponent(".gloss/favorites.json"),
            atomically: true, encoding: .utf8)

        service.reloadFromDisk()
        #expect(service.favorites.map(\.relativePath) == ["synced.md"])
        #expect(service.isFavorite(vault.appendingPathComponent("synced.md")))
    }
}
