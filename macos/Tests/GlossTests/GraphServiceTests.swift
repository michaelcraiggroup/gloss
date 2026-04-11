import Testing
import Foundation
@testable import Gloss

@Suite("Graph Service")
struct GraphServiceTests {

    /// Build a small fixture vault:
    ///
    ///   hub ← note-a (related) ← note-b (supports)
    ///   hub ← note-b (related)
    ///   note-a → missing (broken, unresolved)
    ///   orphan (no links)
    ///   Tags: note-a=[feature], note-b=[feature, draft], hub=[]
    private func populateDatabase() throws -> LinkDatabase {
        let db = try LinkDatabase()

        let hubId = try db.upsertFile(path: "/vault/hub.md", title: "hub", modifiedAt: Date())
        _ = hubId
        try db.upsertFile(path: "/vault/orphan.md", title: "orphan", modifiedAt: Date())
        let aId = try db.upsertFile(path: "/vault/note-a.md", title: "note-a", modifiedAt: Date())
        let bId = try db.upsertFile(path: "/vault/note-b.md", title: "note-b", modifiedAt: Date())

        try db.replaceLinks(fileId: aId, links: [
            (targetName: "hub", linkType: "related", displayText: nil, lineNumber: 1),
            (targetName: "missing", linkType: "related", displayText: nil, lineNumber: 2)
        ])
        try db.replaceLinks(fileId: bId, links: [
            (targetName: "hub", linkType: "related", displayText: nil, lineNumber: 1),
            (targetName: "note-a", linkType: "supports", displayText: nil, lineNumber: 2)
        ])

        try db.replaceTags(fileId: aId, tags: ["feature"])
        try db.replaceTags(fileId: bId, tags: ["feature", "draft"])
        try db.resolveAllLinks()

        return db
    }

    @Test("Unfiltered graph has every file and every resolved edge")
    func unfilteredGraph() throws {
        let db = try populateDatabase()
        let data = GraphService.buildGraph(database: db, filter: .unfiltered)

        #expect(data.nodes.count == 4)
        // 3 resolved edges (note-a→hub, note-b→hub, note-b→note-a); the
        // note-a→missing edge is broken and should be dropped.
        #expect(data.edges.count == 3)
        #expect(data.edges.allSatisfy { $0.source != $0.target })
    }

    @Test("In-degree reflects resolved backlinks")
    func degreeCounts() throws {
        let db = try populateDatabase()
        let data = GraphService.buildGraph(database: db, filter: .unfiltered)

        let hub = data.nodes.first { $0.title == "hub" }
        let noteA = data.nodes.first { $0.title == "note-a" }
        let orphan = data.nodes.first { $0.title == "orphan" }

        #expect(hub?.inDegree == 2)      // linked from note-a and note-b
        #expect(noteA?.inDegree == 1)    // linked from note-b
        #expect(noteA?.outDegree == 1)   // note-a→hub (broken edge dropped)
        #expect(orphan?.inDegree == 0)
        #expect(orphan?.outDegree == 0)
    }

    @Test("Tag filter restricts node set and drops dangling edges")
    func tagFilter() throws {
        let db = try populateDatabase()
        var filter = GraphFilter.unfiltered
        filter.tag = "feature"
        let data = GraphService.buildGraph(database: db, filter: filter)

        // Only note-a and note-b have the feature tag — hub is excluded.
        #expect(data.nodes.count == 2)
        #expect(data.nodes.allSatisfy { $0.tags.contains("feature") })
        // The surviving edge is note-b → note-a (supports). Edges to hub are
        // dropped because hub is no longer in the retained set.
        #expect(data.edges.count == 1)
        #expect(data.edges.first?.type == "supports")
    }

    @Test("Link type filter keeps only matching edges")
    func linkTypeFilter() throws {
        let db = try populateDatabase()
        var filter = GraphFilter.unfiltered
        filter.linkType = .supports
        let data = GraphService.buildGraph(database: db, filter: filter)

        #expect(data.edges.count == 1)
        #expect(data.edges.allSatisfy { $0.type == "supports" })
    }

    @Test("Center + depth filter expands BFS neighborhood")
    func centerDepthFilter() throws {
        let db = try populateDatabase()
        var filter = GraphFilter.unfiltered
        filter.centerPath = "/vault/hub.md"
        filter.maxDepth = 1
        let data = GraphService.buildGraph(database: db, filter: filter)

        // Depth 1 from hub should reach note-a and note-b (both link to hub),
        // but not orphan (no connection).
        let paths = Set(data.nodes.map(\.path))
        #expect(paths.contains("/vault/hub.md"))
        #expect(paths.contains("/vault/note-a.md"))
        #expect(paths.contains("/vault/note-b.md"))
        #expect(!paths.contains("/vault/orphan.md"))
    }

    @Test("Center depth 0 returns only the center node")
    func centerDepthZero() throws {
        let db = try populateDatabase()
        var filter = GraphFilter.unfiltered
        filter.centerPath = "/vault/hub.md"
        filter.maxDepth = 0
        let data = GraphService.buildGraph(database: db, filter: filter)

        #expect(data.nodes.count == 1)
        #expect(data.nodes.first?.path == "/vault/hub.md")
        #expect(data.edges.isEmpty)
    }

    @Test("Empty database returns empty graph")
    func emptyDatabase() throws {
        let db = try LinkDatabase()
        let data = GraphService.buildGraph(database: db, filter: .unfiltered)
        #expect(data.nodes.isEmpty)
        #expect(data.edges.isEmpty)
    }

    @Test("Broken links are excluded from edges")
    func brokenLinksExcluded() throws {
        let db = try populateDatabase()
        let data = GraphService.buildGraph(database: db, filter: .unfiltered)
        // note-a → missing is broken and should not appear as an edge.
        #expect(data.edges.allSatisfy { edge in
            edge.source != "/vault/note-a.md" || edge.target != "/vault/missing.md"
        })
    }
}
