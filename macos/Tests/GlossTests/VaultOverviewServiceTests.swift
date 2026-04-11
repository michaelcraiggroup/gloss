import Testing
import Foundation
@testable import Gloss

@Suite("Vault Overview Service")
@MainActor
struct VaultOverviewServiceTests {

    private func populateDatabase() throws -> LinkDatabase {
        let db = try LinkDatabase()

        let hubId = try db.upsertFile(path: "/vault/hub.md", title: "hub", modifiedAt: Date())
        _ = hubId
        try db.upsertFile(path: "/vault/orphan.md", title: "orphan", modifiedAt: Date())
        let src1 = try db.upsertFile(path: "/vault/note-a.md", title: "note-a", modifiedAt: Date())
        let src2 = try db.upsertFile(path: "/vault/note-b.md", title: "note-b", modifiedAt: Date())

        try db.replaceLinks(fileId: src1, links: [
            (targetName: "hub", linkType: "related", displayText: nil, lineNumber: 1),
            (targetName: "missing-thing", linkType: "related", displayText: nil, lineNumber: 2)
        ])
        try db.replaceLinks(fileId: src2, links: [
            (targetName: "hub", linkType: "supports", displayText: nil, lineNumber: 1)
        ])
        try db.replaceTags(fileId: src1, tags: ["feature", "notes"])
        try db.replaceTags(fileId: src2, tags: ["feature"])
        try db.resolveAllLinks()

        return db
    }

    /// Wait for the detached refresh Task to complete.
    private func waitForRefresh(_ service: VaultOverviewService) async {
        for _ in 0..<50 {
            if !service.isRefreshing && service.lastRefreshedAt != nil {
                return
            }
            try? await Task.sleep(nanoseconds: 20_000_000) // 20ms
        }
    }

    @Test("Refresh populates all aggregate properties")
    func refreshPopulates() async throws {
        let db = try populateDatabase()
        let service = VaultOverviewService()

        service.refresh(database: db)
        await waitForRefresh(service)

        #expect(service.fileCount == 4)
        #expect(service.linkCount == 3)
        #expect(service.brokenCount == 1)
        #expect(service.tagCount == 2)
        #expect(service.hubs.first?.title == "hub")
        #expect(service.hubs.first?.linkCount == 2)
        #expect(service.orphans.contains { $0.title == "orphan" })
        #expect(service.brokenLinks.count == 1)
        #expect(service.brokenLinks.first?.targetName == "missing-thing")
        #expect(service.recentlyChanged.count == 4)
    }

    @Test("Refresh with nil database clears state")
    func refreshNilClears() async throws {
        let db = try populateDatabase()
        let service = VaultOverviewService()

        service.refresh(database: db)
        await waitForRefresh(service)
        #expect(service.fileCount == 4)

        service.refresh(database: nil)
        #expect(service.fileCount == 0)
        #expect(service.hubs.isEmpty)
        #expect(service.brokenLinks.isEmpty)
    }

    @Test("Clear resets all properties")
    func clearResets() async throws {
        let db = try populateDatabase()
        let service = VaultOverviewService()

        service.refresh(database: db)
        await waitForRefresh(service)

        service.clear()
        #expect(service.fileCount == 0)
        #expect(service.linkCount == 0)
        #expect(service.brokenCount == 0)
        #expect(service.tagCount == 0)
        #expect(service.hubs.isEmpty)
        #expect(service.orphans.isEmpty)
        #expect(service.topTags.isEmpty)
        #expect(service.recentlyChanged.isEmpty)
        #expect(service.brokenLinks.isEmpty)
        #expect(service.lastRefreshedAt == nil)
    }

    @Test("Empty database returns zeros")
    func emptyDatabase() async throws {
        let db = try LinkDatabase()
        let service = VaultOverviewService()

        service.refresh(database: db)
        await waitForRefresh(service)

        #expect(service.fileCount == 0)
        #expect(service.linkCount == 0)
        #expect(service.brokenCount == 0)
        #expect(service.tagCount == 0)
        #expect(service.hubs.isEmpty)
    }

    @Test("Top tags ordered by count descending")
    func topTagsOrdered() async throws {
        let db = try LinkDatabase()
        let id1 = try db.upsertFile(path: "/vault/a.md", title: "a", modifiedAt: Date())
        let id2 = try db.upsertFile(path: "/vault/b.md", title: "b", modifiedAt: Date())
        let id3 = try db.upsertFile(path: "/vault/c.md", title: "c", modifiedAt: Date())
        try db.replaceTags(fileId: id1, tags: ["popular", "rare"])
        try db.replaceTags(fileId: id2, tags: ["popular"])
        try db.replaceTags(fileId: id3, tags: ["popular"])

        let service = VaultOverviewService()
        service.refresh(database: db)
        await waitForRefresh(service)

        #expect(service.topTags.first?.tag == "popular")
        #expect(service.topTags.first?.count == 3)
        #expect(service.topTags.count == 2)
    }
}
