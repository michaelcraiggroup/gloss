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
}
