import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// The vault, answering from system search — every indexed note becomes a
/// Core Spotlight item (title + snippet + full text), so ⌘Space on the Mac
/// and the iOS search screen find notes and deep-link straight into the
/// reader, app closed or not.
///
/// Privacy: Spotlight's index is **on-device** — nothing leaves the machine,
/// consistent with the no-telemetry architecture.
///
/// Writes ride the existing LinkIndex pipeline (the only place file content
/// is already in hand), so Spotlight stays in lockstep with the link index:
/// indexed on build/save, removed on delete/stale-sweep, domain-purged when
/// a vault migrates. All CSSearchableIndex calls are async and thread-safe;
/// callers are the off-main index workers.
enum SpotlightIndexer {
    nonisolated static var isAvailable: Bool {
        CSSearchableIndex.isIndexingAvailable()
    }

    /// One domain per vault (resolved root path) — lets a migration purge
    /// its old identity in a single call.
    nonisolated static func domain(forVaultRoot root: URL) -> String {
        root.resolvingSymlinksInPath().path
    }

    // MARK: - Writes (called from the LinkIndex pipeline, off-main)

    nonisolated static func upsert(
        path: String, title: String, content: String, vaultRoot: URL
    ) {
        guard isAvailable else { return }
        let attributes = CSSearchableItemAttributeSet(contentType: .plainText)
        attributes.title = title
        attributes.contentDescription = snippet(from: content)
        attributes.textContent = content
        let item = CSSearchableItem(
            uniqueIdentifier: path,
            domainIdentifier: domain(forVaultRoot: vaultRoot),
            attributeSet: attributes)
        // Notes don't expire — without this, items silently vanish from
        // Spotlight after the system's default ~30-day window.
        item.expirationDate = .distantFuture
        CSSearchableIndex.default().indexSearchableItems([item])
    }

    nonisolated static func remove(paths: [String]) {
        guard isAvailable, !paths.isEmpty else { return }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: paths)
    }

    nonisolated static func purgeVault(root: URL) {
        guard isAvailable else { return }
        CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: [domain(forVaultRoot: root)])
    }

    // MARK: - Pure helpers (unit-tested)

    /// First meaningful prose line — frontmatter, headings, blanks, and
    /// markdown list/quote furniture skipped — capped for the result card.
    nonisolated static func snippet(from content: String, limit: Int = 160) -> String {
        var body = Substring(content)
        // Skip a leading frontmatter block wholesale.
        if body.hasPrefix("---") {
            if let close = body.dropFirst(3).range(of: "\n---") {
                body = body[close.upperBound...]
            }
        }
        for rawLine in body.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let cleaned = line
                .trimmingCharacters(in: CharacterSet(charactersIn: ">-*+ \t"))
            guard !cleaned.isEmpty else { continue }
            return String(cleaned.prefix(limit))
        }
        return ""
    }

    /// The vault root a Spotlight-continued note path belongs to, for when
    /// the tapped note's vault isn't the open one: container paths parse to
    /// `<container>/Documents/<vault>`; anything else is unknown (the caller
    /// falls back to the open vault or a standalone open).
    nonisolated static func vaultRoot(forNotePath path: String) -> URL? {
        let marker = "Mobile Documents/iCloud~group~michaelcraig~gloss/Documents/"
        guard let markerRange = path.range(of: marker) else { return nil }
        let afterDocuments = path[markerRange.upperBound...]
        guard let vaultName = afterDocuments.split(separator: "/").first,
              !vaultName.isEmpty else { return nil }
        let rootPath = String(path[..<markerRange.upperBound]) + vaultName
        return URL(fileURLWithPath: rootPath, isDirectory: true)
    }
}
