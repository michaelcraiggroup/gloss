import Foundation
import Testing
@testable import Gloss

@Suite("File Operations")
struct FileOperationsTests {

    @Test("Create file in directory")
    @MainActor
    func createFile() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let model = FileTreeModel()
        model.openFolder(tmpDir)

        let url = model.createFile(named: "test-note", in: tmpDir)
        #expect(url != nil)
        #expect(url!.lastPathComponent == "test-note.md")
        #expect(FileManager.default.fileExists(atPath: url!.path))
    }

    @Test("Create file adds .md extension")
    @MainActor
    func createFileAddsExtension() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let model = FileTreeModel()
        let url = model.createFile(named: "my-note", in: tmpDir)
        #expect(url?.lastPathComponent == "my-note.md")
    }

    @Test("Create file preserves existing .md extension")
    @MainActor
    func createFilePreservesExtension() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let model = FileTreeModel()
        let url = model.createFile(named: "existing.md", in: tmpDir)
        #expect(url?.lastPathComponent == "existing.md")
    }

    @Test("Create file preserves .markdown extension")
    @MainActor
    func createFilePreservesMarkdownExtension() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let model = FileTreeModel()
        let url = model.createFile(named: "note.markdown", in: tmpDir)
        #expect(url?.lastPathComponent == "note.markdown")
    }

    @Test("Create file with empty name returns nil")
    @MainActor
    func createFileEmptyName() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let model = FileTreeModel()
        let url = model.createFile(named: "  ", in: tmpDir)
        #expect(url == nil)
    }

    @Test("Create file rejects duplicate name")
    @MainActor
    func createFileDuplicate() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let model = FileTreeModel()
        _ = model.createFile(named: "dup", in: tmpDir)
        let second = model.createFile(named: "dup", in: tmpDir)
        #expect(second == nil)
    }

    @Test("Rename file")
    @MainActor
    func renameFile() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let model = FileTreeModel()
        model.openFolder(tmpDir)

        let original = tmpDir.appendingPathComponent("original.md")
        try "content".write(to: original, atomically: true, encoding: .utf8)

        let newURL = model.renameItem(at: original, to: "renamed.md")
        #expect(newURL != nil)
        #expect(newURL!.lastPathComponent == "renamed.md")
        #expect(!FileManager.default.fileExists(atPath: original.path))
        #expect(FileManager.default.fileExists(atPath: newURL!.path))
    }

    @Test("Rename to same name returns nil")
    @MainActor
    func renameSameName() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let model = FileTreeModel()
        let file = tmpDir.appendingPathComponent("same.md")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        let result = model.renameItem(at: file, to: "same.md")
        #expect(result == nil)
    }

    @Test("Rename rejects empty name")
    @MainActor
    func renameEmptyName() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let model = FileTreeModel()
        let file = tmpDir.appendingPathComponent("test.md")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        let result = model.renameItem(at: file, to: "   ")
        #expect(result == nil)
    }

    @Test("Delete file moves to trash")
    @MainActor
    func deleteFile() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let model = FileTreeModel()
        model.openFolder(tmpDir)

        let file = tmpDir.appendingPathComponent("delete-me.md")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        let result = model.deleteItem(at: file)
        #expect(result == true)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test("Refresh after file change detects new file")
    @MainActor
    func refreshDetectsNewFile() throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let model = FileTreeModel()
        model.openFolder(tmpDir)

        let initialCount = model.rootNode?.children?.count ?? 0

        // Create a file externally
        let file = tmpDir.appendingPathComponent("new-file.md")
        try "content".write(to: file, atomically: true, encoding: .utf8)

        model.refreshAfterFileChange()

        let newCount = model.rootNode?.children?.count ?? 0
        #expect(newCount == initialCount + 1)
    }
}
