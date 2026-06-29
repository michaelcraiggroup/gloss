import Foundation
import Testing
@testable import Gloss

@Suite("File Tree Refresh")
struct RefreshTests {

    @Test("Refresh detects externally deleted file")
    @MainActor
    func refreshDetectsDeletedFile() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Create a file, open folder
        let file = tmpDir.appendingPathComponent("to-delete.md")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        let model = FileTreeModel()
        model.openFolder(tmpDir)
        let initialCount = model.rootNode?.children?.count ?? 0
        #expect(initialCount == 1)

        // Delete externally
        try FileManager.default.removeItem(at: file)

        // Refresh should detect
        model.refreshAfterFileChange()
        let afterCount = model.rootNode?.children?.count ?? 0
        #expect(afterCount == 0)
    }

    @Test("Refresh updates after multiple file additions")
    @MainActor
    func refreshDetectsMultipleAdditions() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let model = FileTreeModel()
        model.openFolder(tmpDir)
        #expect(model.rootNode?.children?.count ?? 0 == 0)

        // Add 3 files externally
        for i in 1...3 {
            let file = tmpDir.appendingPathComponent("file\(i).md")
            try "content \(i)".write(to: file, atomically: true, encoding: .utf8)
        }

        model.refreshAfterFileChange()
        #expect(model.rootNode?.children?.count == 3)
    }

    @Test("Refresh is idempotent when no changes")
    @MainActor
    func refreshIdempotent() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let file = tmpDir.appendingPathComponent("stable.md")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        let model = FileTreeModel()
        model.openFolder(tmpDir)

        let count1 = model.rootNode?.children?.count
        model.refreshAfterFileChange()
        let count2 = model.rootNode?.children?.count
        model.refreshAfterFileChange()
        let count3 = model.rootNode?.children?.count

        #expect(count1 == count2)
        #expect(count2 == count3)
    }

    @Test("Refresh with no open folder does not crash")
    @MainActor
    func refreshNoFolder() {
        let model = FileTreeModel()
        // Should not crash
        model.refreshAfterFileChange()
        #expect(model.rootNode == nil)
    }

    @Test("Refresh with scoped node updates scoped view")
    @MainActor
    func refreshScopedNode() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        let subDir = tmpDir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let model = FileTreeModel()
        model.openFolder(tmpDir)

        // Scope into subfolder
        if let subNode = model.rootNode?.children?.first(where: { $0.isDirectory }) {
            model.scopeToFolder(subNode)
        }

        #expect(model.isScoped)

        // Add a file to the scoped folder
        let file = subDir.appendingPathComponent("scoped-file.md")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        model.refreshAfterFileChange()
        let scopedChildren = model.scopedNode?.children?.count ?? 0
        #expect(scopedChildren == 1)
    }

    @Test("hasFolder reflects folder state")
    @MainActor
    func hasFolderState() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let model = FileTreeModel()
        #expect(model.hasFolder == false)

        model.openFolder(tmpDir)
        #expect(model.hasFolder == true)

        model.closeFolder()
        #expect(model.hasFolder == false)
    }

    // MARK: - Recursive reconcile (folder-wide watching)

    @Test("Reconcile preserves expansion state of subfolders")
    @MainActor
    func reconcilePreservesExpansion() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        let subDir = tmpDir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        try "a".write(to: subDir.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)

        let model = FileTreeModel()
        model.openFolder(tmpDir)

        // Expand the subfolder in place.
        let subNode = try #require(model.rootNode?.children?.first(where: { $0.isDirectory }))
        subNode.loadChildren()
        subNode.isExpanded = true
        let subNodeID = subNode.id

        // Add a file at the root — a membership change at the top level.
        try "r".write(to: tmpDir.appendingPathComponent("root.md"), atomically: true, encoding: .utf8)
        model.refreshAfterFileChange()

        // The subfolder node is the same instance and is still expanded/loaded.
        let preserved = model.rootNode?.children?.first(where: { $0.id == subNodeID })
        #expect(preserved != nil)
        #expect(preserved?.isExpanded == true)
        #expect(preserved?.children?.count == 1)
        // Root now holds the new file plus the subfolder.
        #expect(model.rootNode?.children?.count == 2)
    }

    @Test("Reconcile detects additions in an expanded subfolder")
    @MainActor
    func reconcileNestedAddition() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        let subDir = tmpDir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let model = FileTreeModel()
        model.openFolder(tmpDir)
        let subNode = try #require(model.rootNode?.children?.first(where: { $0.isDirectory }))
        subNode.loadChildren()
        subNode.isExpanded = true
        #expect(subNode.children?.count == 0)

        // Add a file inside the expanded subfolder — the old shallow refresh missed this.
        try "n".write(to: subDir.appendingPathComponent("nested.md"), atomically: true, encoding: .utf8)
        model.refreshAfterFileChange()

        #expect(subNode.children?.count == 1)
    }

    @Test("Reconcile detects deletions in an expanded subfolder")
    @MainActor
    func reconcileNestedDeletion() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        let subDir = tmpDir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }
        let nested = subDir.appendingPathComponent("nested.md")
        try "n".write(to: nested, atomically: true, encoding: .utf8)

        let model = FileTreeModel()
        model.openFolder(tmpDir)
        let subNode = try #require(model.rootNode?.children?.first(where: { $0.isDirectory }))
        subNode.loadChildren()
        subNode.isExpanded = true
        #expect(subNode.children?.count == 1)

        try FileManager.default.removeItem(at: nested)
        model.refreshAfterFileChange()

        #expect(subNode.children?.count == 0)
    }

    @Test("Reconcile leaves unexpanded subfolders lazy")
    @MainActor
    func reconcileLeavesUnexpandedFoldersLazy() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        let subDir = tmpDir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let model = FileTreeModel()
        model.openFolder(tmpDir)
        let subNode = try #require(model.rootNode?.children?.first(where: { $0.isDirectory }))
        #expect(subNode.children == nil) // never expanded

        // Adding inside an unexpanded folder must not force it to load.
        try "n".write(to: subDir.appendingPathComponent("nested.md"), atomically: true, encoding: .utf8)
        model.refreshAfterFileChange()

        #expect(subNode.children == nil)
    }

    @Test("Reconcile rebuilds a node when its path flips file<->directory")
    @MainActor
    func reconcileTypeFlip() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let path = tmpDir.appendingPathComponent("notes.md")
        try "hi".write(to: path, atomically: true, encoding: .utf8)

        let model = FileTreeModel()
        model.openFolder(tmpDir)
        let fileNode = try #require(model.rootNode?.children?.first)
        #expect(fileNode.isDirectory == false)

        // Externally replace the file with a directory of the same name.
        try FileManager.default.removeItem(at: path)
        try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        model.refreshAfterFileChange()

        // The node must be rebuilt as a directory, not reuse the stale file node.
        let flipped = try #require(model.rootNode?.children?.first)
        #expect(flipped.isDirectory == true)
    }

    @Test("Scoped folder externally deleted clears scopedNode")
    @MainActor
    func scopedFolderDeletedExternally() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        let subDir = tmpDir.appendingPathComponent("sub")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let model = FileTreeModel()
        model.openFolder(tmpDir)
        let subNode = try #require(model.rootNode?.children?.first(where: { $0.isDirectory }))
        model.scopeToFolder(subNode)
        #expect(model.isScoped)

        try FileManager.default.removeItem(at: subDir)
        model.refreshAfterFileChange()

        #expect(model.scopedNode == nil)
        #expect(!model.isScoped)
    }

    @Test("Reconcile updates modificationDate after external edit")
    @MainActor
    func reconcileUpdatesModificationDate() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let file = tmpDir.appendingPathComponent("editable.md")
        try "v1".write(to: file, atomically: true, encoding: .utf8)

        let model = FileTreeModel()
        model.openFolder(tmpDir)
        let node = try #require(model.rootNode?.children?.first)
        let before = node.modificationDate

        // Small pause so APFS records a different nanosecond-precision mtime.
        try await Task.sleep(for: .milliseconds(20))
        try "v2".write(to: file, atomically: true, encoding: .utf8)
        model.refreshAfterFileChange()

        #expect(node.modificationDate != before)
    }
}
