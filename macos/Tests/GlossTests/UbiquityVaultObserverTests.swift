import Foundation
import Testing
@testable import Gloss

@Suite("UbiquityVaultObserver")
struct UbiquityVaultObserverTests {
    @Test func nonContainerRootRefusesToStart() throws {
        // Sandbox-local vaults have no ubiquitous metadata — start() must
        // return false so FileTreeModel keeps the per-file fallback engaged.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-ubiq-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let observer = UbiquityVaultObserver()
        let started = observer.start(root: dir, rules: .standard) { _ in }
        #expect(!started)
        observer.stop()
    }

    @Test func pathFilteringMatchesFolderWatcherSemantics() {
        let root = "/Users/x/Library/Mobile Documents/iCloud~group~michaelcraig~gloss/Documents/Vault"
        let paths = [
            root + "/note.md",
            root + "/.gloss/index.sqlite",          // always excluded
            root + "/node_modules/dep/readme.md",   // excluded subtree
            root + "/sub/inner.md",
            "/somewhere/else/outside.md",           // outside root — inspected whole, passes
        ]
        let filtered = UbiquityVaultObserver.vaultRelevantPaths(
            paths, rootPath: root, rules: .standard)
        #expect(filtered == [
            root + "/note.md",
            root + "/sub/inner.md",
            "/somewhere/else/outside.md",
        ])
    }

    @Test func excludedNameInRootPrefixStillWorks() {
        // Vault living under an excluded-name ancestor (e.g. .../build/Vault)
        // must not filter its own contents — only components BELOW the root
        // are inspected (FolderWatcher parity).
        let root = "/Users/x/build/Vault"
        let filtered = UbiquityVaultObserver.vaultRelevantPaths(
            [root + "/note.md"], rootPath: root, rules: .standard)
        #expect(filtered == [root + "/note.md"])
    }

    @Test func eagerDownloadWantsUndownloadedMarkdownOnly() {
        let current = NSMetadataUbiquitousItemDownloadingStatusCurrent
        #expect(UbiquityVaultObserver.wantsEagerDownload(path: "/v/a.md", downloadStatus: nil))
        #expect(UbiquityVaultObserver.wantsEagerDownload(
            path: "/v/b.markdown", downloadStatus: NSMetadataUbiquitousItemDownloadingStatusNotDownloaded))
        #expect(!UbiquityVaultObserver.wantsEagerDownload(path: "/v/a.md", downloadStatus: current))
        #expect(!UbiquityVaultObserver.wantsEagerDownload(path: "/v/image.png", downloadStatus: nil))
        #expect(!UbiquityVaultObserver.wantsEagerDownload(path: "/v/dir", downloadStatus: nil))
    }
}
