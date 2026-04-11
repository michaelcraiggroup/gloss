import Testing
import Foundation
@testable import Gloss

@Suite("Link Database Forward Links")
struct LinkDatabaseForwardLinksTests {

    @Test("Forward links return symmetric data to backlinks")
    func forwardLinksSymmetric() throws {
        let db = try LinkDatabase()

        try db.upsertFile(path: "/vault/target.md", title: "target", modifiedAt: Date())
        let sourceId = try db.upsertFile(path: "/vault/source.md", title: "source", modifiedAt: Date())
        try db.replaceLinks(fileId: sourceId, links: [
            (targetName: "target", linkType: "supports", displayText: nil, lineNumber: 7)
        ])
        try db.resolveAllLinks()

        let forward = try db.forwardLinks(forPath: "/vault/source.md")
        #expect(forward.count == 1)
        #expect(forward[0].targetName == "target")
        #expect(forward[0].targetPath == "/vault/target.md")
        #expect(forward[0].linkType == .supports)
        #expect(forward[0].lineNumber == 7)
        #expect(forward[0].isResolved == true)
    }

    @Test("Forward links include unresolved links with isResolved=false")
    func forwardLinksUnresolved() throws {
        let db = try LinkDatabase()

        let sourceId = try db.upsertFile(path: "/vault/source.md", title: "source", modifiedAt: Date())
        try db.replaceLinks(fileId: sourceId, links: [
            (targetName: "missing", linkType: "related", displayText: nil, lineNumber: 1)
        ])
        try db.resolveAllLinks()

        let forward = try db.forwardLinks(forPath: "/vault/source.md")
        #expect(forward.count == 1)
        #expect(forward[0].isResolved == false)
        #expect(forward[0].targetPath == nil)
    }

    @Test("Backlinks expose isResolved=true after resolution")
    func backlinksIsResolved() throws {
        let db = try LinkDatabase()
        try db.upsertFile(path: "/vault/target.md", title: "target", modifiedAt: Date())
        let sourceId = try db.upsertFile(path: "/vault/source.md", title: "source", modifiedAt: Date())
        try db.replaceLinks(fileId: sourceId, links: [
            (targetName: "target", linkType: "related", displayText: nil, lineNumber: 1)
        ])
        try db.resolveAllLinks()

        let backlinks = try db.backlinks(forPath: "/vault/target.md")
        #expect(backlinks.count == 1)
        #expect(backlinks[0].isResolved == true)
    }

    @Test("Broken link count matches isResolved=0 rows")
    func brokenLinkCount() throws {
        let db = try LinkDatabase()
        try db.upsertFile(path: "/vault/target.md", title: "target", modifiedAt: Date())
        let sourceId = try db.upsertFile(path: "/vault/source.md", title: "source", modifiedAt: Date())
        try db.replaceLinks(fileId: sourceId, links: [
            (targetName: "target", linkType: "related", displayText: nil, lineNumber: 1),
            (targetName: "missing-1", linkType: "related", displayText: nil, lineNumber: 2),
            (targetName: "missing-2", linkType: "supports", displayText: nil, lineNumber: 3)
        ])
        try db.resolveAllLinks()

        #expect(try db.brokenLinkCount() == 2)
        #expect(try db.linkCount() == 3)
    }

    @Test("Broken links list includes source titles")
    func brokenLinksList() throws {
        let db = try LinkDatabase()
        let sourceId = try db.upsertFile(path: "/vault/notes.md", title: "notes", modifiedAt: Date())
        try db.replaceLinks(fileId: sourceId, links: [
            (targetName: "ghost", linkType: "related", displayText: nil, lineNumber: 4)
        ])
        try db.resolveAllLinks()

        let broken = try db.brokenLinks()
        #expect(broken.count == 1)
        #expect(broken[0].sourceTitle == "notes")
        #expect(broken[0].targetName == "ghost")
        #expect(broken[0].isResolved == false)
    }

    @Test("Orphan files have no inbound and no outbound links")
    func orphanFiles() throws {
        let db = try LinkDatabase()
        try db.upsertFile(path: "/vault/orphan.md", title: "orphan", modifiedAt: Date())
        try db.upsertFile(path: "/vault/target.md", title: "target", modifiedAt: Date())
        let sourceId = try db.upsertFile(path: "/vault/source.md", title: "source", modifiedAt: Date())
        try db.replaceLinks(fileId: sourceId, links: [
            (targetName: "target", linkType: "related", displayText: nil, lineNumber: 1)
        ])
        try db.resolveAllLinks()

        let orphans = try db.orphanFiles()
        #expect(orphans.count == 1)
        #expect(orphans[0].path == "/vault/orphan.md")
    }

    @Test("Hub files ranked by inbound link count")
    func hubFiles() throws {
        let db = try LinkDatabase()
        let hubId = try db.upsertFile(path: "/vault/hub.md", title: "hub", modifiedAt: Date())
        _ = hubId
        try db.upsertFile(path: "/vault/lonely.md", title: "lonely", modifiedAt: Date())

        let src1 = try db.upsertFile(path: "/vault/a.md", title: "a", modifiedAt: Date())
        let src2 = try db.upsertFile(path: "/vault/b.md", title: "b", modifiedAt: Date())
        let src3 = try db.upsertFile(path: "/vault/c.md", title: "c", modifiedAt: Date())

        try db.replaceLinks(fileId: src1, links: [
            (targetName: "hub", linkType: "related", displayText: nil, lineNumber: 1)
        ])
        try db.replaceLinks(fileId: src2, links: [
            (targetName: "hub", linkType: "supports", displayText: nil, lineNumber: 1)
        ])
        try db.replaceLinks(fileId: src3, links: [
            (targetName: "lonely", linkType: "related", displayText: nil, lineNumber: 1)
        ])
        try db.resolveAllLinks()

        let hubs = try db.hubFiles(limit: 10)
        #expect(hubs.count == 2)
        #expect(hubs[0].title == "hub")
        #expect(hubs[0].linkCount == 2)
        #expect(hubs[1].title == "lonely")
        #expect(hubs[1].linkCount == 1)
    }

    @Test("Forward links empty for unknown file")
    func forwardLinksUnknownFile() throws {
        let db = try LinkDatabase()
        let result = try db.forwardLinks(forPath: "/vault/nonexistent.md")
        #expect(result.isEmpty)
    }
}
