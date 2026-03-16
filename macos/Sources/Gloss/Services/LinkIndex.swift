import Foundation
import GlossKit

/// Orchestrates the link index: scans vault files, extracts links/tags,
/// persists to SQLite, and exposes backlinks for the current document.
@Observable
@MainActor
final class LinkIndex {
    var backlinks: [BacklinkGroup] = []
    var isIndexing: Bool = false

    private var database: LinkDatabase?
    private var rootURL: URL?
    private var indexTask: Task<Void, Never>?

    /// Build the full index for a vault root. Creates `.gloss/index.sqlite`.
    func buildIndex(rootURL: URL) {
        self.rootURL = rootURL
        indexTask?.cancel()
        isIndexing = true

        indexTask = Task {
            do {
                let db = try LinkDatabase(rootURL: rootURL)
                self.database = db

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

                isIndexing = false
            } catch {
                isIndexing = false
            }
        }
    }

    /// Incrementally update the index for a single file (e.g., after save).
    func updateIndex(for fileURL: URL) {
        guard let db = database, let rootURL else { return }

        Task {
            do {
                try Self.indexFile(fileURL, rootURL: rootURL, database: db)
                try db.resolveAllLinks()
                // Refresh backlinks if we're viewing a file
                refreshBacklinks(for: fileURL)
            } catch {
                // Index update failed silently
            }
        }
    }

    /// Update the index after a file is deleted.
    func removeFromIndex(url: URL) {
        guard let db = database else { return }
        let standardizedPath = url.standardizedFileURL.path
        Task {
            do {
                try db.deleteFile(path: standardizedPath)
                try db.resolveAllLinks()
            } catch {
                // Delete failed silently
            }
        }
    }

    /// Update the index after a file rename.
    func handleRename(oldURL: URL, newURL: URL) {
        guard let db = database, let rootURL else { return }
        let oldPath = oldURL.standardizedFileURL.path
        Task {
            do {
                try db.deleteFile(path: oldPath)
                try Self.indexFile(newURL, rootURL: rootURL, database: db)
                try db.resolveAllLinks()
            } catch {
                // Rename index update failed silently
            }
        }
    }

    /// Refresh the backlinks array for the currently viewed file.
    func refreshBacklinks(for fileURL: URL?) {
        guard let db = database, let fileURL else {
            backlinks = []
            return
        }

        guard let links = try? db.backlinks(forPath: fileURL.standardizedFileURL.path), !links.isEmpty else {
            backlinks = []
            return
        }

        let grouped = Dictionary(grouping: links, by: \.linkType)
        backlinks = LinkType.allCases.compactMap { type in
            guard let typeLinks = grouped[type], !typeLinks.isEmpty else { return nil }
            return BacklinkGroup(linkType: type, links: typeLinks)
        }
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
        let standardizedPath = fileURL.standardizedFileURL.path

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
    }
}
