import Foundation
import Observation

/// A vault the app can offer to open. In milestone C's interim state these
/// come from the app-sandbox Documents folder; PR 9 replaces the catalog's
/// source with the iCloud container discovery query — same descriptor.
struct VaultDescriptor: Identifiable, Hashable {
    let id: String
    let name: String
    let rootURL: URL
}

/// Seam the vault-sync arc implements against the iCloud container (PR 9).
@MainActor
protocol VaultCatalogProviding: AnyObject, Observable {
    var vaults: [VaultDescriptor] { get }
    func refresh() async
}

/// Seam the pairing arc implements for `gloss://pair` URLs (PR 11).
@MainActor
protocol PairingURLHandling: AnyObject {
    func handle(_ url: URL)
}

/// Interim catalog until the ubiquity store lands: lists directories inside
/// the app-sandbox Documents folder, so the shell is developable in the
/// simulator today (drop a folder in via the Files app, or
/// `xcrun simctl` push). Harmless in release — the folder is simply empty.
@Observable
@MainActor
final class LocalVaultCatalog: VaultCatalogProviding {
    private(set) var vaults: [VaultDescriptor] = []

    func refresh() async {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            vaults = []
            return
        }
        let contents = (try? fm.contentsOfDirectory(
            at: docs,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        vaults = contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
            .map {
                VaultDescriptor(
                    id: $0.standardizedFileURL.path,
                    name: $0.lastPathComponent,
                    rootURL: $0
                )
            }
    }
}

/// Interim pairing handler until PR 11: records the last URL so the
/// `gloss://` route can be exercised end-to-end today
/// (`xcrun simctl openurl booted "gloss://pair?v=1&d=..."`).
@Observable
@MainActor
final class LoggingPairingHandler: PairingURLHandling {
    private(set) var lastReceived: URL?

    func handle(_ url: URL) {
        lastReceived = url
    }
}
