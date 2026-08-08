import Foundation
import Observation

/// A vault the app can offer to open, with the shelf metadata that makes the
/// list read as a library rather than a file picker. Counts are optional —
/// rows render immediately and fill in as the catalog's scan completes.
struct VaultDescriptor: Identifiable, Hashable {
    let id: String
    let name: String
    let rootURL: URL
    var noteCount: Int?
    var updatedAt: Date?
    var isInICloud: Bool = false
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

// The production conformer is PairingHandler (PairingHandler.swift) — the
// QR/deep-link state machine that consumes PairingEngine's decisions.
