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
        #if DEBUG
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
            .map {
                VaultDescriptor(
                    id: $0.standardizedFileURL.path,
                    name: $0.lastPathComponent,
                    rootURL: $0
                )
            }
    }
}
