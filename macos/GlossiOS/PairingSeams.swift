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
