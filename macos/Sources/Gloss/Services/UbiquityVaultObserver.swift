import Foundation

/// NSMetadataQuery-based `VaultObserving` conformer for vaults inside the
/// iCloud container — the iOS counterpart of FolderWatcher (no FSEvents on
/// iOS). The metadata query reports adds, changes, removes, AND
/// download-state transitions for ubiquitous items; every update flows into
/// the same debouncer → `.glossVaultFilesChanged` → reconcile +
/// incremental-index pipeline FolderWatcher feeds on macOS. Index-as-
/// downloaded falls out for free: a placeholder landing locally is an update
/// whose path gets re-indexed.
///
/// Also owns the eager-download policy: on first gathering (and for every
/// later-appearing placeholder) it kicks `startDownloadingUbiquitousItem`
/// for markdown files, so a fresh device pulls the readable vault down
/// without the user touching each file. Non-markdown assets download on
/// demand when a document referencing them is opened (WKWebView reads them
/// via file URLs once present).
///
/// `@unchecked Sendable` like FolderWatcher: start/stop run on the main
/// actor (FileTreeModel), and all query notifications are delivered on the
/// main queue, so mutable state is only ever touched on main.
final class UbiquityVaultObserver: NSObject, VaultObserving, @unchecked Sendable {
    private var query: NSMetadataQuery?
    private var observers: [any NSObjectProtocol] = []
    private var rootPath = ""
    private var rules: ExclusionRules = .standard
    private var onChange: (@Sendable ([String]) -> Void)?
    /// Placeholders already asked to download — each is kicked exactly once.
    private var downloadRequested: Set<String> = []

    @discardableResult
    func start(
        root: URL,
        rules: ExclusionRules,
        onChange: @escaping @Sendable ([String]) -> Void
    ) -> Bool {
        stop()
        // Only container vaults have ubiquitous metadata. For sandbox-local
        // vaults return false so FileTreeModel leaves `isWatching` false and
        // the per-file fallback semantics apply (macOS parity).
        guard UbiquityVaultStore.isUbiquitousPath(root) else { return false }

        let resolvedRoot = root.resolvingSymlinksInPath()
        rootPath = resolvedRoot.path
        self.rules = rules
        self.onChange = onChange

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        // Path-key predicates silently match NOTHING on device (the path
        // attribute isn't reliably queryable, and bird reports items under
        // /private/var while our root says /var). The only trustworthy
        // predicate is the always-true FSName form; vault scoping happens
        // in code, on canonicalized paths (vaultRelevantPaths).
        query.predicate = NSPredicate(format: "%K LIKE '*'", NSMetadataItemFSNameKey)

        observers.append(NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main
        ) { [weak self] _ in
            self?.handleInitialGathering()
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate, object: query, queue: .main
        ) { [weak self] note in
            self?.handleUpdate(note)
        })

        self.query = query
        return query.start()
    }

    func stop() {
        query?.stop()
        query = nil
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers = []
        onChange = nil
        rootPath = ""
        rules = .standard
        downloadRequested = []
    }

    // MARK: - Query handling (main queue)

    private func handleInitialGathering() {
        guard let query else { return }
        query.disableUpdates()
        var paths: [String] = []
        for index in 0..<query.resultCount {
            guard let item = query.result(at: index) as? NSMetadataItem,
                  let path = Self.path(of: item) else { continue }
            paths.append(path)
            kickDownloadIfWanted(item, path: path)
        }
        query.enableUpdates()
        emit(paths)
    }

    private func handleUpdate(_ note: Notification) {
        let added = note.userInfo?[NSMetadataQueryUpdateAddedItemsKey] as? [NSMetadataItem] ?? []
        let changed = note.userInfo?[NSMetadataQueryUpdateChangedItemsKey] as? [NSMetadataItem] ?? []
        let removed = note.userInfo?[NSMetadataQueryUpdateRemovedItemsKey] as? [NSMetadataItem] ?? []

        var paths: [String] = []
        for item in added + changed {
            guard let path = Self.path(of: item) else { continue }
            paths.append(path)
            kickDownloadIfWanted(item, path: path)
        }
        for item in removed {
            guard let path = Self.path(of: item) else { continue }
            paths.append(path)
            downloadRequested.remove(path)
        }
        emit(paths)
    }

    private func emit(_ paths: [String]) {
        let inVault = paths.filter { $0.hasPrefix(rootPrefix) }
        // Same favorites passthrough as FolderWatcher: the one .gloss path
        // that gets a signal out (already on the main queue here). Scoped
        // to THIS vault — the broad query sees sibling vaults' files too.
        if FavoritesService.pathsIncludeFavoritesFile(inVault) {
            NotificationCenter.default.post(name: .glossFavoritesFileChanged, object: nil)
        }
        guard let onChange else { return }
        let relevant = Self.vaultRelevantPaths(inVault, rootPath: rootPath, rules: rules)
        guard !relevant.isEmpty else { return }
        onChange(relevant)
    }

    private var rootPrefix: String {
        rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
    }

    private func kickDownloadIfWanted(_ item: NSMetadataItem, path: String) {
        let status = item.value(
            forAttribute: NSMetadataUbiquitousItemDownloadingStatusKey) as? String
        guard path.hasPrefix(rootPrefix),
              Self.wantsEagerDownload(path: path, downloadStatus: status),
              !downloadRequested.contains(path) else { return }
        downloadRequested.insert(path)
        try? FileManager.default.startDownloadingUbiquitousItem(
            at: URL(fileURLWithPath: path))
    }

    private static func path(of item: NSMetadataItem) -> String? {
        guard let raw = item.value(forAttribute: NSMetadataItemPathKey) as? String else {
            return nil
        }
        return canonicalItemPath(raw)
    }

    /// Metadata items surface under `/private/var/...` on device while every
    /// path the app derives from the container URL says `/var/...`.
    /// `resolvingSymlinksInPath` strips the `/private` prefix (documented
    /// behavior when the result exists), converging both spellings — so
    /// prefix checks, the debouncer, reconcile, and `paths.contains(target)`
    /// reload guards all compare in one path space.
    nonisolated static func canonicalItemPath(_ raw: String) -> String {
        URL(fileURLWithPath: raw).resolvingSymlinksInPath().path
    }

    // MARK: - Pure policy helpers (unit-tested)

    /// Vault scoping + exclusion filtering. The query is deliberately broad
    /// (see the predicate note in `start`), so paths outside the watched
    /// root — sibling vaults in the same container — are DROPPED here.
    /// Below the root, exclusion semantics match FolderWatcher: only
    /// components BELOW the root are inspected, so a vault whose own path
    /// contains an excluded name still works.
    nonisolated static func vaultRelevantPaths(
        _ paths: [String],
        rootPath: String,
        rules: ExclusionRules
    ) -> [String] {
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        return paths.filter { path in
            guard path.hasPrefix(prefix) else { return false }
            return !rules.isExcludedRelativePath(path.dropFirst(rootPath.count))
        }
    }

    /// Eager-download policy: markdown that isn't local yet. Everything else
    /// (images, attachments) downloads on demand.
    nonisolated static func wantsEagerDownload(path: String, downloadStatus: String?) -> Bool {
        guard downloadStatus != NSMetadataUbiquitousItemDownloadingStatusCurrent else {
            return false
        }
        let ext = (path as NSString).pathExtension.lowercased()
        return ext == "md" || ext == "markdown"
    }
}
