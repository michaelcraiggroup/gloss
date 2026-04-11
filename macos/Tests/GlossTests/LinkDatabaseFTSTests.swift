import Testing
import Foundation
@testable import Gloss

@Suite("Link Database FTS5")
struct LinkDatabaseFTSTests {

    /// Populate a tiny in-memory vault with three files indexed for FTS.
    ///
    /// - alpha.md: talks about strategies and pricing
    /// - beta.md:  talks about monetization strategy
    /// - gamma.md: unrelated ocean content, tagged `research`
    private func populateDatabase() throws -> LinkDatabase {
        let db = try LinkDatabase()

        let alphaId = try db.upsertFile(path: "/vault/alpha.md", title: "alpha", modifiedAt: Date())
        let betaId = try db.upsertFile(path: "/vault/beta.md", title: "beta", modifiedAt: Date())
        let gammaId = try db.upsertFile(path: "/vault/gamma.md", title: "gamma", modifiedAt: Date())

        try db.indexFileContent(
            fileId: alphaId,
            title: "alpha",
            body: "Pricing strategy for the launch. Considering tiered plans."
        )
        try db.indexFileContent(
            fileId: betaId,
            title: "beta",
            body: "Monetization strategy: one-time purchase, no subscription."
        )
        try db.indexFileContent(
            fileId: gammaId,
            title: "gamma",
            body: "The ocean is deep and unrelated to business topics."
        )

        try db.replaceTags(fileId: gammaId, tags: ["research"])
        try db.replaceTags(fileId: betaId, tags: ["monetization"])

        return db
    }

    @Test("Indexing a file populates the FTS table")
    func indexPopulatesFTS() throws {
        let db = try populateDatabase()
        #expect(try db.ftsRowCount() == 3)
    }

    @Test("Basic search returns matching files ranked")
    func basicSearch() throws {
        let db = try populateDatabase()
        let hits = try db.searchFTS(query: "strategy")
        #expect(hits.count == 2)
        // Every hit should be one of alpha or beta.
        let paths = Set(hits.map(\.path))
        #expect(paths.contains("/vault/alpha.md"))
        #expect(paths.contains("/vault/beta.md"))
        // bm25 rank is populated (lower = better).
        #expect(hits.allSatisfy { $0.rank < 0 }) // bm25 returns negative values by default in SQLite
    }

    @Test("Snippet contains match delimiters")
    func snippetDelimiters() throws {
        let db = try populateDatabase()
        let hits = try db.searchFTS(query: "monetization")
        #expect(hits.count == 1)
        #expect(hits.first?.path == "/vault/beta.md")
        // The snippet function was configured to wrap matches in «...»
        let snippet = hits.first?.snippet ?? ""
        #expect(snippet.contains("«"))
        #expect(snippet.contains("»"))
    }

    @Test("Prefix matching finds partial words")
    func prefixMatch() throws {
        let db = try populateDatabase()
        // "monet" should prefix-match "monetization"
        let hits = try db.searchFTS(query: "monet")
        #expect(hits.count == 1)
        #expect(hits.first?.path == "/vault/beta.md")
    }

    @Test("Empty and whitespace queries return no hits")
    func emptyQuery() throws {
        let db = try populateDatabase()
        #expect(try db.searchFTS(query: "").isEmpty)
        #expect(try db.searchFTS(query: "   ").isEmpty)
    }

    @Test("Tag filter narrows results to tagged files")
    func tagFilter() throws {
        let db = try populateDatabase()
        // "strategy" matches alpha + beta, but only beta is tagged monetization
        let hits = try db.searchFTS(query: "strategy", tag: "monetization")
        #expect(hits.count == 1)
        #expect(hits.first?.path == "/vault/beta.md")
    }

    @Test("Date range filter narrows by modifiedAt")
    func dateRangeFilter() throws {
        let db = try LinkDatabase()
        let past = Date(timeIntervalSince1970: 1_000_000)
        let now = Date()
        let oldId = try db.upsertFile(path: "/vault/old.md", title: "old", modifiedAt: past)
        let newId = try db.upsertFile(path: "/vault/new.md", title: "new", modifiedAt: now)
        try db.indexFileContent(fileId: oldId, title: "old", body: "markdown content")
        try db.indexFileContent(fileId: newId, title: "new", body: "markdown content")

        let recentRange = Date(timeIntervalSinceNow: -3600)...Date(timeIntervalSinceNow: 3600)
        let hits = try db.searchFTS(query: "markdown", dateRange: recentRange)
        #expect(hits.count == 1)
        #expect(hits.first?.path == "/vault/new.md")
    }

    @Test("Special characters in query don't crash search")
    func specialCharacterSafety() throws {
        let db = try populateDatabase()
        // Pure punctuation produces no valid pattern → empty result, no crash.
        let hits = try db.searchFTS(query: "!!!???")
        #expect(hits.isEmpty)
    }

    @Test("Re-indexing a file replaces the FTS row")
    func reindexReplaces() throws {
        let db = try LinkDatabase()
        let id = try db.upsertFile(path: "/vault/file.md", title: "file", modifiedAt: Date())
        try db.indexFileContent(fileId: id, title: "file", body: "original content about apples")

        var hits = try db.searchFTS(query: "apples")
        #expect(hits.count == 1)

        // Re-index with different content
        try db.indexFileContent(fileId: id, title: "file", body: "new content about oranges")

        hits = try db.searchFTS(query: "apples")
        #expect(hits.isEmpty)
        hits = try db.searchFTS(query: "oranges")
        #expect(hits.count == 1)
    }

    @Test("Deleting a file removes its FTS row")
    func deleteCascadesFTS() throws {
        let db = try populateDatabase()
        #expect(try db.ftsRowCount() == 3)

        try db.deleteFile(path: "/vault/alpha.md")
        #expect(try db.ftsRowCount() == 2)

        let hits = try db.searchFTS(query: "pricing")
        #expect(hits.isEmpty)
    }

    @Test("removeStaleFiles cascades FTS rows too")
    func removeStaleFilesCascadesFTS() throws {
        let db = try populateDatabase()
        // Keep only beta — alpha and gamma should be removed.
        try db.removeStaleFiles(existingPaths: ["/vault/beta.md"])
        #expect(try db.ftsRowCount() == 1)

        let hits = try db.searchFTS(query: "strategy")
        #expect(hits.count == 1)
        #expect(hits.first?.path == "/vault/beta.md")
    }

    @Test("Clear FTS empties the table without touching files")
    func clearFTS() throws {
        let db = try populateDatabase()
        try db.clearFTS()
        #expect(try db.ftsRowCount() == 0)
        #expect(try db.fileCount() == 3)
        #expect(try db.searchFTS(query: "strategy").isEmpty)
    }
}
