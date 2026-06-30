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
    var currentFileTags: [String] = []
    var linkHealth: LinkHealthStats = .empty
    var isIndexing: Bool = false

    private var database: LinkDatabase?
    private var rootURL: URL?
    private var indexTask: Task<Void, Never>?

    /// Paths the app itself just (re)indexed, with a timestamp. Used to swallow
    /// the FSEvents echo of our own saves so an in-app edit doesn't get indexed
    /// and resolved twice. @MainActor-confined (all access is on the main actor).
    private var recentSelfUpdates: [String: Date] = [:]

    /// Sendable snapshot of the current database, for other services (e.g.
    /// `VaultOverviewService`) that need to run queries off-main.
    var databaseRef: LinkDatabase? { database }

    /// Build the full index for a vault root. Creates `.gloss/index.sqlite`.
    ///
    /// Runs the heavy indexing work off-main via `Task.detached` — otherwise
    /// the nonisolated static helpers inherit main actor isolation from the
    /// enclosing `@MainActor` class and block the UI thread for the whole scan.
    func buildIndex(rootURL: URL) {
        self.rootURL = rootURL
        indexTask?.cancel()
        isIndexing = true

        indexTask = Task.detached { [weak self] in
            do {
                let db = try LinkDatabase(rootURL: rootURL)

                let files = Self.collectMarkdownFiles(under: rootURL)
                guard !Task.isCancelled else { return }

                // Remove stale entries
                let existingPaths = Set(files.map(\.path))
                try db.removeStaleFiles(existingPaths: existingPaths)

                // Index each file
                for fileURL in files {
                    guard !Task.isCancelled else { return }
                    try Self.indexFile(fileURL, rootURL: rootURL, database: db)
                }

                // Resolve cross-references
                try db.resolveAllLinks()

                // Collect aggregates off-main
                let recent = (try? db.recentlyChangedFiles()) ?? []
                let tags = (try? db.allTagCounts()) ?? []
                let health = Self.computeHealth(database: db)

                // Hop back to main actor for the state swap + notification
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.database = db
                    self.recentlyChanged = recent
                    self.allTags = tags
                    self.linkHealth = health
                    self.isIndexing = false
                    NotificationCenter.default.post(name: .glossIndexUpdated, object: nil)
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.isIndexing = false
                }
            }
            _ = self  // silence unused-capture warning when the catch path fires
        }
    }

    /// Incrementally update the index for a single file (e.g., after save).
    func updateIndex(for fileURL: URL) {
        guard let db = database, let rootURL else { return }

        // Record so handleExternalChanges can ignore the FSEvents echo of this save.
        recentSelfUpdates[fileURL.resolvingSymlinksInPath().path] = Date()

        Task.detached { [weak self] in
            do {
                try Self.indexFile(fileURL, rootURL: rootURL, database: db)
                try db.resolveAllLinks()

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

    /// Update the index after a file is deleted.
    func removeFromIndex(url: URL) {
        guard let db = database else { return }
        let standardizedPath = url.resolvingSymlinksInPath().path
        Task.detached { [weak self] in
            do {
                try db.deleteFile(path: standardizedPath)
                try db.resolveAllLinks()
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
    ///   the affected markdown files from the path alone, so they trigger a single
    ///   full rebuild — as do large bursts (e.g. a git checkout).
    /// - Otherwise all changed files are indexed/removed and links resolved ONCE
    ///   for the whole batch, not once per file.
    func handleExternalChanges(paths: [String]) {
        guard let db = database, let rootURL else { return }

        let fm = FileManager.default

        // A directory in the batch means a folder was created/renamed/moved/deleted
        // (file-level events carry the file's own path, not its parent).
        let hasStructuralChange = paths.contains { path in
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: path, isDirectory: &isDir) {
                return isDir.boolValue
            }
            // A vanished path with no file extension is most likely a removed dir.
            return (path as NSString).pathExtension.isEmpty
        }

        var markdownPaths = paths.filter {
            Self.markdownExtensions.contains(($0 as NSString).pathExtension.lowercased())
        }

        // Swallow the FSEvents echo of our own saves (one-shot: a genuine later
        // external edit to the same file is not suppressed).
        markdownPaths = markdownPaths.filter { path in
            let key = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
            if let t = recentSelfUpdates[key], Date().timeIntervalSince(t) < 2.0 {
                recentSelfUpdates[key] = nil
                return false
            }
            return true
        }
        let cutoff = Date().addingTimeInterval(-2.0)
        recentSelfUpdates = recentSelfUpdates.filter { $0.value > cutoff }

        if hasStructuralChange || markdownPaths.count > 20 {
            buildIndex(rootURL: rootURL)
            return
        }
        guard !markdownPaths.isEmpty else { return }

        // Batch: index/remove every changed file, then resolve links and refresh
        // aggregates ONCE. Posting .glossIndexUpdated lets ContentView refresh
        // backlinks, the vault overview, and the graph for the current file.
        Task.detached { [weak self] in
            for path in markdownPaths {
                let url = URL(fileURLWithPath: path)
                if FileManager.default.fileExists(atPath: path) {
                    try? Self.indexFile(url, rootURL: rootURL, database: db)
                } else {
                    try? db.deleteFile(path: url.resolvingSymlinksInPath().path)
                }
            }
            try? db.resolveAllLinks()
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
        Task.detached { [weak self] in
            do {
                try db.deleteFile(path: oldPath)
                try Self.indexFile(newURL, rootURL: rootURL, database: db)
                try db.resolveAllLinks()
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

    /// Names to skip during indexing (mirrors FileTreeNode.excludedNames + .gloss).
    nonisolated private static let excludedNames: Set<String> = [
        "node_modules", ".git", ".build", ".swiftpm", "__pycache__",
        ".DS_Store", "Thumbs.db", ".gloss"
    ]
    nonisolated private static let markdownExtensions: Set<String> = ["md", "markdown"]

    /// Collect all markdown files under a directory.
    nonisolated private static func collectMarkdownFiles(under url: URL) -> [URL] {
        let fm = FileManager.default
        var files: [URL] = []

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        while let itemURL = enumerator.nextObject() as? URL {
            let name = itemURL.lastPathComponent

            if excludedNames.contains(name) {
                enumerator.skipDescendants()
                continue
            }

            let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if !isDir && markdownExtensions.contains(itemURL.pathExtension.lowercased()) {
                files.append(itemURL)
            }
        }

        return files
    }

    /// Index a single file: read content, extract links/tags, persist to database.
    nonisolated private static func indexFile(_ fileURL: URL, rootURL: URL, database: LinkDatabase) throws {
        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else { return }

        let modDate = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
        let title = fileURL.deletingPathExtension().lastPathComponent
        let standardizedPath = fileURL.resolvingSymlinksInPath().path

        let fileId = try database.upsertFile(path: standardizedPath, title: title, modifiedAt: modDate)

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
    }
}
