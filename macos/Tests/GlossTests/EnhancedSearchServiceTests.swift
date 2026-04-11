import Testing
import Foundation
@testable import Gloss

@Suite("Enhanced Search Service")
@MainActor
struct EnhancedSearchServiceTests {

    /// Build a small database with content that exercises each filter.
    private func makeDatabase() throws -> LinkDatabase {
        let db = try LinkDatabase()
        let aId = try db.upsertFile(path: "/v/strategy-doc.md", title: "strategy-doc", modifiedAt: Date())
        let bId = try db.upsertFile(path: "/v/pitches/growth-pitch.md", title: "growth-pitch", modifiedAt: Date())
        let cId = try db.upsertFile(path: "/v/readme.md", title: "readme", modifiedAt: Date())

        try db.indexFileContent(fileId: aId, title: "strategy-doc",
                                body: "Pricing strategy and monetization for the launch.")
        try db.indexFileContent(fileId: bId, title: "growth-pitch",
                                body: "Pitch for a growth experiment targeting pricing tiers.")
        try db.indexFileContent(fileId: cId, title: "readme",
                                body: "Overview and getting-started info.")

        try db.replaceTags(fileId: aId, tags: ["monetization"])
        try db.replaceTags(fileId: bId, tags: ["monetization", "experiments"])
        return db
    }

    /// Spin-wait until the service stops searching (debounce + async fetch).
    private func waitForSearch(_ service: EnhancedSearchService) async {
        for _ in 0..<60 {
            if !service.isSearching { return }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    @Test("Empty query clears results without hitting database")
    func emptyQuery() async throws {
        let db = try makeDatabase()
        let service = EnhancedSearchService()
        service.search(query: "", database: db)
        #expect(service.results.isEmpty)
        #expect(service.isSearching == false)
    }

    @Test("Nil database clears results")
    func nilDatabase() async throws {
        let service = EnhancedSearchService()
        service.search(query: "strategy", database: nil)
        #expect(service.results.isEmpty)
        #expect(service.isSearching == false)
    }

    @Test("Basic search returns FTS hits")
    func basicSearch() async throws {
        let db = try makeDatabase()
        let service = EnhancedSearchService()
        service.search(query: "strategy", database: db)
        await waitForSearch(service)

        #expect(service.results.count == 1)
        #expect(service.results.first?.title == "strategy-doc")
    }

    @Test("Prefix match picks up both strategy and growth docs")
    func prefixMatch() async throws {
        let db = try makeDatabase()
        let service = EnhancedSearchService()
        service.search(query: "pric", database: db)
        await waitForSearch(service)

        // Both strategy-doc ("Pricing") and growth-pitch ("pricing tiers") match.
        #expect(service.results.count == 2)
    }

    @Test("Tag filter narrows results")
    func tagFilter() async throws {
        let db = try makeDatabase()
        let service = EnhancedSearchService()
        service.tagFilter = "experiments"
        service.search(query: "pricing", database: db)
        await waitForSearch(service)

        #expect(service.results.count == 1)
        #expect(service.results.first?.title == "growth-pitch")
    }

    @Test("Document type filter excludes non-matching files")
    func documentTypeFilter() async throws {
        let db = try makeDatabase()
        let service = EnhancedSearchService()
        // Only the pitch folder should match when we filter by .pitch
        service.documentTypeFilter = .pitch
        service.search(query: "pricing", database: db)
        await waitForSearch(service)

        #expect(service.results.count == 1)
        #expect(service.results.first?.documentType == .pitch)
    }

    @Test("clearFilters resets all filter state")
    func clearFilters() async throws {
        let service = EnhancedSearchService()
        service.tagFilter = "foo"
        service.documentTypeFilter = .pitch
        service.dateRange = Date()...Date()
        #expect(service.hasActiveFilters)

        service.clearFilters()
        #expect(service.tagFilter == nil)
        #expect(service.documentTypeFilter == nil)
        #expect(service.dateRange == nil)
        #expect(service.hasActiveFilters == false)
    }

    @Test("rerun re-executes the last query with current filters")
    func rerunReusesLastQuery() async throws {
        let db = try makeDatabase()
        let service = EnhancedSearchService()
        service.search(query: "pricing", database: db)
        await waitForSearch(service)
        #expect(service.results.count == 2)

        // Add a filter, rerun — no need to re-type the query
        service.tagFilter = "experiments"
        service.rerun(database: db)
        await waitForSearch(service)
        #expect(service.results.count == 1)
    }

    @Test("cancel clears in-flight results")
    func cancelClears() async throws {
        let db = try makeDatabase()
        let service = EnhancedSearchService()
        service.search(query: "strategy", database: db)
        service.cancel()
        #expect(service.isSearching == false)
        #expect(service.results.isEmpty)
    }
}

@Suite("SearchHit snippet parsing")
struct SearchHitSnippetTests {

    @Test("Plain snippet with no matches parses as one segment")
    func plainSnippet() {
        let segments = SearchHit.parseSnippet("just some plain text")
        #expect(segments.count == 1)
        #expect(segments[0].isMatch == false)
        #expect(segments[0].text == "just some plain text")
    }

    @Test("Single match splits into three segments")
    func singleMatch() {
        let segments = SearchHit.parseSnippet("before «match» after")
        #expect(segments.count == 3)
        #expect(segments[0] == SearchHit.Segment(text: "before ", isMatch: false))
        #expect(segments[1] == SearchHit.Segment(text: "match", isMatch: true))
        #expect(segments[2] == SearchHit.Segment(text: " after", isMatch: false))
    }

    @Test("Multiple matches alternate correctly")
    func multipleMatches() {
        let segments = SearchHit.parseSnippet("«a» and «b» and «c»")
        #expect(segments.count == 5)
        #expect(segments[0].isMatch == true)
        #expect(segments[0].text == "a")
        #expect(segments[2].isMatch == true)
        #expect(segments[2].text == "b")
        #expect(segments[4].isMatch == true)
        #expect(segments[4].text == "c")
    }

    @Test("Match at start of snippet")
    func matchAtStart() {
        let segments = SearchHit.parseSnippet("«hit» and the rest")
        #expect(segments.first?.isMatch == true)
        #expect(segments.first?.text == "hit")
    }
}
