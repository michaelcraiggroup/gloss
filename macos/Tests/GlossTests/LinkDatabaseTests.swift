import Testing
import Foundation
@testable import Gloss
import GlossKit

@Suite("Link Database")
struct LinkDatabaseTests {

    @Test("Creates in-memory database")
    func createDatabase() throws {
        let db = try LinkDatabase()
        #expect(try db.fileCount() == 0)
        #expect(try db.linkCount() == 0)
    }

    @Test("Upserts a file")
    func upsertFile() throws {
        let db = try LinkDatabase()
        let id = try db.upsertFile(path: "/test/note.md", title: "note", modifiedAt: Date())
        #expect(id > 0)
        #expect(try db.fileCount() == 1)

        // Upsert same path returns same ID
        let id2 = try db.upsertFile(path: "/test/note.md", title: "note updated", modifiedAt: Date())
        #expect(id2 == id)
        #expect(try db.fileCount() == 1)
    }

    @Test("Deletes a file")
    func deleteFile() throws {
        let db = try LinkDatabase()
        try db.upsertFile(path: "/test/note.md", title: "note", modifiedAt: Date())
        #expect(try db.fileCount() == 1)
        try db.deleteFile(path: "/test/note.md")
        #expect(try db.fileCount() == 0)
    }

    @Test("Replaces links for a file")
    func replaceLinks() throws {
        let db = try LinkDatabase()
        let fileId = try db.upsertFile(path: "/test/source.md", title: "source", modifiedAt: Date())

        try db.replaceLinks(fileId: fileId, links: [
            (targetName: "target1", linkType: "related", displayText: nil, lineNumber: 5),
            (targetName: "target2", linkType: "supports", displayText: "evidence", lineNumber: 10)
        ])
        #expect(try db.linkCount() == 2)

        // Replace clears old links
        try db.replaceLinks(fileId: fileId, links: [
            (targetName: "target3", linkType: "contradicts", displayText: nil, lineNumber: 1)
        ])
        #expect(try db.linkCount() == 1)
    }

    // MARK: - Properties + Query (M1)

    @Test("Replaces frontmatter properties and clears old ones")
    func replaceProperties() throws {
        let db = try LinkDatabase()
        let fileId = try db.upsertFile(path: "/v/a.md", title: "a", modifiedAt: Date())
        try db.replaceProperties(fileId: fileId, properties: [
            (key: "status", value: "open"), (key: "priority", value: "high")
        ])
        let open = MdPlusQuery(id: "q", properties: [MdPlusPropertyFilter(key: "status", value: "open")])
        #expect(try db.runQuery(open).count == 1)

        try db.replaceProperties(fileId: fileId, properties: [(key: "status", value: "done")])
        #expect(try db.runQuery(open).isEmpty)
    }

    @Test("runQuery filters by tag and property, AND-combined")
    func runQueryFilters() throws {
        let db = try LinkDatabase()
        let a = try db.upsertFile(path: "/v/a.md", title: "Alpha", modifiedAt: Date(timeIntervalSince1970: 100))
        let b = try db.upsertFile(path: "/v/b.md", title: "Beta", modifiedAt: Date(timeIntervalSince1970: 200))
        try db.replaceTags(fileId: a, tags: ["project"])
        try db.replaceTags(fileId: b, tags: ["project"])
        try db.replaceProperties(fileId: a, properties: [(key: "status", value: "open")])
        try db.replaceProperties(fileId: b, properties: [(key: "status", value: "done")])

        #expect(try db.runQuery(MdPlusQuery(id: "q", tags: ["project"])).count == 2)

        let open = MdPlusQuery(id: "q", tags: ["project"],
                               properties: [MdPlusPropertyFilter(key: "status", value: "open")])
        let rows = try db.runQuery(open)
        #expect(rows.count == 1)
        #expect(rows.first?.title == "Alpha")
        #expect(rows.first?.url.hasPrefix("file://") == true)
    }

    @Test("runQuery honors sort, order, and limit")
    func runQuerySortLimit() throws {
        let db = try LinkDatabase()
        let a = try db.upsertFile(path: "/v/a.md", title: "Alpha", modifiedAt: Date(timeIntervalSince1970: 100))
        let b = try db.upsertFile(path: "/v/b.md", title: "Beta", modifiedAt: Date(timeIntervalSince1970: 200))
        try db.replaceTags(fileId: a, tags: ["x"])
        try db.replaceTags(fileId: b, tags: ["x"])

        let descByModified = MdPlusQuery(id: "q", tags: ["x"], sort: .modified, order: .desc)
        #expect(try db.runQuery(descByModified).first?.title == "Beta")

        let limited = MdPlusQuery(id: "q", tags: ["x"], limit: 1)
        #expect(try db.runQuery(limited).count == 1)
    }

    @Test("Cascading delete removes properties")
    func cascadeDeleteProperties() throws {
        let db = try LinkDatabase()
        let fileId = try db.upsertFile(path: "/v/a.md", title: "a", modifiedAt: Date())
        try db.replaceProperties(fileId: fileId, properties: [(key: "status", value: "open")])
        try db.deleteFile(path: "/v/a.md")
        let open = MdPlusQuery(id: "q", properties: [MdPlusPropertyFilter(key: "status", value: "open")])
        #expect(try db.runQuery(open).isEmpty)
    }

    @Test("unlinkedMentions finds text mentions that aren't linked")
    func unlinkedMentions() throws {
        let db = try LinkDatabase()
        let target = try db.upsertFile(path: "/v/shape-up.md", title: "Shape Up", modifiedAt: Date())
        let mentions = try db.upsertFile(path: "/v/notes.md", title: "notes", modifiedAt: Date())
        let linker = try db.upsertFile(path: "/v/plan.md", title: "plan", modifiedAt: Date())
        try db.indexFileContent(fileId: target, title: "Shape Up", body: "The Shape Up method.")
        try db.indexFileContent(fileId: mentions, title: "notes", body: "We should use Shape Up here.")
        try db.indexFileContent(fileId: linker, title: "plan", body: "See Shape Up.")
        try db.replaceLinks(fileId: linker, links: [
            (targetName: "Shape Up", linkType: "related", displayText: nil, lineNumber: 1)
        ])
        try db.resolveAllLinks()

        let paths = try db.unlinkedMentions(forTitle: "Shape Up", currentFileId: target).map(\.path)
        #expect(paths.contains("/v/notes.md"))       // mentions, not linked → included
        #expect(!paths.contains("/v/plan.md"))        // already links → excluded
        #expect(!paths.contains("/v/shape-up.md"))    // the note itself → excluded
    }

    @Test("unlinkedMentions ignores very short titles")
    func unlinkedMentionsShortTitle() throws {
        let db = try LinkDatabase()
        let id = try db.upsertFile(path: "/v/a.md", title: "a", modifiedAt: Date())
        try db.indexFileContent(fileId: id, title: "a", body: "a a a")
        #expect(try db.unlinkedMentions(forTitle: "a", currentFileId: 999).isEmpty)
    }

    @Test("Cascading delete removes links and tags")
    func cascadingDelete() throws {
        let db = try LinkDatabase()
        let fileId = try db.upsertFile(path: "/test/note.md", title: "note", modifiedAt: Date())
        try db.replaceLinks(fileId: fileId, links: [
            (targetName: "other", linkType: "related", displayText: nil, lineNumber: 1)
        ])
        try db.replaceTags(fileId: fileId, tags: ["swift", "test"])
        #expect(try db.linkCount() == 1)

        try db.deleteFile(path: "/test/note.md")
        #expect(try db.linkCount() == 0)
    }

    @Test("Fetches backlinks for a file")
    func backlinks() throws {
        let db = try LinkDatabase()

        // Create target file
        try db.upsertFile(path: "/vault/target.md", title: "target", modifiedAt: Date())

        // Create source file that links to target
        let sourceId = try db.upsertFile(path: "/vault/source.md", title: "source", modifiedAt: Date())
        try db.replaceLinks(fileId: sourceId, links: [
            (targetName: "target", linkType: "supports", displayText: nil, lineNumber: 3)
        ])
        try db.resolveAllLinks()

        let backlinks = try db.backlinks(forPath: "/vault/target.md")
        #expect(backlinks.count == 1)
        #expect(backlinks[0].sourceTitle == "source")
        #expect(backlinks[0].linkType == .supports)
        #expect(backlinks[0].lineNumber == 3)
    }

    @Test("Replaces tags for a file")
    func replaceTags() throws {
        let db = try LinkDatabase()
        let fileId = try db.upsertFile(path: "/test/note.md", title: "note", modifiedAt: Date())
        try db.replaceTags(fileId: fileId, tags: ["swift", "macos"])
        // Tags stored — no crash
        try db.replaceTags(fileId: fileId, tags: ["rust"])
        // Replaced — no crash
    }

    @Test("Removes stale files")
    func removeStaleFiles() throws {
        let db = try LinkDatabase()
        try db.upsertFile(path: "/vault/keep.md", title: "keep", modifiedAt: Date())
        try db.upsertFile(path: "/vault/remove.md", title: "remove", modifiedAt: Date())
        #expect(try db.fileCount() == 2)

        try db.removeStaleFiles(existingPaths: Set(["/vault/keep.md"]))
        #expect(try db.fileCount() == 1)
    }

    @Test("Resolves links after new file added")
    func resolvesAfterNewFile() throws {
        let db = try LinkDatabase()
        let sourceId = try db.upsertFile(path: "/vault/source.md", title: "source", modifiedAt: Date())
        try db.replaceLinks(fileId: sourceId, links: [
            (targetName: "future", linkType: "related", displayText: nil, lineNumber: 1)
        ])

        // No target yet — backlinks empty
        #expect(try db.backlinks(forPath: "/vault/future.md").isEmpty)

        // Now add the target file
        try db.upsertFile(path: "/vault/future.md", title: "future", modifiedAt: Date())
        try db.resolveAllLinks()

        let backlinks = try db.backlinks(forPath: "/vault/future.md")
        #expect(backlinks.count == 1)
        #expect(backlinks[0].sourceTitle == "source")
    }

    @Test("File indexed-at timestamp")
    func fileIndexedAt() throws {
        let db = try LinkDatabase()
        #expect(try db.fileIndexedAt(path: "/test/note.md") == nil)

        try db.upsertFile(path: "/test/note.md", title: "note", modifiedAt: Date())
        let indexedAt = try db.fileIndexedAt(path: "/test/note.md")
        #expect(indexedAt != nil)
    }

    @Test("Multiple source files linking to same target")
    func multipleBacklinks() throws {
        let db = try LinkDatabase()
        try db.upsertFile(path: "/vault/target.md", title: "target", modifiedAt: Date())

        let src1 = try db.upsertFile(path: "/vault/a.md", title: "a", modifiedAt: Date())
        let src2 = try db.upsertFile(path: "/vault/b.md", title: "b", modifiedAt: Date())

        try db.replaceLinks(fileId: src1, links: [
            (targetName: "target", linkType: "supports", displayText: nil, lineNumber: 1)
        ])
        try db.replaceLinks(fileId: src2, links: [
            (targetName: "target", linkType: "contradicts", displayText: nil, lineNumber: 5)
        ])
        try db.resolveAllLinks()

        let backlinks = try db.backlinks(forPath: "/vault/target.md")
        #expect(backlinks.count == 2)
    }
}
