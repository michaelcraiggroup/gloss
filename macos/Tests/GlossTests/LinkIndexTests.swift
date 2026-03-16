import Testing
import Foundation
@testable import Gloss
@testable import GlossKit

@Suite("Link Index")
struct LinkIndexTests {

    @Test("Builds index from vault directory")
    @MainActor
    func buildIndex() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create test files
        let noteA = "# Note A\n\nLinks to [[Note B::supports]]\n"
        let noteB = "# Note B\n\nLinks to [[Note A]]\n"
        try noteA.write(to: tempDir.appendingPathComponent("Note A.md"), atomically: true, encoding: .utf8)
        try noteB.write(to: tempDir.appendingPathComponent("Note B.md"), atomically: true, encoding: .utf8)

        let index = LinkIndex()
        index.buildIndex(rootURL: tempDir)

        // Wait for async indexing to complete
        try await Task.sleep(nanoseconds: 500_000_000)

        #expect(!index.isIndexing)
    }

    @Test("Backlinks refresh for target file")
    @MainActor
    func backlinkRefresh() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let source = "Links to [[target::supports]]\n"
        let target = "# Target\n\nSome content\n"
        try source.write(to: tempDir.appendingPathComponent("source.md"), atomically: true, encoding: .utf8)
        try target.write(to: tempDir.appendingPathComponent("target.md"), atomically: true, encoding: .utf8)

        let index = LinkIndex()
        index.buildIndex(rootURL: tempDir)

        // Wait for indexing to complete
        for _ in 0..<30 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if !index.isIndexing { break }
        }
        try #require(!index.isIndexing)

        // refreshBacklinks is synchronous
        index.refreshBacklinks(for: tempDir.appendingPathComponent("target.md"))

        try #require(!index.backlinks.isEmpty, "Backlinks should not be empty after refresh")
        #expect(index.backlinks[0].linkType == .supports)
        #expect(index.backlinks[0].links[0].sourceTitle == "source")
    }

    @Test("Empty backlinks for file with no inbound links")
    @MainActor
    func emptyBacklinks() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let source = "No links here\n"
        try source.write(to: tempDir.appendingPathComponent("lonely.md"), atomically: true, encoding: .utf8)

        let index = LinkIndex()
        index.buildIndex(rootURL: tempDir)

        for _ in 0..<20 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if !index.isIndexing { break }
        }

        index.refreshBacklinks(for: tempDir.appendingPathComponent("lonely.md"))
        try await Task.sleep(nanoseconds: 300_000_000)

        #expect(index.backlinks.isEmpty)
    }

    @Test("LinkType display names and icons")
    func linkTypeDisplayNames() {
        for type in LinkType.allCases {
            #expect(!type.displayName.isEmpty)
            #expect(!type.icon.isEmpty)
        }
    }

    @Test("LinkType fromRaw with unknown defaults to related")
    func linkTypeFromRaw() {
        #expect(LinkType(fromRaw: "supports") == .supports)
        #expect(LinkType(fromRaw: "SUPPORTS") == .supports)
        #expect(LinkType(fromRaw: "unknown") == .related)
        #expect(LinkType(fromRaw: "") == .related)
    }

    @Test("BacklinkGroup identity")
    func backlinkGroupId() {
        let group = BacklinkGroup(linkType: .supports, links: [])
        #expect(group.id == "supports")
    }
}
