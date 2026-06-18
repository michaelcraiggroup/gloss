import Foundation
import Testing
@testable import Gloss

/// Behavioral tests for the FSEvents-backed folder watcher. These touch the
/// real file system and FSEvents, so they use generous timeouts to stay
/// reliable; the ~0.3s coalescing latency means events are not instantaneous.
@Suite("Folder Watcher")
struct FolderWatcherTests {

    /// Thread-safe sink for paths delivered by the watcher callback.
    actor PathCollector {
        private(set) var paths: [String] = []
        func add(_ new: [String]) { paths.append(contentsOf: new) }
        func contains(suffix: String) -> Bool { paths.contains { $0.hasSuffix(suffix) } }
    }

    @Test("Fires on file creation in the watched tree")
    func firesOnCreate() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-watch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let collector = PathCollector()
        let watcher = FolderWatcher()
        watcher.start(root: tmpDir) { paths in
            Task { await collector.add(paths) }
        }
        defer { watcher.stop() }

        // Let FSEvents arm before mutating.
        try await Task.sleep(nanoseconds: 300_000_000)
        try "hello".write(
            to: tmpDir.appendingPathComponent("new.md"),
            atomically: true, encoding: .utf8
        )

        // Poll up to ~6s for the coalesced event.
        var fired = false
        for _ in 0..<60 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if await collector.contains(suffix: "new.md") { fired = true; break }
        }
        #expect(fired, "watcher should report the created file")
    }

    @Test("Fires on changes in a nested subfolder")
    func firesOnNestedChange() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-watch-\(UUID().uuidString)")
        let subDir = tmpDir.appendingPathComponent("a/b")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let collector = PathCollector()
        let watcher = FolderWatcher()
        watcher.start(root: tmpDir) { paths in
            Task { await collector.add(paths) }
        }
        defer { watcher.stop() }

        try await Task.sleep(nanoseconds: 300_000_000)
        try "deep".write(
            to: subDir.appendingPathComponent("deep.md"),
            atomically: true, encoding: .utf8
        )

        var fired = false
        for _ in 0..<60 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if await collector.contains(suffix: "deep.md") { fired = true; break }
        }
        #expect(fired, "watcher should report changes in nested subfolders")
    }

    @Test("Delivers nothing after stop()")
    func stopHaltsDelivery() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-watch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let collector = PathCollector()
        let watcher = FolderWatcher()
        watcher.start(root: tmpDir) { paths in
            Task { await collector.add(paths) }
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        watcher.stop()

        try "x".write(
            to: tmpDir.appendingPathComponent("after-stop.md"),
            atomically: true, encoding: .utf8
        )
        try await Task.sleep(nanoseconds: 800_000_000)

        let sawIt = await collector.contains(suffix: "after-stop.md")
        #expect(!sawIt, "no events should arrive after stop()")
    }
}
