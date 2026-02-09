import Testing
import Foundation
@testable import Gloss

@Suite("File Tree Search")
struct FileTreeSearchTests {

    /// Create a temp directory with markdown files for search testing.
    private func makeTempTree() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-search-test-\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)

        // Create files
        try "# README".write(to: tmp.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try "# Plan".write(to: tmp.appendingPathComponent("PROJECT_PLAN.md"), atomically: true, encoding: .utf8)
        try "# Notes".write(to: tmp.appendingPathComponent("notes.md"), atomically: true, encoding: .utf8)

        // Create subdirectory with files
        let sub = tmp.appendingPathComponent("docs")
        try fm.createDirectory(at: sub, withIntermediateDirectories: true)
        try "# API".write(to: sub.appendingPathComponent("api.md"), atomically: true, encoding: .utf8)
        try "# Setup".write(to: sub.appendingPathComponent("setup.md"), atomically: true, encoding: .utf8)

        return tmp
    }

    @Test("Empty search returns nil")
    @MainActor
    func emptySearchReturnsNil() throws {
        let tmp = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let model = FileTreeModel()
        model.openFolder(tmp)
        model.searchQuery = ""
        #expect(model.searchResults == nil)
    }

    @Test("Search filters files by name")
    @MainActor
    func searchFiltersFiles() throws {
        let tmp = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let model = FileTreeModel()
        model.openFolder(tmp)
        model.searchQuery = "readme"
        let results = model.searchResults
        #expect(results != nil)
        #expect(results?.count == 1)
        #expect(results?.first?.name == "README.md")
    }

    @Test("Search finds files in subdirectories")
    @MainActor
    func searchFindsSubdirectoryFiles() throws {
        let tmp = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let model = FileTreeModel()
        model.openFolder(tmp)
        model.searchQuery = "api"
        let results = model.searchResults
        #expect(results != nil)
        #expect(results?.count == 1)
        #expect(results?.first?.name == "api.md")
    }

    @Test("Search is case insensitive")
    @MainActor
    func searchIsCaseInsensitive() throws {
        let tmp = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let model = FileTreeModel()
        model.openFolder(tmp)
        model.searchQuery = "PLAN"
        let results = model.searchResults
        #expect(results != nil)
        #expect(results?.count == 1)
    }

    @Test("Search with no matches returns empty array")
    @MainActor
    func searchNoMatches() throws {
        let tmp = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let model = FileTreeModel()
        model.openFolder(tmp)
        model.searchQuery = "nonexistent"
        let results = model.searchResults
        #expect(results != nil)
        #expect(results?.isEmpty == true)
    }

    @Test("Search returns nil when no folder is open")
    @MainActor
    func searchNoFolder() {
        let model = FileTreeModel()
        model.searchQuery = "test"
        #expect(model.searchResults == nil)
    }
}
