import Foundation
import Testing
@testable import Gloss

@Suite("FileTreeNode")
@MainActor
struct FileTreeNodeTests {

    /// Creates a temporary directory structure for testing.
    private func makeTempTree() throws -> URL {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("GlossTest-\(UUID().uuidString)")
        let fm = FileManager.default

        // Create structure:
        // root/
        //   README.md
        //   notes.md
        //   pitches/
        //     cool-idea.md
        //   .hidden-dir/
        //     secret.md
        //   node_modules/
        //     junk.md
        //   image.png

        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
        try "# README".write(to: tmp.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
        try "notes".write(to: tmp.appendingPathComponent("notes.md"), atomically: true, encoding: .utf8)
        try "".write(to: tmp.appendingPathComponent("image.png"), atomically: true, encoding: .utf8)

        let pitches = tmp.appendingPathComponent("pitches")
        try fm.createDirectory(at: pitches, withIntermediateDirectories: true)
        try "pitch".write(to: pitches.appendingPathComponent("cool-idea.md"), atomically: true, encoding: .utf8)

        let hidden = tmp.appendingPathComponent(".hidden-dir")
        try fm.createDirectory(at: hidden, withIntermediateDirectories: true)
        try "secret".write(to: hidden.appendingPathComponent("secret.md"), atomically: true, encoding: .utf8)

        let nodeModules = tmp.appendingPathComponent("node_modules")
        try fm.createDirectory(at: nodeModules, withIntermediateDirectories: true)
        try "junk".write(to: nodeModules.appendingPathComponent("junk.md"), atomically: true, encoding: .utf8)

        return tmp
    }

    private func cleanupTempTree(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test("Loads children with correct count")
    func loadChildren() throws {
        let root = try makeTempTree()
        defer { cleanupTempTree(root) }

        let node = FileTreeNode(url: root, isDirectory: true)
        node.loadChildren()

        // Should include: pitches/ dir, README.md, notes.md
        // Should exclude: .hidden-dir, node_modules, image.png
        #expect(node.children?.count == 3)
    }

    @Test("Directories sort before files")
    func sortOrder() throws {
        let root = try makeTempTree()
        defer { cleanupTempTree(root) }

        let node = FileTreeNode(url: root, isDirectory: true)
        node.loadChildren()

        guard let first = node.children?.first else {
            Issue.record("No children loaded")
            return
        }
        #expect(first.isDirectory)
        #expect(first.name == "pitches")
    }

    @Test("Excludes hidden files and node_modules")
    func excludes() throws {
        let root = try makeTempTree()
        defer { cleanupTempTree(root) }

        let node = FileTreeNode(url: root, isDirectory: true)
        node.loadChildren()

        let names = node.children?.map(\.name) ?? []
        #expect(!names.contains(".hidden-dir"))
        #expect(!names.contains("node_modules"))
        #expect(!names.contains("image.png"))
    }

    @Test("Detects document type from parent folder")
    func documentTypeFromFolder() throws {
        let root = try makeTempTree()
        defer { cleanupTempTree(root) }

        let node = FileTreeNode(url: root, isDirectory: true)
        node.loadChildren()

        // Expand the pitches folder
        let pitchesNode = node.children?.first { $0.name == "pitches" }
        pitchesNode?.loadChildren()

        let pitchFile = pitchesNode?.children?.first
        #expect(pitchFile?.documentType == .pitch)
    }

    @Test("Toggle expands and loads children")
    func toggle() throws {
        let root = try makeTempTree()
        defer { cleanupTempTree(root) }

        let node = FileTreeNode(url: root, isDirectory: true)
        #expect(node.children == nil)
        #expect(!node.isExpanded)

        node.toggle()
        #expect(node.isExpanded)
        #expect(node.children != nil)

        node.toggle()
        #expect(!node.isExpanded)
    }

    @Test("Non-directory loadChildren is no-op")
    func fileNodeNoChildren() {
        let url = URL(fileURLWithPath: "/tmp/test.md")
        let node = FileTreeNode(url: url, isDirectory: false)
        node.loadChildren()
        #expect(node.children == nil)
    }

    @Test("Directory node has folder document type")
    func directoryType() {
        let url = URL(fileURLWithPath: "/tmp/docs")
        let node = FileTreeNode(url: url, isDirectory: true)
        #expect(node.documentType == .folder)
    }
}
