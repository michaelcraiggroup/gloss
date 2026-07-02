import Testing
import Foundation
@testable import Gloss

/// Filename search is backed by the link index's `files` table (via
/// `FilenameSearchService`) — it replaced the synchronous whole-tree walk
/// that force-loaded every directory during view-body evaluation.
@Suite("Filename Search")
struct FileTreeSearchTests {

    /// In-memory database mirroring the old temp-tree fixture.
    private func makeDatabase() throws -> LinkDatabase {
        let db = try LinkDatabase()
        _ = try db.upsertFile(path: "/vault/README.md", title: "README", modifiedAt: Date())
        _ = try db.upsertFile(path: "/vault/PROJECT_PLAN.md", title: "PROJECT_PLAN", modifiedAt: Date())
        _ = try db.upsertFile(path: "/vault/notes.md", title: "notes", modifiedAt: Date())
        _ = try db.upsertFile(path: "/vault/docs/api.md", title: "api", modifiedAt: Date())
        _ = try db.upsertFile(path: "/vault/docs/setup.md", title: "setup", modifiedAt: Date())
        return db
    }

    @Test("Matches filter by filename")
    func matchesFilterByName() throws {
        let db = try makeDatabase()
        let hits = FilenameSearchService.matches(rows: try db.allFiles(), query: "readme")
        #expect(hits.count == 1)
        #expect(hits.first?.filename == "README.md")
    }

    @Test("Finds files in subdirectories")
    func findsSubdirectoryFiles() throws {
        let db = try makeDatabase()
        let hits = FilenameSearchService.matches(rows: try db.allFiles(), query: "api")
        #expect(hits.count == 1)
        #expect(hits.first?.path == "/vault/docs/api.md")
    }

    @Test("Matching is case insensitive")
    func caseInsensitive() throws {
        let db = try makeDatabase()
        let hits = FilenameSearchService.matches(rows: try db.allFiles(), query: "PLAN")
        #expect(hits.count == 1)
        #expect(hits.first?.filename == "PROJECT_PLAN.md")
    }

    @Test("The extension is searchable")
    func extensionSearchable() throws {
        let db = try makeDatabase()
        let hits = FilenameSearchService.matches(rows: try db.allFiles(), query: "api.md")
        #expect(hits.count == 1)
    }

    @Test("No matches yields empty result")
    func noMatches() throws {
        let db = try makeDatabase()
        let hits = FilenameSearchService.matches(rows: try db.allFiles(), query: "nonexistent")
        #expect(hits.isEmpty)
    }

    @Test("Result limit is honored")
    func limitHonored() throws {
        let db = try LinkDatabase()
        for i in 0..<20 {
            _ = try db.upsertFile(path: "/vault/note-\(i).md", title: "note-\(i)", modifiedAt: Date())
        }
        let hits = FilenameSearchService.matches(rows: try db.allFiles(), query: "note", limit: 5)
        #expect(hits.count == 5)
    }

    @Test("Empty query deactivates the service")
    @MainActor
    func emptyQueryDeactivates() throws {
        let service = FilenameSearchService()
        service.search(query: "", database: try makeDatabase())
        #expect(service.results == nil)
    }

    @Test("Wiki target resolves by title")
    func wikiTargetByTitle() throws {
        let db = try makeDatabase()
        #expect(try db.pathForWikiTarget("api") == "/vault/docs/api.md")
        #expect(try db.pathForWikiTarget("missing") == nil)
    }

    @Test("Wiki target resolves folder/note path suffix")
    func wikiTargetSuffix() throws {
        let db = try makeDatabase()
        #expect(try db.pathForWikiTarget("docs/setup") == "/vault/docs/setup.md")
    }
}
