import Foundation
import Testing
@testable import Gloss

@Suite("VaultPaths")
struct VaultPathsTests {
    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gloss-paths-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Location policy

    @Test func localVaultKeepsInVaultIndex() {
        let root = URL(fileURLWithPath: "/Users/x/Notes")
        let url = VaultPaths.indexDatabaseURL(for: root)
        #expect(url.path == "/Users/x/Notes/.gloss/index.sqlite")
    }

    @Test func containerVaultRelocatesToApplicationSupport() {
        let root = URL(fileURLWithPath:
            "/Users/x/Library/Mobile Documents/iCloud~group~michaelcraig~gloss/Documents/Notes")
        let url = VaultPaths.indexDatabaseURL(for: root)
        // The load-bearing assertions: never inside the container, always
        // under the VaultIndexes base, keyed by the vault.
        #expect(!url.path.contains("Mobile Documents"))
        #expect(url.path.hasPrefix(VaultPaths.vaultIndexesBase().path))
        #expect(url.lastPathComponent == "index.sqlite")
        #expect(url.deletingLastPathComponent().lastPathComponent
            == VaultPaths.indexKey(for: root))
    }

    // MARK: - Keys

    @Test func indexKeyIsStableAndPathSensitive() {
        let a = URL(fileURLWithPath:
            "/Users/x/Library/Mobile Documents/iCloud~group~michaelcraig~gloss/Documents/Notes")
        let b = URL(fileURLWithPath:
            "/Users/x/Library/Mobile Documents/iCloud~group~michaelcraig~gloss/Documents/Other")
        #expect(VaultPaths.indexKey(for: a) == VaultPaths.indexKey(for: a))
        #expect(VaultPaths.indexKey(for: a) != VaultPaths.indexKey(for: b))
        #expect(VaultPaths.indexKey(for: a).hasPrefix("Notes-"))
    }

    @Test func indexKeySanitizesHostileNames() {
        let root = URL(fileURLWithPath: "/vaults/Naïve Résumé — überdraft 🚀")
        let key = VaultPaths.indexKey(for: root)
        #expect(!key.contains(" "))
        #expect(!key.contains("/"))
        #expect(key.count <= 60)
        // Pure-symbol names fall back to a stable placeholder.
        let symbols = URL(fileURLWithPath: "/vaults/€€€")
        #expect(VaultPaths.indexKey(for: symbols).hasPrefix("vault-"))
    }

    // MARK: - meta.json + sweep

    @Test func sweepRemovesOrphansKeepsLiveAndUnmarked() throws {
        let base = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: base) }
        let liveVault = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: liveVault) }

        let fm = FileManager.default
        func plantIndexDir(_ name: String, vaultPath: String?) throws -> URL {
            let dir = base.appendingPathComponent(name, isDirectory: true)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            if let vaultPath {
                let meta = VaultPaths.Meta(vaultPath: vaultPath, updatedAt: "2026-08-08T00:00:00Z")
                try JSONEncoder().encode(meta).write(to: dir.appendingPathComponent("meta.json"))
            }
            return dir
        }

        let live = try plantIndexDir("live-aaaa", vaultPath: liveVault.path)
        let orphan = try plantIndexDir("orphan-bbbb", vaultPath: liveVault.path + "-gone")
        let unmarked = try plantIndexDir("unmarked-cccc", vaultPath: nil)

        let removed = VaultPaths.sweepStaleIndexDirectories(base: base)
        #expect(removed == 1)
        #expect(fm.fileExists(atPath: live.path))
        #expect(!fm.fileExists(atPath: orphan.path))
        // No meta.json → exempt (safety: never guess-delete).
        #expect(fm.fileExists(atPath: unmarked.path))
    }

    // MARK: - LinkDatabase integration

    @Test func explicitDatabaseURLOpensAnywhere() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let dbURL = dir.appendingPathComponent("nested/custom.sqlite")
        let db = try LinkDatabase(databaseURL: dbURL)
        _ = try db.upsertFile(path: "/x/a.md", title: "a", modifiedAt: Date())
        #expect(FileManager.default.fileExists(atPath: dbURL.path))
    }

    @Test func localRootInitBehaviorUnchanged() throws {
        let vault = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: vault) }
        _ = try LinkDatabase(rootURL: vault)
        #expect(FileManager.default.fileExists(
            atPath: vault.appendingPathComponent(".gloss/index.sqlite").path))
    }

    // MARK: - Dataless guard

    @Test func regularFilesAreNeverDataless() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("a.md")
        try "# a".write(to: file, atomically: true, encoding: .utf8)
        #expect(!LinkIndex.isDatalessUbiquitousFile(file))
    }
}
