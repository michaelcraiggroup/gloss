import Foundation

/// Persists security-scoped bookmarks so the **sandboxed** release build can
/// re-read user-granted files and folders across launches and from stored
/// references (Recent Documents, favorites, vault restore).
///
/// The app sandbox grants read access ONLY to items the user selects in the
/// current session (Open panel, Finder open, drag-in). A plain stored path
/// opened later — e.g. clicking a recent after relaunch — is denied, surfacing
/// as the red "could not read file" error (#55). Capturing a security-scoped
/// bookmark when access is first granted, then resolving + `startAccessing…`
/// it on re-open, is the sandbox-sanctioned way to make that access durable.
///
/// SPM/dev builds are not sandboxed, so none of this is exercised there — the
/// bug and this fix are release-only (verify on a signed/sandboxed build).
@MainActor
final class SecurityScopedBookmarks {
    static let shared = SecurityScopedBookmarks()

    private let defaultsKey = "securityScopedBookmarks_v1"
    /// standardized path → bookmark data.
    private var bookmarks: [String: Data]
    /// Resolved security-scoped URLs we currently hold access to, keyed by
    /// path, so start/stop are balanced on the exact resolved URL object.
    private var accessing: [String: URL] = [:]
    private var currentVaultKey: String?
    private var currentFileKey: String?

    private init() {
        bookmarks = (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Data]) ?? [:]
    }

    private func pathKey(_ url: URL) -> String { url.standardizedFileURL.path }

    /// Whether a file-read error means access was DENIED (sandbox or POSIX
    /// permissions) as opposed to the file being missing. Denied reads get the
    /// one-click re-grant UX (#57); missing files keep the plain error.
    nonisolated static func isPermissionDenied(_ error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == NSCocoaErrorDomain && ns.code == NSFileReadNoPermissionError { return true }
        if ns.domain == NSPOSIXErrorDomain && (ns.code == Int(EACCES) || ns.code == Int(EPERM)) { return true }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isPermissionDenied(underlying)
        }
        return false
    }

    // MARK: - Capture

    /// Record a bookmark for a URL the user just granted access to (Open panel,
    /// Finder open, drag-in). No-op if the URL isn't currently accessible —
    /// or lives in the app's own iCloud container, which the sandbox already
    /// extends to (bookmarkData(.withSecurityScope) can fail outright there).
    func save(_ url: URL) {
        guard !UbiquityVaultStore.isUbiquitousPath(url) else { return }
        guard let data = try? url.bookmarkData(options: .withSecurityScope,
                                               includingResourceValuesForKeys: nil,
                                               relativeTo: nil) else { return }
        bookmarks[pathKey(url)] = data
        UserDefaults.standard.set(bookmarks, forKey: defaultsKey)
    }

    // MARK: - Vault access

    /// Hold scoped access to the vault root — a folder bookmark covers every
    /// file inside it, so recents/favorites/embeds/index within the vault all
    /// read without per-file bookmarks. Ends any previously-held vault; pass
    /// `nil` when closing the folder.
    func useVault(_ url: URL?) {
        let newKey = url.map(pathKey)
        if newKey == currentVaultKey { return }
        if let old = currentVaultKey { stop(old) }
        currentVaultKey = newKey
        // Container vaults need no bookmark (the sandbox extends to the app's
        // own iCloud container once resolved) — but currentVaultKey stays set
        // so isUnderVault() keeps covering files inside them.
        if let url, !UbiquityVaultStore.isUbiquitousPath(url) { _ = begin(url) }
    }

    // MARK: - File access

    /// Ensure scoped access to a standalone file before reading it. Returns
    /// `true` when access is available (covered by the open vault, already
    /// held, or freshly started from a stored bookmark). Ends the previously
    /// held standalone file's access. A `false` return means no bookmark exists
    /// yet — the caller may still read if the OS granted access this session
    /// (and `save(_:)` should have been called at that grant point).
    @discardableResult
    func ensureFileAccess(_ url: URL) -> Bool {
        let key = pathKey(url)
        if isUnderVault(key) { return true }
        if key == currentFileKey { return accessing[key] != nil }
        if let old = currentFileKey, old != key { stop(old) }
        currentFileKey = key
        return begin(url)
    }

    // MARK: - Internals

    private func isUnderVault(_ key: String) -> Bool {
        guard let v = currentVaultKey else { return false }
        return key == v || key.hasPrefix(v + "/")
    }

    /// Resolve `url`'s stored bookmark and start accessing it. Refreshes a
    /// stale bookmark in place. Returns `true` when access is now held.
    @discardableResult
    private func begin(_ url: URL) -> Bool {
        let key = pathKey(url)
        if accessing[key] != nil { return true }
        guard let data = bookmarks[key] else { return false }
        var stale = false
        guard let scoped = try? URL(resolvingBookmarkData: data,
                                    options: .withSecurityScope,
                                    relativeTo: nil,
                                    bookmarkDataIsStale: &stale),
              scoped.startAccessingSecurityScopedResource() else { return false }
        accessing[key] = scoped
        if stale, let fresh = try? scoped.bookmarkData(options: .withSecurityScope,
                                                       includingResourceValuesForKeys: nil,
                                                       relativeTo: nil) {
            bookmarks[key] = fresh
            UserDefaults.standard.set(bookmarks, forKey: defaultsKey)
        }
        return true
    }

    private func stop(_ key: String) {
        if let scoped = accessing.removeValue(forKey: key) {
            scoped.stopAccessingSecurityScopedResource()
        }
    }
}
