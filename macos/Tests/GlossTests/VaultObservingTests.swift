import Foundation
import Testing
@testable import Gloss

/// Spy conformer that records calls and hands back the onChange closure so
/// tests can drive the pipeline without a real file-system watcher.
final class SpyVaultObserver: VaultObserving, @unchecked Sendable {
    private(set) var startRoots: [URL] = []
    private(set) var stopCount = 0
    var startReturns = true
    private(set) var capturedOnChange: (@Sendable ([String]) -> Void)?

    @discardableResult
    func start(
        root: URL,
        rules: ExclusionRules,
        onChange: @escaping @Sendable ([String]) -> Void
    ) -> Bool {
        startRoots.append(root)
        capturedOnChange = onChange
        return startReturns
    }

    func stop() { stopCount += 1 }
}

@Suite("VaultObserving seam")
@MainActor
struct VaultObservingTests {
    private func makeTempVault() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-observing-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try "# Note\n".write(
            to: dir.appendingPathComponent("note.md"), atomically: true, encoding: .utf8)
        return dir
    }

    @Test func openFolderStartsInjectedObserverAndMirrorsResult() throws {
        let dir = try makeTempVault()
        defer { try? FileManager.default.removeItem(at: dir) }
        let spy = SpyVaultObserver()
        let model = FileTreeModel(vaultObserver: spy)

        model.openFolder(dir)
        #expect(spy.startRoots == [dir])
        #expect(model.isWatching)

        model.closeFolder()
        #expect(spy.stopCount == 1)
        #expect(!model.isWatching)
    }

    @Test func failedObserverStartLeavesWatchingFalse() throws {
        let dir = try makeTempVault()
        defer { try? FileManager.default.removeItem(at: dir) }
        let spy = SpyVaultObserver()
        spy.startReturns = false
        let model = FileTreeModel(vaultObserver: spy)

        model.openFolder(dir)
        // DocumentView reads isWatching to keep the per-file fallback engaged.
        #expect(!model.isWatching)
        model.closeFolder()
    }

    @Test func nullObserverNeverWatches() throws {
        let dir = try makeTempVault()
        defer { try? FileManager.default.removeItem(at: dir) }
        let model = FileTreeModel(vaultObserver: NullVaultObserver())

        model.openFolder(dir)
        #expect(!model.isWatching)
        model.closeFolder()
    }

    @Test func observerEventsFlowThroughDebouncerToNotification() async throws {
        let dir = try makeTempVault()
        defer { try? FileManager.default.removeItem(at: dir) }
        let spy = SpyVaultObserver()
        let model = FileTreeModel(vaultObserver: spy)
        model.openFolder(dir)
        defer { model.closeFolder() }

        let changed = dir.appendingPathComponent("note.md").path
        try await confirmation("debounced .glossVaultFilesChanged arrives") { confirm in
            let observer = NotificationCenter.default.addObserver(
                forName: .glossVaultFilesChanged, object: nil, queue: .main
            ) { note in
                if (note.object as? [String]) == [changed] { confirm() }
            }
            defer { NotificationCenter.default.removeObserver(observer) }

            // Contract: delivery on the main queue — we are @MainActor.
            spy.capturedOnChange?([changed])
            // VaultEventDebouncer quiet interval is 400ms; leave headroom.
            try await Task.sleep(for: .milliseconds(1500))
        }
    }
}
