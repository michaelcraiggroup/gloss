import Foundation
import CryptoKit

/// Location policy for a vault's derived, per-device state (the link index).
///
/// Local vaults keep the in-vault `.gloss/` directory — it travels with the
/// folder and predates sync. Container vaults must NEVER host SQLite (a
/// database under file-sync corrupts on partial/concurrent replication), so
/// their index lives in Application Support, keyed by vault name + a path
/// hash, with a `meta.json` breadcrumb so a launch sweep can reap index
/// directories whose vault no longer exists.
enum VaultPaths {
    /// Where the link index database for `vaultRoot` lives.
    nonisolated static func indexDatabaseURL(for vaultRoot: URL) -> URL {
        if UbiquityVaultStore.isUbiquitousPath(vaultRoot) {
            return indexDirectory(for: vaultRoot)
                .appendingPathComponent("index.sqlite")
        }
        return vaultRoot
            .appendingPathComponent(".gloss")
            .appendingPathComponent("index.sqlite")
    }

    /// The per-vault directory under Application Support (container vaults).
    nonisolated static func indexDirectory(for vaultRoot: URL) -> URL {
        vaultIndexesBase().appendingPathComponent(indexKey(for: vaultRoot), isDirectory: true)
    }

    /// Stable, filesystem-safe identity: sanitized vault name + first 16 hex
    /// chars of the standardized path's SHA-256. Rename or move the vault and
    /// the key changes — the old directory is reaped by the sweep.
    nonisolated static func indexKey(for vaultRoot: URL) -> String {
        let standardized = vaultRoot.standardizedFileURL.path
        let digest = SHA256.hash(data: Data(standardized.utf8))
        let hex = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        let sanitized = vaultRoot.lastPathComponent
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
            .prefix(40)
        return "\(sanitized.isEmpty ? "vault" : String(sanitized))-\(hex)"
    }

    /// `<Application Support>/Gloss/VaultIndexes/` (inside the app sandbox
    /// container when sandboxed; the plain user directory in SPM dev builds).
    nonisolated static func vaultIndexesBase() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Gloss/VaultIndexes", isDirectory: true)
    }

    // MARK: - meta.json (sweep support)

    struct Meta: Codable {
        var vaultPath: String
        var updatedAt: String
    }

    /// Record which vault an index directory belongs to. Best-effort — a
    /// missing meta simply exempts the directory from sweeping.
    nonisolated static func writeMeta(for vaultRoot: URL) {
        let dir = indexDirectory(for: vaultRoot)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let meta = Meta(
            vaultPath: vaultRoot.standardizedFileURL.path,
            updatedAt: ISO8601DateFormatter().string(from: Date()))
        if let data = try? JSONEncoder().encode(meta) {
            try? data.write(to: dir.appendingPathComponent("meta.json"), options: .atomic)
        }
    }

    /// Remove index directories whose vault no longer exists on disk.
    /// Directories without a readable meta.json are left alone (safety).
    /// Returns the number of directories removed.
    @discardableResult
    nonisolated static func sweepStaleIndexDirectories(base: URL? = nil) -> Int {
        let baseURL = base ?? vaultIndexesBase()
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: baseURL, includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]) else { return 0 }
        var removed = 0
        for entry in entries {
            guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                  let data = try? Data(contentsOf: entry.appendingPathComponent("meta.json")),
                  let meta = try? JSONDecoder().decode(Meta.self, from: data)
            else { continue }
            if !fm.fileExists(atPath: meta.vaultPath) {
                try? fm.removeItem(at: entry)
                removed += 1
            }
        }
        return removed
    }
}
