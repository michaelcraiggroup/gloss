import Foundation
import Observation

/// A vault the app can offer to open, with the shelf metadata that makes the
/// list read as a library rather than a file picker. Counts are optional —
/// rows render immediately and fill in as the catalog's scan completes.
/// Shared by the iOS vault list and the macOS no-vault sidebar library.
struct VaultDescriptor: Identifiable, Hashable {
    let id: String
    let name: String
    let rootURL: URL
    var noteCount: Int?
    var updatedAt: Date?
    var isInICloud: Bool = false

    /// "N notes · Updated <relative>" — the shelf metadata line, shared by
    /// the iOS vault list and the macOS sidebar library. Manual pluralization:
    /// inflection markup doesn't inflect through a plain String.
    var shelfLine: String? {
        var parts: [String] = []
        if let noteCount {
            parts.append(
                noteCount >= 999 ? "999+ notes" : noteCount == 1 ? "1 note" : "\(noteCount) notes")
        }
        if let updatedAt {
            parts.append("Updated \(updatedAt.formatted(.relative(presentation: .named)))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

/// Seam the vault-sync arc implements against the iCloud container (PR 9).
@MainActor
protocol VaultCatalogProviding: AnyObject, Observable {
    var vaults: [VaultDescriptor] { get }
    func refresh() async
}
