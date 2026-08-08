import Foundation
import GlossKit

/// Orchestrates the link index: scans vault files, extracts links/tags,
/// persists to SQLite, and exposes backlinks for the current document.
@Observable
@MainActor
final class LinkIndex {
    var backlinks: [BacklinkGroup] = []
    var forwardLinks: [ForwardLinkGroup] = []
    var recentlyChanged: [(path: String, title: String, modifiedAt: Date)] = []
    var allTags: [(tag: String, count: Int)] = []
    var allTitles: [String] = []
    var currentFileTags: [String] = []
    var unlinkedMentions: [UnlinkedMention] = []
    var linkHealth: LinkHealthStats = .empty
    var isIndexing: Bool = false

    private var database: LinkDatabase?
    private var rootURL: URL?

    /// Paths the app itself just (re)indexed, with a timestamp. Used to swallow
    /// the FSEvents echo of our own saves so an in-app edit doesn't get indexed
    /// and resolved twice. @MainActor-confined (all access is on the main actor).
    private var recentSelfUpdates: [String: Date] = [:]

    /// Sendable snapshot of the current database, for other services (e.g.
    /// `VaultOverviewService`) that need to run queries off-main.
    var databaseRef: LinkDatabase? { database }

    // MARK: - Serialized Index Pipeline

    /// Tail of the serialized pipeline. Every index mutation (full build,
    /// per-file update, watcher batch, delete, rename) chains behind the
    /// previous one. Overlapping untracked `Task.detached` workers were how a
    /// burst of watcher batches piled up multi-GB of concurrent rebuild
    /// state (#35).
    private var pipelineTail: Task<Void, Never>?

    /// The in-flight full build, if any; a newer full build cancels it
    /// (checked per file inside the build loop).
    private var buildTask: Task<Void, Never>?

    /// Rate limiting for watcher-triggered full rebuilds.
    private var lastFullBuildStartedAt: Date?
    private var fullRebuildScheduled = false
    /// Minimum spacing between full builds. Instance-var so tests can shrink it.
    var fullRebuildMinInterval: TimeInterval = 30

    /// Number of full builds that began executing (observability for tests).
    private(set) var fullBuildCount = 0

    /// Stats from the most recent completed full build.
    struct BuildStats: Equatable, Sendable {
        var indexed = 0
        var skipped = 0
        var removed = 0
    }
    private(set) var lastBuildStats: BuildStats?

    /// True when the vault scan crossed the large-workspace threshold —
    /// the sidebar surfaces a one-time hint about `.gloss/config.json`.
    private(set) var largeVaultDetected = false
    nonisolated private static let largeVaultDirectoryThreshold = 5_000

    /// Chain an operation behind all previously enqueued index work.
    @discardableResult
    private func enqueue(_ op: @escaping @Sendable () async -> Void) -> Task<Void, Never> {
        let previous = pipelineTail
        let task = Task.detached(priority: .utility) {
            await previous?.value
            await op()
        }
        pipelineTail = task
        return task
    }

    /// Tear down the open database and cancel in-flight index work — called
    /// when a vault closes, and by the vault migrator to quiesce before
    /// moving a vault (nothing may hold the SQLite file open mid-move).
    func close() {
        buildTask?.cancel()
        buildTask = nil
        pipelineTail = nil
        database = nil
        rootURL = nil
        recentSelfUpdates = [:]
        backlinks = []
        forwardLinks = []
        recentlyChanged = []
        allTags = []
        allTitles = []
        currentFileTags = []
        unlinkedMentions = []
        linkHealth = .empty
        isIndexing = false
        fullRebuildScheduled = false
    }

    // MARK: - Full Build

    /// Build the full index for a vault root. Creates `.gloss/index.sqlite`.
    ///
    /// Runs on the serialized pipeline off-main. Files whose stored mtime
    /// matches disk are skipped, so a warm rebuild (app launch, structural
    /// change) is a metadata scan rather than a full re-read of the vault.
    func buildIndex(rootURL: URL) {
        self.rootURL = rootURL
        fullRebuildScheduled = false
        lastFullBuildStartedAt = Date()
        fullBuildCount += 1
        isIndexing = true
        buildTask?.cancel() // a newer full build supersedes an in-flight one

        buildTask = enqueue { [weak self] in
            do {
                let db = try LinkDatabase(rootURL: rootURL)

                // Re-derive rules from the vault config rather than capturing
                // main-actor state — order-independent of FileTreeModel.openFolder.
                let rules = ExclusionRules.forVault(root: rootURL)
                let scan = Self.collectMarkdownFiles(under: rootURL, rules: rules)
                let files = scan.files
                let isLargeVault = scan.directoryCount > Self.largeVaultDirectoryThreshold
                guard !Task.isCancelled else { return }

                // Remove stale entries. Stale-detection must compare the same
                // canonical form the index stores (symlink-resolved), or a
                // vault under a symlinked root (/var → /private/var) wipes and
                // re-indexes everything on every build.
                let resolvedPaths = files.map { $0.resolvingSymlinksInPath().path }
                let resolvedSet = Set(resolvedPaths)
                // Fetched BEFORE the stale sweep so the vanished paths can be
                // mirrored out of Spotlight (the DB sweep only reports a count).
                let storedModTimes = (try? db.allFileModTimes()) ?? [:]
                SpotlightIndexer.remove(
                    paths: storedModTimes.keys.filter { !resolvedSet.contains($0) })
                let removed = try db.removeStaleFiles(existingPaths: resolvedSet)

                // Index each changed file; skip unchanged mtimes. The
                // autoreleasepool bounds Foundation's bridged-string garbage,
                // which otherwise accumulates for the whole scan.
                var stats = BuildStats(indexed: 0, skipped: 0, removed: removed)
                for (fileURL, resolvedPath) in zip(files, resolvedPaths) {
                    guard !Task.isCancelled else { return }
                    try autoreleasepool {
                        let diskMod = (try? fileURL.resourceValues(
                            forKeys: [.contentModificationDateKey]))?.contentModificationDate
                        if let diskMod, let stored = storedModTimes[resolvedPath],
                           abs(diskMod.timeIntervalSince1970 - stored) < 0.001 {
                            stats.skipped += 1
                        } else {
                            _ = try Self.indexFile(fileURL, rootURL: rootURL, database: db)
                            stats.indexed += 1
                        }
                    }
                }

                // Resolve cross-references once — skippable when nothing changed.
                if stats.indexed > 0 || stats.removed > 0 {
                    try db.resolveAllLinks()
                }

                // Collect aggregates off-main
                let recent = (try? db.recentlyChangedFiles()) ?? []
                let tags = (try? db.allTagCounts()) ?? []
                let titles = (try? db.graphFiles())?.map(\.title) ?? []
                let health = Self.computeHealth(database: db)

                // Hop back to main actor for the state swap + notification
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.database = db
                    self.recentlyChanged = recent
                    self.allTags = tags
                    self.allTitles = titles
                    self.linkHealth = health
                    self.lastBuildStats = stats
                    self.largeVaultDetected = isLargeVault
                    self.isIndexing = false
                    NotificationCenter.default.post(name: .glossIndexUpdated, object: nil)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.isIndexing = false
                }
            }
            _ = self // silence unused-capture warning when the catch path fires
        }
    }

    /// Request a full rebuild, coalescing repeated requests: dev churn can
    /// otherwise ask for one per watcher batch. At most one build starts per
    /// `fullRebuildMinInterval`; a request arriving inside the window schedules
    /// exactly one trailing build, so the index still converges on the final
    /// on-disk state.
    func requestFullRebuild() {
        guard let rootURL else { return }
        guard !fullRebuildScheduled else { return }
        let elapsed = lastFullBuildStartedAt.map { Date().timeIntervalSince($0) } ?? .infinity
        if elapsed >= fullRebuildMinInterval {
            buildIndex(rootURL: rootURL)
        } else {
            fullRebuildScheduled = true
            let delay = fullRebuildMinInterval - elapsed
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                guard let self, self.fullRebuildScheduled else { return }
                if let root = self.rootURL {
                    self.buildIndex(rootURL: root) // clears fullRebuildScheduled
                }
            }
        }
    }

    // MARK: - Incremental Updates

    /// Incrementally update the index for a single file (e.g., after save).
    func updateIndex(for fileURL: URL) {
        guard let db = database, let rootURL else { return }

        // Record so handleExternalChanges can ignore the FSEvents echo of this save.
        recentSelfUpdates[fileURL.resolvingSymlinksInPath().path] = Date()

        enqueue { [weak self] in
            do {
                guard let fileId = try Self.indexFile(fileURL, rootURL: rootURL, database: db) else { return }
                try db.resolveLinksTouching(fileId: fileId)

                let recent = (try? db.recentlyChangedFiles()) ?? []
                let tags = (try? db.allTagCounts()) ?? []
                let health = Self.computeHealth(database: db)

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.recentlyChanged = recent
                    self.allTags = tags
                    self.linkHealth = health
                    self.refreshBacklinks(for: fileURL)
                }
            } catch {
                // Index update failed silently
            }
            _ = self
        }
    }

    /// Update the index after a file is deleted. `deleteFile` un-resolves
    /// inbound links itself, so no resolve pass is needed.
    func removeFromIndex(url: URL) {
        guard let db = database else { return }
        let standardizedPath = url.resolvingSymlinksInPath().path
        enqueue { [weak self] in
            do {
                try db.deleteFile(path: standardizedPath)
                SpotlightIndexer.remove(paths: [standardizedPath])
                // Recompute aggregates too, otherwise the deleted file lingers in
                // the Recently Changed list and its tags stay in the Tags browser.
                let recent = (try? db.recentlyChangedFiles()) ?? []
                let tags = (try? db.allTagCounts()) ?? []
                let health = Self.computeHealth(database: db)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.recentlyChanged = recent
                    self.allTags = tags
                    self.linkHealth = health
                }
            } catch {
                // Delete failed silently
            }
            _ = self
        }
    }

    /// React to external (non-app) file-system changes reported by the folder
    /// watcher. Re-indexes created/modified markdown files and drops deleted ones.
    ///
    /// - Directory-level changes (folder rename/move/delete) can't be mapped to
    ///   the affected markdown files from the path alone, so they request a
    ///   full rebuild — rate-limited, since builds are mtime-cheap but not free.
    /// - Otherwise all changed files are indexed/removed on the serialized
    ///   pipeline and links resolved for the whole batch: incrementally for
    ///   small batches, or in one indexed full pass for large ones.
    func handleExternalChanges(paths: [String]) {
        guard let db = database, let rootURL else { return }

        let fm = FileManager.default

        // A path that IS currently a directory means a folder was created/
        // renamed/moved. A vanished path counts as structural only when the
        // index knows files beneath it — the old guess ("vanished + no
        // extension ⇒ removed dir") fired for every deleted extension-less
        // dev file (Makefile, LICENSE, binaries) and forced full rebuilds.
        let hasStructuralChange = paths.contains { path in
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: path, isDirectory: &isDir) {
                return isDir.boolValue
            }
            let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
            return (try? db.hasFiles(underPathPrefix: resolved + "/")) ?? false
        }

        var markdownPaths = paths.filter {
            Self.markdownExtensions.contains(($0 as NSString).pathExtension.lowercased())
        }

        // Swallow the FSEvents echo of our own saves (one-shot: a genuine later
        // external edit to the same file is not suppressed). The window covers
        // FSEvents latency (0.3s) plus the debouncer's max delivery delay (1.5s).
        markdownPaths = markdownPaths.filter { path in
            let key = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
            if let t = recentSelfUpdates[key], Date().timeIntervalSince(t) < 3.0 {
                recentSelfUpdates[key] = nil
                return false
            }
            return true
        }
        let cutoff = Date().addingTimeInterval(-3.0)
        recentSelfUpdates = recentSelfUpdates.filter { $0.value > cutoff }

        if hasStructuralChange {
            requestFullRebuild()
            return
        }
        guard !markdownPaths.isEmpty else { return }

        // Batch: index/remove every changed file, then resolve links and refresh
        // aggregates ONCE. Posting .glossIndexUpdated lets ContentView refresh
        // backlinks, the vault overview, and the graph for the current file.
        let batchPaths = markdownPaths
        enqueue { [weak self] in
            var touchedIds: [Int64] = []
            for path in batchPaths {
                let url = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: path) {
                    if let id = ((try? Self.indexFile(url, rootURL: rootURL, database: db)) ?? nil) {
                        touchedIds.append(id)
                    }
                } else {
                    try? db.deleteFile(path: url.resolvingSymlinksInPath().path)
                }
            }
            if touchedIds.count > 5 {
                try? db.resolveAllLinks()
            } else {
                for id in touchedIds {
                    try? db.resolveLinksTouching(fileId: id)
                }
            }
            let recent = (try? db.recentlyChangedFiles()) ?? []
            let tags = (try? db.allTagCounts()) ?? []
            let health = Self.computeHealth(database: db)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.recentlyChanged = recent
                self.allTags = tags
                self.linkHealth = health
                NotificationCenter.default.post(name: .glossIndexUpdated, object: nil)
            }
            _ = self
        }
    }

    /// Update the index after a file rename.
    func handleRename(oldURL: URL, newURL: URL) {
        guard let db = database, let rootURL else { return }
        let oldPath = oldURL.resolvingSymlinksInPath().path
        enqueue { [weak self] in
            do {
                try db.deleteFile(path: oldPath)
                // The new path re-enters Spotlight via indexFile below.
                SpotlightIndexer.remove(paths: [oldPath])
                if let fileId = try Self.indexFile(newURL, rootURL: rootURL, database: db) {
                    try db.resolveLinksTouching(fileId: fileId)
                }
                let health = Self.computeHealth(database: db)
                await MainActor.run { [weak self] in
                    self?.linkHealth = health
                }
            } catch {
                // Rename index update failed silently
            }
            _ = self
        }
    }

    /// Refresh the backlinks, forward links, and tags for the currently viewed file.
    func refreshBacklinks(for fileURL: URL?) {
        guard let db = database, let fileURL else {
            backlinks = []
            forwardLinks = []
            currentFileTags = []
            unlinkedMentions = []
            return
        }

        let standardizedPath = fileURL.resolvingSymlinksInPath().path

        // Refresh tags for current file
        if let fileId = try? db.fileId(forPath: standardizedPath),
           let tags = try? db.tags(forFileId: fileId) {
            currentFileTags = tags
        } else {
            currentFileTags = []
        }

        // Refresh backlinks
        if let links = try? db.backlinks(forPath: standardizedPath), !links.isEmpty {
            let grouped = Dictionary(grouping: links, by: \.linkType)
            backlinks = LinkType.allCases.compactMap { type in
                guard let typeLinks = grouped[type], !typeLinks.isEmpty else { return nil }
                return BacklinkGroup(linkType: type, links: typeLinks)
            }
        } else {
            backlinks = []
        }

        // Refresh forward links
        if let links = try? db.forwardLinks(forPath: standardizedPath), !links.isEmpty {
            let grouped = Dictionary(grouping: links, by: \.linkType)
            forwardLinks = LinkType.allCases.compactMap { type in
                guard let typeLinks = grouped[type], !typeLinks.isEmpty else { return nil }
                return ForwardLinkGroup(linkType: type, links: typeLinks)
            }
        } else {
            forwardLinks = []
        }

        // Refresh unlinked mentions — notes that mention this title but don't link
        let title = fileURL.deletingPathExtension().lastPathComponent
        if let fileId = try? db.fileId(forPath: standardizedPath),
           let mentions = try? db.unlinkedMentions(forTitle: title, currentFileId: fileId) {
            unlinkedMentions = mentions
        } else {
            unlinkedMentions = []
        }
    }

    /// Compute current vault link health (total + broken counts).
    nonisolated private static func computeHealth(database: LinkDatabase) -> LinkHealthStats {
        let total = (try? database.linkCount()) ?? 0
        let broken = (try? database.brokenLinkCount()) ?? 0
        return LinkHealthStats(totalLinks: total, brokenCount: broken)
    }

    /// Get file paths for a specific tag.
    func files(forTag tag: String) -> [(path: String, title: String)] {
        guard let db = database else { return [] }
        return (try? db.files(forTag: tag)) ?? []
    }

    // MARK: - Static Helpers (nonisolated for TaskGroup)

    nonisolated private static let markdownExtensions: Set<String> = ["md", "markdown"]

    /// Collect all markdown files under a directory, honoring the vault's
    /// exclusion rules (single source of truth shared with the watcher/tree).
    /// Also reports how many directories were visited, which feeds the
    /// large-workspace detection.
    nonisolated private static func collectMarkdownFiles(
        under url: URL,
        rules: ExclusionRules
    ) -> (files: [URL], directoryCount: Int) {
        let fm = FileManager.default
        var files: [URL] = []
        var directoryCount = 0

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return ([], 0) }

        while let itemURL = enumerator.nextObject() as? URL {
            let name = itemURL.lastPathComponent

            if rules.isExcluded(name) {
                enumerator.skipDescendants()
                continue
            }

            let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir {
                directoryCount += 1
            } else if markdownExtensions.contains(itemURL.pathExtension.lowercased()) {
                files.append(itemURL)
            }
        }

        return (files, directoryCount)
    }

    /// Index a single file: read content, extract links/tags, persist to
    /// database. Returns the file's row ID, or nil when the file is unreadable.
    /// Links are stored unresolved — follow up with `resolveLinksTouching` or
    /// `resolveAllLinks`.
    @discardableResult
    /// Evicted or not-yet-downloaded ubiquitous files (Optimize Mac Storage
    /// on macOS, placeholders on iOS) either fail to read or trigger a
    /// blocking download — the indexer must skip them. The watcher delivers
    /// the path again when the bytes land, and it gets indexed then.
    nonisolated static func isDatalessUbiquitousFile(_ url: URL) -> Bool {
        guard let values = try? url.resourceValues(
                forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]),
              values.isUbiquitousItem == true else { return false }
        return values.ubiquitousItemDownloadingStatus != .current
    }

    nonisolated private static func indexFile(
        _ fileURL: URL,
        rootURL: URL,
        database: LinkDatabase
    ) throws -> Int64? {
        guard !isDatalessUbiquitousFile(fileURL) else { return nil }
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }

        let modDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
        let title = fileURL.deletingPathExtension().lastPathComponent
        let standardizedPath = fileURL.resolvingSymlinksInPath().path

        let fileId = try database.upsertFile(path: standardizedPath, title: title, modifiedAt: modDate)
        // Content is in hand exactly here — mirror into Spotlight so system
        // search stays in lockstep with the link index.
        SpotlightIndexer.upsert(
            path: standardizedPath, title: title, content: content, vaultRoot: rootURL)

        // Extract and store links
        let extractedLinks = MarkdownRenderer.extractLinks(content)
        let linkTuples = extractedLinks.map {
            (targetName: $0.target, linkType: $0.linkType, displayText: $0.displayText, lineNumber: $0.lineNumber)
        }
        try database.replaceLinks(fileId: fileId, links: linkTuples)

        // Extract and store tags
        let tags = MarkdownRenderer.extractTags(content)
        try database.replaceTags(fileId: fileId, tags: tags)

        // Extract and store scalar frontmatter properties (for `type: query` filters)
        let properties = MarkdownRenderer.extractProperties(content)
        try database.replaceProperties(fileId: fileId, properties: properties)

        // WS5 — full-text index the raw markdown body. Keeping the raw
        // source (not rendered HTML) matches what users actually search for
        // and lets FTS5 tokenize against wiki-link syntax.
        try database.indexFileContent(fileId: fileId, title: title, body: content)

        return fileId
    }
}
