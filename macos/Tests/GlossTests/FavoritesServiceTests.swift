import Testing
import Foundation
@testable import Gloss

@Suite("FavoritesService")
@MainActor
struct FavoritesServiceTests {

    /// Fresh on-disk vault root per test.
    private func makeVault() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-fav-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @discardableResult
    private func touch(_ root: URL, _ relative: String) throws -> URL {
        let url = root.appendingPathComponent(relative)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try Data("# test\n".utf8).write(to: url)
        return url
    }

    private func favoritesFileURL(_ root: URL) -> URL {
        root.appendingPathComponent(".gloss/favorites.json")
    }

    // MARK: - Persistence

    @Test("Toggle adds then removes a favorite")
    func toggleAddsThenRemoves() throws {
        let root = try makeVault()
        let file = try touch(root, "notes/a.md")
        let service = FavoritesService()
        service.configure(rootURL: root)

        service.toggle(file)
        #expect(service.isFavorite(file))
        #expect(service.favorites.count == 1)
        #expect(service.favorites.first?.relativePath == "notes/a.md")

        service.toggle(file)
        #expect(!service.isFavorite(file))
        #expect(service.favorites.isEmpty)
    }

    @Test("JSON round-trips across configure")
    func jsonRoundTripPersistsAcrossConfigure() throws {
        let root = try makeVault()
        let file = try touch(root, "projects/roadmap.md")
        let first = FavoritesService()
        first.configure(rootURL: root)
        first.toggle(file)

        let second = FavoritesService()
        second.configure(rootURL: root)
        #expect(second.isFavorite(file))
        #expect(second.favorites.first?.title == "roadmap")
    }

    @Test("First save creates the .gloss directory")
    func createsGlossDirectoryOnFirstSave() throws {
        let root = try makeVault()
        let file = try touch(root, "a.md")
        let service = FavoritesService()
        service.configure(rootURL: root)
        #expect(!FileManager.default.fileExists(atPath: favoritesFileURL(root).path))

        service.toggle(file)
        #expect(FileManager.default.fileExists(atPath: favoritesFileURL(root).path))
    }

    @Test("Missing favorites file loads as empty")
    func missingFileLoadsEmpty() throws {
        let root = try makeVault()
        let service = FavoritesService()
        service.configure(rootURL: root)
        #expect(service.favorites.isEmpty)
    }

    @Test("Corrupt file loads empty and is not rewritten until a mutation")
    func corruptFileLoadsEmptyAndIsNotRewrittenUntilMutation() throws {
        let root = try makeVault()
        let file = try touch(root, "a.md")
        let corrupt = "{ this is not json"
        try FileManager.default.createDirectory(
            at: favoritesFileURL(root).deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(corrupt.utf8).write(to: favoritesFileURL(root))

        let service = FavoritesService()
        service.configure(rootURL: root)
        #expect(service.favorites.isEmpty)
        // configure() must not clobber the (possibly half-synced) file…
        #expect(try String(contentsOf: favoritesFileURL(root), encoding: .utf8) == corrupt)

        // …but the next mutation owns it.
        service.toggle(file)
        #expect(try String(contentsOf: favoritesFileURL(root), encoding: .utf8) != corrupt)
        #expect(service.isFavorite(file))
    }

    @Test("File is written with version 1")
    func versionFieldWrittenAsOne() throws {
        let root = try makeVault()
        let file = try touch(root, "a.md")
        let service = FavoritesService()
        service.configure(rootURL: root)
        service.toggle(file)

        let data = try Data(contentsOf: favoritesFileURL(root))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(object?["version"] as? Int == 1)
    }

    @Test("Relative paths survive moving the vault root")
    func relativePathsSurviveRootMove() throws {
        let root = try makeVault()
        let file = try touch(root, "deep/nested/note.md")
        let service = FavoritesService()
        service.configure(rootURL: root)
        service.toggle(file)

        let moved = root.deletingLastPathComponent()
            .appendingPathComponent("gloss-fav-tests-moved-\(UUID().uuidString)")
        try FileManager.default.moveItem(at: root, to: moved)

        let reopened = FavoritesService()
        reopened.configure(rootURL: moved)
        #expect(reopened.favorites.count == 1)
        #expect(reopened.isFavorite(moved.appendingPathComponent("deep/nested/note.md")))
        #expect(reopened.favorites.first?.fileExists == true)
    }

    // MARK: - Scope

    @Test("handles() rejects URLs outside the vault and without a vault")
    func handlesRejectsOutOfRootURL() throws {
        let root = try makeVault()
        let service = FavoritesService()
        service.configure(rootURL: root)
        #expect(!service.handles(URL(fileURLWithPath: "/somewhere/else.md")))
        #expect(!service.isFavorite(URL(fileURLWithPath: "/somewhere/else.md")))

        service.configure(rootURL: nil)
        #expect(!service.handles(root.appendingPathComponent("a.md")))
    }

    @Test("handles() resolves symlinked roots (index-derived URLs)")
    func handlesResolvesSymlinkedRoot() throws {
        let container = try makeVault()
        let real = container.appendingPathComponent("real-vault")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        let link = container.appendingPathComponent("link-vault")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
        let realFile = try touch(real, "notes/a.md")

        // Vault opened via the symlink; URL arrives symlink-RESOLVED (as the
        // link index emits them).
        let service = FavoritesService()
        service.configure(rootURL: link)
        #expect(service.handles(realFile.resolvingSymlinksInPath()))

        service.toggle(realFile.resolvingSymlinksInPath())
        // And the unresolved form (tree-derived) must agree.
        #expect(service.isFavorite(link.appendingPathComponent("notes/a.md")))
    }

    @Test("isFavorite uses standardized comparison")
    func isFavoriteUsesStandardizedComparison() throws {
        let root = try makeVault()
        let file = try touch(root, "notes/a.md")
        let service = FavoritesService()
        service.configure(rootURL: root)
        service.toggle(file)

        let dotted = root.appendingPathComponent("notes/../notes/a.md")
        #expect(service.isFavorite(dotted))
    }

    // MARK: - Follow the file

    @Test("Renaming a file rewrites its entry")
    func renameFileRewritesEntry() throws {
        let root = try makeVault()
        let old = try touch(root, "old-name.md")
        let service = FavoritesService()
        service.configure(rootURL: root)
        service.toggle(old)

        let new = root.appendingPathComponent("new-name.md")
        try FileManager.default.moveItem(at: old, to: new)
        service.handleRename(oldURL: old, newURL: new)

        #expect(!service.isFavorite(old))
        #expect(service.isFavorite(new))
        #expect(service.favorites.first?.title == "new-name")
    }

    @Test("Renaming a folder rewrites prefixed entries")
    func renameFolderRewritesPrefixedEntries() throws {
        let root = try makeVault()
        let file = try touch(root, "docs/inner/a.md")
        let service = FavoritesService()
        service.configure(rootURL: root)
        service.toggle(file)

        let oldDir = root.appendingPathComponent("docs")
        let newDir = root.appendingPathComponent("documents")
        try FileManager.default.moveItem(at: oldDir, to: newDir)
        service.handleRename(oldURL: oldDir, newURL: newDir)

        #expect(service.favorites.first?.relativePath == "documents/inner/a.md")
        #expect(service.favorites.first?.fileExists == true)
    }

    @Test("Deleting a folder removes prefixed entries")
    func deleteFolderRemovesPrefixedEntries() throws {
        let root = try makeVault()
        let inner = try touch(root, "docs/inner/a.md")
        let outer = try touch(root, "keep.md")
        let service = FavoritesService()
        service.configure(rootURL: root)
        service.toggle(inner)
        service.toggle(outer)

        service.handleDelete(url: root.appendingPathComponent("docs"))
        #expect(service.favorites.count == 1)
        #expect(service.favorites.first?.relativePath == "keep.md")
    }

    // MARK: - Import & existence

    @Test("importFavorites dedupes against existing entries")
    func importFavoritesDedupes() throws {
        let root = try makeVault()
        let a = try touch(root, "a.md")
        let b = try touch(root, "b.md")
        let service = FavoritesService()
        service.configure(rootURL: root)
        service.toggle(a)

        service.importFavorites(urls: [a, b, b, URL(fileURLWithPath: "/outside.md")])
        #expect(service.favorites.count == 2)
    }

    @Test("Missing files stay listed, flagged, and heal on refresh")
    func missingFileFlaggedNotDroppedAndHeals() throws {
        let root = try makeVault()
        let file = try touch(root, "a.md")
        let service = FavoritesService()
        service.configure(rootURL: root)
        service.toggle(file)

        try FileManager.default.removeItem(at: file)
        service.refreshExistence()
        #expect(service.favorites.count == 1)
        #expect(service.favorites.first?.fileExists == false)

        try touch(root, "a.md")
        service.refreshExistence()
        #expect(service.favorites.first?.fileExists == true)
    }

    @Test("Favorites sorted by title")
    func favoritesSortedByTitle() throws {
        let root = try makeVault()
        let service = FavoritesService()
        service.configure(rootURL: root)
        for name in ["zebra.md", "apple.md", "mango.md"] {
            service.toggle(try touch(root, name))
        }
        #expect(service.favorites.map(\.title) == ["apple", "mango", "zebra"])
    }

    @Test("configure(nil) clears state")
    func configureNilClearsState() throws {
        let root = try makeVault()
        let file = try touch(root, "a.md")
        let service = FavoritesService()
        service.configure(rootURL: root)
        service.toggle(file)

        service.configure(rootURL: nil)
        #expect(service.favorites.isEmpty)
        #expect(service.rootURL == nil)
        #expect(!service.isFavorite(file))
    }
}
