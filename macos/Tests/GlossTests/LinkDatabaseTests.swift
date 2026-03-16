import Testing
import Foundation
@testable import Gloss

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
