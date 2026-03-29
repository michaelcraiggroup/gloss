import Testing
import Foundation
@testable import Gloss

@Suite("Tag Queries")
struct TagQueryTests {

    @Test("allTagCounts returns unique tags with counts")
    func allTagCounts() throws {
        let db = try LinkDatabase()
        let file1 = try db.upsertFile(path: "/vault/a.md", title: "a", modifiedAt: Date())
        let file2 = try db.upsertFile(path: "/vault/b.md", title: "b", modifiedAt: Date())
        let file3 = try db.upsertFile(path: "/vault/c.md", title: "c", modifiedAt: Date())

        try db.replaceTags(fileId: file1, tags: ["swift", "macos"])
        try db.replaceTags(fileId: file2, tags: ["swift", "rust"])
        try db.replaceTags(fileId: file3, tags: ["swift"])

        let tagCounts = try db.allTagCounts()
        #expect(tagCounts.count == 3)

        // Sorted alphabetically: macos, rust, swift
        #expect(tagCounts[0].tag == "macos")
        #expect(tagCounts[0].count == 1)
        #expect(tagCounts[1].tag == "rust")
        #expect(tagCounts[1].count == 1)
        #expect(tagCounts[2].tag == "swift")
        #expect(tagCounts[2].count == 3)
    }

    @Test("allTagCounts returns empty for no tags")
    func allTagCountsEmpty() throws {
        let db = try LinkDatabase()
        try db.upsertFile(path: "/vault/a.md", title: "a", modifiedAt: Date())
        let tagCounts = try db.allTagCounts()
        #expect(tagCounts.isEmpty)
    }

    @Test("tags(forFileId:) returns tags for a specific file")
    func tagsForFile() throws {
        let db = try LinkDatabase()
        let file1 = try db.upsertFile(path: "/vault/a.md", title: "a", modifiedAt: Date())
        let file2 = try db.upsertFile(path: "/vault/b.md", title: "b", modifiedAt: Date())

        try db.replaceTags(fileId: file1, tags: ["swift", "macos"])
        try db.replaceTags(fileId: file2, tags: ["rust"])

        let tags1 = try db.tags(forFileId: file1)
        #expect(tags1 == ["macos", "swift"]) // alphabetical

        let tags2 = try db.tags(forFileId: file2)
        #expect(tags2 == ["rust"])
    }

    @Test("tags(forFileId:) returns empty for file with no tags")
    func tagsForFileEmpty() throws {
        let db = try LinkDatabase()
        let fileId = try db.upsertFile(path: "/vault/a.md", title: "a", modifiedAt: Date())
        let tags = try db.tags(forFileId: fileId)
        #expect(tags.isEmpty)
    }

    @Test("files(forTag:) returns all files with a specific tag")
    func filesForTag() throws {
        let db = try LinkDatabase()
        let file1 = try db.upsertFile(path: "/vault/a.md", title: "a", modifiedAt: Date())
        let file2 = try db.upsertFile(path: "/vault/b.md", title: "b", modifiedAt: Date())
        let file3 = try db.upsertFile(path: "/vault/c.md", title: "c", modifiedAt: Date())

        try db.replaceTags(fileId: file1, tags: ["swift", "macos"])
        try db.replaceTags(fileId: file2, tags: ["swift"])
        try db.replaceTags(fileId: file3, tags: ["rust"])

        let swiftFiles = try db.files(forTag: "swift")
        #expect(swiftFiles.count == 2)
        #expect(swiftFiles[0].title == "a") // alphabetical
        #expect(swiftFiles[1].title == "b")

        let rustFiles = try db.files(forTag: "rust")
        #expect(rustFiles.count == 1)
        #expect(rustFiles[0].title == "c")
    }

    @Test("files(forTag:) returns empty for nonexistent tag")
    func filesForTagEmpty() throws {
        let db = try LinkDatabase()
        try db.upsertFile(path: "/vault/a.md", title: "a", modifiedAt: Date())
        let files = try db.files(forTag: "nonexistent")
        #expect(files.isEmpty)
    }

    @Test("Tag counts update after tag replacement")
    func tagCountsAfterReplacement() throws {
        let db = try LinkDatabase()
        let fileId = try db.upsertFile(path: "/vault/a.md", title: "a", modifiedAt: Date())

        try db.replaceTags(fileId: fileId, tags: ["swift", "macos"])
        #expect(try db.allTagCounts().count == 2)

        // Replace with different tags
        try db.replaceTags(fileId: fileId, tags: ["rust"])
        let tagCounts = try db.allTagCounts()
        #expect(tagCounts.count == 1)
        #expect(tagCounts[0].tag == "rust")
    }

    @Test("Cascading delete removes tags from counts")
    func cascadingDeleteRemovesTags() throws {
        let db = try LinkDatabase()
        let fileId = try db.upsertFile(path: "/vault/a.md", title: "a", modifiedAt: Date())
        try db.replaceTags(fileId: fileId, tags: ["swift", "macos"])
        #expect(try db.allTagCounts().count == 2)

        try db.deleteFile(path: "/vault/a.md")
        #expect(try db.allTagCounts().isEmpty)
    }

    @Test("SearchScope includes tags case")
    func searchScopeHasTags() {
        let scope = SearchScope.tags
        #expect(scope.rawValue == "Tags")
        #expect(SearchScope.allCases.contains(.tags))
    }

    @Test("FileTreeModel tag filter state")
    @MainActor
    func fileTreeTagFilter() {
        let model = FileTreeModel()
        #expect(model.activeTagFilter == nil)
        #expect(model.tagFilteredFiles == nil)

        model.filterByTag("swift", files: [
            (path: "/vault/a.md", title: "a"),
            (path: "/vault/b.md", title: "b")
        ])
        #expect(model.activeTagFilter == "swift")
        #expect(model.tagFilteredFiles?.count == 2)

        model.clearTagFilter()
        #expect(model.activeTagFilter == nil)
        #expect(model.tagFilteredFiles == nil)
    }
}
