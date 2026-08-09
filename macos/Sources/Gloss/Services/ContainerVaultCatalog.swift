import Foundation
import Observation

/// The production vault catalog: folders inside the iCloud container's
/// Documents ("iCloud Drive → Gloss") — every vault the Mac moved to iCloud
/// appears here on any device signed into the same Apple Account. In DEBUG
/// builds the app-sandbox Documents folders ride along so the simulator
/// (unsigned, no container) stays developable.
@Observable
@MainActor
final class ContainerVaultCatalog: VaultCatalogProviding {
    private let ubiquityStore: UbiquityVaultStore
    private(set) var vaults: [VaultDescriptor] = []

    init(ubiquityStore: UbiquityVaultStore) {
        self.ubiquityStore = ubiquityStore
    }

    func refresh() async {
        var found: [VaultDescriptor] = []
        if let documents = ubiquityStore.documentsURL {
            found += Self.vaultDescriptors(inDirectory: documents)
        }
        // iOS-simulator development only: unsigned sim builds have no
        // container, so sandbox Documents folders stand in. On macOS the
        // sandbox Documents dir is app-private noise — never list it.
        #if DEBUG && os(iOS)
        if let sandbox = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first {
            found += Self.vaultDescriptors(inDirectory: sandbox)
        }
        #endif
        var seen = Set<String>()
        vaults = found.filter { seen.insert($0.id).inserted }
    }

    /// Every visible directory in `directory`, as a vault row. Placeholder
    /// (not-yet-downloaded) folders still enumerate — iCloud materializes
    /// directory structure eagerly; only file contents are lazy.
    nonisolated static func vaultDescriptors(inDirectory directory: URL) -> [VaultDescriptor] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted {
                $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent)
                    == .orderedAscending
            }
            .map { url in
                let shelf = shelfInfo(for: url)
                return VaultDescriptor(
                    id: url.standardizedFileURL.path,
                    name: url.lastPathComponent,
                    rootURL: url,
                    noteCount: shelf.count,
                    updatedAt: shelf.updatedAt,
                    isInICloud: UbiquityVaultStore.isUbiquitousPath(url)
                )
            }
    }

    /// Markdown count + newest modification, with the standard exclusion set
    /// pruned (a dev-workspace vault must not walk node_modules). Capped so a
    /// pathological vault can't stall the shelf — the row shows "999+".
    nonisolated static func shelfInfo(for root: URL, cap: Int = 999) -> (count: Int?, updatedAt: Date?) {
        let excluded = ExclusionRules.standard
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return (nil, nil) }

        var count = 0
        var newest: Date?
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(
                forKeys: [.isDirectoryKey, .contentModificationDateKey])
            if values?.isDirectory == true {
                if excluded.isExcludedRelativePath(Substring(url.lastPathComponent)) {
                    enumerator.skipDescendants()
                }
                continue
            }
            let ext = url.pathExtension.lowercased()
            guard ext == "md" || ext == "markdown" else { continue }
            count += 1
            if let modified = values?.contentModificationDate {
                newest = newest.map { max($0, modified) } ?? modified
            }
            if count > cap {
                return (cap, newest)
            }
        }
        return (count, newest)
    }
}
