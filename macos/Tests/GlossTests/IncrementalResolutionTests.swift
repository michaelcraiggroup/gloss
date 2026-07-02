import Testing
import Foundation
import GRDB
@testable import Gloss

/// Phase 3 of the vault event storm overhaul (#35): incremental link
/// resolution must produce exactly what a full re-resolve produces, deletes
/// must un-resolve inbound links without a global pass, rebuilds must skip
/// unchanged files, and watcher-triggered rebuilds must be rate limited.
@Suite("Incremental Resolution & Index Pipeline")
struct IncrementalResolutionTests {

    /// Canonical snapshot of the links table for equality comparison.
    private func snapshot(_ db: LinkDatabase) throws -> [String] {
        try db.dbQueue.read { database in
            let rows = try Row.fetchAll(
                database,
                sql: "SELECT sourceFileId, targetName, targetFileId, isResolved FROM links ORDER BY sourceFileId, targetName"
            )
            return rows.map { row in
                let target: Int64? = row["targetFileId"]
                let resolved: Bool = row["isResolved"]
                return "\(row["sourceFileId"] as Int64)|\(row["targetName"] as String)|\(target.map(String.init) ?? "nil")|\(resolved ? 1 : 0)"
            }
        }
    }

    @Test("Incremental resolution matches a full re-resolve")
    func incrementalMatchesFull() throws {
        let db = try LinkDatabase()

        // A links to B (title), docs/C (path suffix), and a missing note —
        // indexed before either target exists.
        let idA = try db.upsertFile(path: "/v/A.md", title: "A", modifiedAt: Date())
        try db.replaceLinks(fileId: idA, links: [
            (targetName: "B", linkType: "related", displayText: nil, lineNumber: 1),
            (targetName: "docs/C", linkType: "related", displayText: nil, lineNumber: 2),
            (targetName: "Missing", linkType: "related", displayText: nil, lineNumber: 3),
        ])
        try db.resolveLinksTouching(fileId: idA)

        // B arrives: its own link to A resolves, and A's link to B resolves inbound.
        let idB = try db.upsertFile(path: "/v/B.md", title: "B", modifiedAt: Date())
        try db.replaceLinks(fileId: idB, links: [
            (targetName: "A", linkType: "supports", displayText: nil, lineNumber: 1),
        ])
        try db.resolveLinksTouching(fileId: idB)

        // C arrives under docs/: A's folder/note suffix link resolves inbound.
        let idC = try db.upsertFile(path: "/v/docs/C.md", title: "C", modifiedAt: Date())
        try db.replaceLinks(fileId: idC, links: [])
        try db.resolveLinksTouching(fileId: idC)

        let incremental = try snapshot(db)
        try db.resolveAllLinks()
        let full = try snapshot(db)

        #expect(incremental == full)
        #expect(incremental.contains("\(idA)|B|\(idB)|1"))
        #expect(incremental.contains("\(idA)|docs/C|\(idC)|1"))
        #expect(incremental.contains("\(idA)|Missing|nil|0"))
        #expect(incremental.contains("\(idB)|A|\(idA)|1"))
    }

    @Test("Deleting a file un-resolves inbound links without a global pass")
    func deleteUnresolvesInbound() throws {
        let db = try LinkDatabase()
        let idA = try db.upsertFile(path: "/v/A.md", title: "A", modifiedAt: Date())
        try db.replaceLinks(fileId: idA, links: [
            (targetName: "B", linkType: "related", displayText: nil, lineNumber: 1),
        ])
        _ = try db.upsertFile(path: "/v/B.md", title: "B", modifiedAt: Date())
        try db.resolveAllLinks()
        #expect(try db.brokenLinkCount() == 0)

        try db.deleteFile(path: "/v/B.md")
        #expect(try snapshot(db) == ["\(idA)|B|nil|0"])
        #expect(try db.brokenLinkCount() == 1)
    }

    @Test("Stale-file removal un-resolves inbound links")
    func staleRemovalUnresolvesInbound() throws {
        let db = try LinkDatabase()
        let idA = try db.upsertFile(path: "/v/A.md", title: "A", modifiedAt: Date())
        try db.replaceLinks(fileId: idA, links: [
            (targetName: "B", linkType: "related", displayText: nil, lineNumber: 1),
        ])
        _ = try db.upsertFile(path: "/v/B.md", title: "B", modifiedAt: Date())
        try db.resolveAllLinks()

        let removed = try db.removeStaleFiles(existingPaths: ["/v/A.md"])
        #expect(removed == 1)
        #expect(try snapshot(db) == ["\(idA)|B|nil|0"])
    }

    @Test("Second build skips unchanged files by mtime")
    @MainActor
    func mtimeSkip() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-mtime-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        for name in ["one", "two", "three"] {
            try "# \(name)".write(
                to: tempDir.appendingPathComponent("\(name).md"),
                atomically: true, encoding: .utf8
            )
        }

        let index = LinkIndex()
        index.buildIndex(rootURL: tempDir)
        try await waitForBuild(index)
        #expect(index.lastBuildStats == .init(indexed: 3, skipped: 0, removed: 0))

        index.buildIndex(rootURL: tempDir)
        try await waitForBuild(index)
        #expect(index.lastBuildStats == .init(indexed: 0, skipped: 3, removed: 0))

        // Editing one file re-indexes just that file.
        try await Task.sleep(nanoseconds: 50_000_000)
        try "# one (edited)".write(
            to: tempDir.appendingPathComponent("one.md"),
            atomically: true, encoding: .utf8
        )
        index.buildIndex(rootURL: tempDir)
        try await waitForBuild(index)
        #expect(index.lastBuildStats == .init(indexed: 1, skipped: 2, removed: 0))
    }

    @Test("Watcher-triggered rebuild requests are rate limited and coalesced")
    @MainActor
    func rebuildRateLimit() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-ratelimit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try "# note".write(
            to: tempDir.appendingPathComponent("note.md"),
            atomically: true, encoding: .utf8
        )

        let index = LinkIndex()
        index.fullRebuildMinInterval = 2.0
        index.buildIndex(rootURL: tempDir)
        try await waitForBuild(index)
        #expect(index.fullBuildCount == 1)

        // A burst of requests inside the window starts nothing new…
        index.requestFullRebuild()
        index.requestFullRebuild()
        index.requestFullRebuild()
        #expect(index.fullBuildCount == 1)

        // …but exactly one trailing build runs once the window elapses.
        for _ in 0..<40 where index.fullBuildCount < 2 {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        #expect(index.fullBuildCount == 2)
        try await waitForBuild(index)
        try await Task.sleep(nanoseconds: 300_000_000)
        #expect(index.fullBuildCount == 2, "burst must coalesce into a single trailing build")
    }

    /// Poll until the current build finishes.
    @MainActor
    private func waitForBuild(_ index: LinkIndex) async throws {
        for _ in 0..<50 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if !index.isIndexing { return }
        }
        try #require(!index.isIndexing, "index build timed out")
    }
}
