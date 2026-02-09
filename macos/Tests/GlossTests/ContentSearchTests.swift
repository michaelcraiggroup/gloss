import Testing
import Foundation
@testable import Gloss

@Suite("Content Search")
@MainActor
struct ContentSearchTests {

    /// Create a temp directory with markdown files containing known content.
    private func makeTempTree() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-content-search-\(UUID().uuidString)")
        let fm = FileManager.default
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)

        try "# Welcome\nThis is the homepage with important info.".write(
            to: tmp.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try "# Plan\nWe need to ship the feature by Friday.".write(
            to: tmp.appendingPathComponent("PLAN.md"), atomically: true, encoding: .utf8)
        try "# Notes\nSome unrelated content here.".write(
            to: tmp.appendingPathComponent("notes.md"), atomically: true, encoding: .utf8)

        let sub = tmp.appendingPathComponent("docs")
        try fm.createDirectory(at: sub, withIntermediateDirectories: true)
        try "# API Reference\nThe important endpoint returns JSON.".write(
            to: sub.appendingPathComponent("api.md"), atomically: true, encoding: .utf8)

        // Excluded directory
        let nodeModules = tmp.appendingPathComponent("node_modules")
        try fm.createDirectory(at: nodeModules, withIntermediateDirectories: true)
        try "# Hidden\nThis has important secrets.".write(
            to: nodeModules.appendingPathComponent("secret.md"), atomically: true, encoding: .utf8)

        return tmp
    }

    @Test("Finds content match in root file")
    func findsContentInRoot() async throws {
        let tmp = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let service = ContentSearchService()
        service.search(query: "homepage", rootURL: tmp)

        // Wait for debounce + search to complete
        try await Task.sleep(nanoseconds: 500_000_000)

        #expect(service.results.count == 1)
        #expect(service.results.first?.fileName == "README.md")
        #expect(service.results.first?.lineNumber == 2)
    }

    @Test("Finds content match in subdirectory")
    func findsContentInSubdirectory() async throws {
        let tmp = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let service = ContentSearchService()
        service.search(query: "endpoint", rootURL: tmp)

        try await Task.sleep(nanoseconds: 500_000_000)

        #expect(service.results.count == 1)
        #expect(service.results.first?.fileName == "api.md")
    }

    @Test("Search is case insensitive")
    func caseInsensitive() async throws {
        let tmp = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let service = ContentSearchService()
        service.search(query: "IMPORTANT", rootURL: tmp)

        try await Task.sleep(nanoseconds: 500_000_000)

        // "important" appears in README.md and api.md
        #expect(service.results.count == 2)
    }

    @Test("No matches returns empty results")
    func noMatches() async throws {
        let tmp = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let service = ContentSearchService()
        service.search(query: "xyznonexistent", rootURL: tmp)

        try await Task.sleep(nanoseconds: 500_000_000)

        #expect(service.results.isEmpty)
    }

    @Test("Empty query clears results")
    func emptyQueryClears() async throws {
        let tmp = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let service = ContentSearchService()
        // First search with content
        service.search(query: "homepage", rootURL: tmp)
        try await Task.sleep(nanoseconds: 500_000_000)
        #expect(!service.results.isEmpty)

        // Clear with empty query
        service.search(query: "", rootURL: tmp)
        #expect(service.results.isEmpty)
    }

    @Test("Ignores excluded directories")
    func ignoresExcluded() async throws {
        let tmp = try makeTempTree()
        defer { try? FileManager.default.removeItem(at: tmp) }

        let service = ContentSearchService()
        // "secrets" only appears in node_modules/secret.md
        service.search(query: "secrets", rootURL: tmp)

        try await Task.sleep(nanoseconds: 500_000_000)

        #expect(service.results.isEmpty)
    }
}
