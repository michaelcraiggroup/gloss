import Foundation
import Testing
@testable import Gloss

/// First-ever coverage for the read/render pipeline semantics that lived as
/// view-private helpers in DocumentView: candidate generation, the
/// same-directory-then-index resolution order, snapshot building (type/label
/// stripping, lowercased dedupe, unresolved tracking), embed heading split,
/// and the instance model's cancellation + identical-HTML short-circuit.
@Suite("DocumentRenderModel")
@MainActor
struct DocumentRenderModelTests {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-render-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Candidates

    @Test func candidatesForBareTargetTryExtensionsThenLiteral() {
        #expect(DocumentRenderModel.wikiLinkCandidates(for: "Ideas") ==
                ["Ideas.md", "Ideas.markdown", "Ideas"])
    }

    @Test func candidatesForExplicitExtensionPassThrough() {
        #expect(DocumentRenderModel.wikiLinkCandidates(for: "Ideas.md") == ["Ideas.md"])
        #expect(DocumentRenderModel.wikiLinkCandidates(for: "Ideas.markdown") == ["Ideas.markdown"])
    }

    // MARK: - Resolution order

    @Test func sameDirectoryBeatsIndex() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let local = dir.appendingPathComponent("Target.md")
        try "# local".write(to: local, atomically: true, encoding: .utf8)

        // Index knows a DIFFERENT path for the same title — same-dir must win.
        let db = try LinkDatabase()
        _ = try db.upsertFile(path: "/elsewhere/Target.md", title: "Target", modifiedAt: Date())

        let resolved = DocumentRenderModel.resolveWikiLink(
            "Target", from: dir.appendingPathComponent("Note.md"), database: db)
        #expect(resolved == local.absoluteString)
    }

    @Test func indexFallbackWhenNotInDirectory() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let db = try LinkDatabase()
        _ = try db.upsertFile(path: "/vault/deep/Elsewhere.md", title: "Elsewhere", modifiedAt: Date())

        let resolved = DocumentRenderModel.resolveWikiLink(
            "Elsewhere", from: dir.appendingPathComponent("Note.md"), database: db)
        #expect(resolved == URL(fileURLWithPath: "/vault/deep/Elsewhere.md").absoluteString)

        // Explicit extension is stripped before the title lookup.
        let resolvedWithExt = DocumentRenderModel.resolveWikiLink(
            "Elsewhere.md", from: dir.appendingPathComponent("Note.md"), database: db)
        #expect(resolvedWithExt == URL(fileURLWithPath: "/vault/deep/Elsewhere.md").absoluteString)
    }

    @Test func unresolvableReturnsNil() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let resolved = DocumentRenderModel.resolveWikiLink(
            "Nowhere", from: dir.appendingPathComponent("Note.md"), database: nil)
        #expect(resolved == nil)
    }

    // MARK: - Wiki snapshot

    @Test func snapshotStripsTypesAndLabelsAndTracksUnresolved() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try "# a".write(to: dir.appendingPathComponent("Alpha.md"), atomically: true, encoding: .utf8)

        let content = """
        Links: [[Alpha::supports]] and [[alpha|The First]] again,
        plus [[Missing Note]].
        """
        let (map, unresolved) = DocumentRenderModel.buildWikiLinkSnapshot(
            for: content, from: dir.appendingPathComponent("Note.md"), database: nil)

        // One lowercased key per target; type/label stripped before resolution.
        #expect(map.count == 1)
        #expect(map["alpha"] == dir.appendingPathComponent("Alpha.md").absoluteString)
        #expect(unresolved == ["missing note"])
    }

    @Test func snapshotIsEmptyWithoutWikiLinks() {
        let (map, unresolved) = DocumentRenderModel.buildWikiLinkSnapshot(
            for: "no links here", from: URL(fileURLWithPath: "/tmp/x.md"), database: nil)
        #expect(map.isEmpty)
        #expect(unresolved.isEmpty)
    }

    // MARK: - Embed snapshot

    @Test func embedSnapshotSplitsHeadingAndResolves() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        try "# doc".write(to: dir.appendingPathComponent("Embedded.md"), atomically: true, encoding: .utf8)

        let map = DocumentRenderModel.buildEmbedSnapshot(
            for: "Intro ![[Embedded#Section Two]] outro",
            from: dir.appendingPathComponent("Note.md"),
            database: nil)
        #expect(map["embedded"] == dir.appendingPathComponent("Embedded.md"))
    }

    // MARK: - Instance model

    @Test func loadReadsFileAndPublishesContent() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("Doc.md")
        try "# Hello".write(to: file, atomically: true, encoding: .utf8)

        let model = DocumentRenderModel()
        #expect(model.load(url: file))
        #expect(model.fileContent == "# Hello")
        #expect(!model.load(url: dir.appendingPathComponent("missing.md")))
        #expect(model.fileContent == nil)
    }

    @Test func renderPublishesHTMLAndClearsRenderingFlag() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("Doc.md")
        let model = DocumentRenderModel()

        await model.render("# Title\n\nBody.", url: url, isDark: false, fontSize: 16).value
        #expect(model.renderedHTML?.contains("<h1") == true)
        #expect(model.renderURL == url)
        #expect(!model.isRendering)
    }

    @Test func identicalRenderShortCircuitKeepsHTMLInstance() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("Doc.md")
        let model = DocumentRenderModel()

        await model.render("# Same", url: url, isDark: true, fontSize: 16).value
        let first = model.renderedHTML
        #expect(first != nil)

        // Identical content → identical HTML → renderedHTML must not be
        // re-assigned (the WebView reloads only on actual change; #40).
        let second = dir.appendingPathComponent("Other.md")
        await model.render("# Same", url: second, isDark: true, fontSize: 16).value
        #expect(model.renderedHTML == first)
        #expect(model.renderURL == second)
        #expect(!model.isRendering)
    }

    @Test func cancelStopsInFlightRenderWithoutPublishing() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("Doc.md")
        let model = DocumentRenderModel()

        let big = String(repeating: "## Section\n\ntext *emphasis* `code`\n\n", count: 4000)
        let task = model.render(big, url: url, isDark: false, fontSize: 16)
        model.cancel()
        await task.value
        #expect(model.renderedHTML == nil)
        #expect(model.renderURL == nil)
        #expect(!model.isRendering)
    }

    // MARK: - Wiki href scheme (iOS file-sandbox workaround)

    @Test func wikiHrefRoundtripsHostilePaths() {
        // The device case: spaces, tildes, and query-breaking characters.
        let path = "/var/mobile/Library/Mobile Documents/iCloud~group~michaelcraig~gloss/Documents/Vault/Notes & Ideas/Q?.md"
        let href = DocumentRenderModel.wikiHref(
            forFileURLString: URL(fileURLWithPath: path).absoluteString)
        #expect(href.hasPrefix("glosswiki://open?path="))
        #expect(!href.contains(" "))
        let back = DocumentRenderModel.fileURL(fromWikiHref: URL(string: href)!)
        #expect(back?.path == path)
    }

    @Test func wikiHrefDecodeRejectsForeignAndRelative() {
        #expect(DocumentRenderModel.fileURL(
            fromWikiHref: URL(string: "https://example.com/?path=/x.md")!) == nil)
        #expect(DocumentRenderModel.fileURL(
            fromWikiHref: URL(string: "glosswiki://open?path=relative/x.md")!) == nil)
        #expect(DocumentRenderModel.fileURL(
            fromWikiHref: URL(string: "glosswiki://open")!) == nil)
        // Non-file input passes through encode untouched (defensive no-op).
        #expect(DocumentRenderModel.wikiHref(forFileURLString: "not a url") == "not a url")
    }
}
