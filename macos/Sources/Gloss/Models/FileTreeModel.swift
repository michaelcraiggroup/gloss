import Foundation

/// Sort criteria for the file tree.
enum SortOrder: String, CaseIterable {
    case name = "Name"
    case dateModified = "Date"
}

/// Sort direction.
enum SortDirection {
    case ascending, descending

    var toggled: SortDirection {
        self == .ascending ? .descending : .ascending
    }

    var symbol: String {
        self == .ascending ? "chevron.up" : "chevron.down"
    }
}

/// Manages the file tree sidebar state. Holds the root folder node and selected file.
@Observable
@MainActor
final class FileTreeModel {
    var rootNode: FileTreeNode?
    var selectedFileURL: URL?
    var searchQuery: String = ""
    var searchScope: SearchScope = .filename
    var scopedNode: FileTreeNode?
    var sortOrder: SortOrder = .name
    var sortDirection: SortDirection = .ascending
    var activeTagFilter: String?
    var tagFilteredFiles: [(path: String, title: String)]?

    private let folderWatcher = FolderWatcher()

    /// Whether the folder watcher is actively running. False if FSEvents failed
    /// to start — DocumentView checks this so it keeps the per-file watcher as a
    /// fallback for the open document instead of silently relying on a dead watch.
    private(set) var isWatching = false

    /// Open a folder and populate the root tree node.
    func openFolder(_ url: URL) {
        let node = FileTreeNode(url: url, isDirectory: true)
        node.loadChildren()
        node.isExpanded = true
        rootNode = node
        // Watch the whole tree; the callback (on main) fans out to the tree,
        // the link index, and the open document via a single notification.
        isWatching = folderWatcher.start(root: url) { paths in
            NotificationCenter.default.post(name: .glossVaultFilesChanged, object: paths)
        }
    }

    /// Close the current folder.
    func closeFolder() {
        folderWatcher.stop()
        isWatching = false
        scopedNode = nil
        rootNode = nil
    }

    /// Whether a folder is currently open.
    var hasFolder: Bool {
        rootNode != nil
    }

    /// The display name of the open folder.
    var folderName: String {
        rootNode?.name ?? ""
    }

    /// The active tree node for display and search (scoped or root).
    var activeNode: FileTreeNode? {
        scopedNode ?? rootNode
    }

    /// Whether the tree is scoped to a subfolder.
    var isScoped: Bool {
        scopedNode != nil
    }

    /// Drill into a subfolder — scopes tree display and search.
    func scopeToFolder(_ node: FileTreeNode) {
        guard node.isDirectory else { return }
        if node.children == nil { node.loadChildren() }
        node.isExpanded = true
        scopedNode = node
    }

    /// Return to the full root tree.
    func unscopeFolder() {
        scopedNode = nil
    }

    // MARK: - Sorting

    /// Toggle sort: if same order, flip direction; if different, set new order ascending.
    func toggleSort(_ order: SortOrder) {
        if sortOrder == order {
            sortDirection = sortDirection.toggled
        } else {
            sortOrder = order
            sortDirection = .ascending
        }
    }

    /// Sort children: directories first, then files by current sort criteria.
    func sortedChildren(_ children: [FileTreeNode]) -> [FileTreeNode] {
        children.sorted { a, b in
            // Directories always first
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }

            let result: ComparisonResult
            switch sortOrder {
            case .name:
                result = a.name.localizedStandardCompare(b.name)
            case .dateModified:
                let dateA = a.modificationDate ?? .distantPast
                let dateB = b.modificationDate ?? .distantPast
                result = dateA.compare(dateB)
            }

            return sortDirection == .ascending
                ? result == .orderedAscending
                : result == .orderedDescending
        }
    }

    // MARK: - File Operations

    /// Create a new markdown file in the given directory.
    @discardableResult
    func createFile(named name: String, in directory: URL) -> URL? {
        var fileName = name.trimmingCharacters(in: .whitespaces)
        guard !fileName.isEmpty else { return nil }
        if !fileName.hasSuffix(".md") && !fileName.hasSuffix(".markdown") {
            fileName += ".md"
        }
        let fileURL = directory.appendingPathComponent(fileName)
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            refreshAfterFileChange()
            return fileURL
        } catch {
            return nil
        }
    }

    /// Rename a file or folder.
    func renameItem(at url: URL, to newName: String) -> URL? {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        let newURL = url.deletingLastPathComponent().appendingPathComponent(trimmed)
        guard newURL != url else { return nil }
        guard !FileManager.default.fileExists(atPath: newURL.path) else { return nil }
        do {
            try FileManager.default.moveItem(at: url, to: newURL)
            refreshAfterFileChange()
            return newURL
        } catch {
            return nil
        }
    }

    /// Move a file to trash.
    func deleteItem(at url: URL) -> Bool {
        do {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
            refreshAfterFileChange()
            return true
        } catch {
            return false
        }
    }

    /// Reconcile the tree against the current disk state after a file-system
    /// change (external edit, file op, or a folder-watcher event). Recurses
    /// through every loaded directory and preserves existing nodes — and their
    /// expansion + loaded subtrees — wherever the path still exists.
    func refreshAfterFileChange() {
        if let root = rootNode {
            reconcileNode(root)
        }
        // scopedNode lives within root's tree, but reconcileNode only recurses
        // into already-loaded directories; reconcile it explicitly in case the
        // path from root to it isn't fully loaded.
        if let scoped = scopedNode, scoped !== rootNode {
            reconcileNode(scoped)
        }
    }

    // MARK: - Tag Filtering

    /// Filter the sidebar to show only files with a specific tag.
    func filterByTag(_ tag: String, files: [(path: String, title: String)]) {
        activeTagFilter = tag
        tagFilteredFiles = files
    }

    /// Clear the active tag filter.
    func clearTagFilter() {
        activeTagFilter = nil
        tagFilteredFiles = nil
    }

    // MARK: - Tree Reconciliation

    /// Reconcile a single loaded directory node against disk, then recurse into
    /// its loaded subdirectories. Reuses existing child nodes by path so that
    /// expansion state and already-loaded grandchildren survive the refresh —
    /// only added/removed entries change. Cost is bounded by the directories
    /// the user has actually expanded (children != nil), not the whole tree.
    private func reconcileNode(_ node: FileTreeNode) {
        guard node.isDirectory, let existing = node.children else { return }

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: node.url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let folderName = node.url.lastPathComponent

        // Entries that belong in the tree (same filter as loadChildren).
        var desired: [(url: URL, isDir: Bool)] = []
        for itemURL in contents {
            if FileTreeNode.excludedNames.contains(itemURL.lastPathComponent) { continue }
            let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDir || FileTreeNode.markdownExtensions.contains(itemURL.pathExtension.lowercased()) {
                desired.append((itemURL, isDir))
            }
        }

        // Reuse existing nodes by standardized path; create nodes for the rest.
        var existingByPath: [String: FileTreeNode] = [:]
        for child in existing {
            existingByPath[child.url.standardizedFileURL.path] = child
        }

        var merged: [FileTreeNode] = desired.map { entry in
            // Reuse only when the type still matches — an external `rm x && mkdir x`
            // (or the reverse) keeps the path but flips file<->dir, and the stale
            // node's `isDirectory`/`documentType` are immutable, so it must be rebuilt.
            if let reused = existingByPath[entry.url.standardizedFileURL.path],
               reused.isDirectory == entry.isDir {
                return reused
            }
            return FileTreeNode(
                url: entry.url,
                isDirectory: entry.isDir,
                parentFolderName: entry.isDir ? "" : folderName
            )
        }

        // Match loadChildren's storage order: directories first, then alpha.
        merged.sort { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }

        // Reassign when the set of (type, path) entries changed — keying on type
        // too means a file<->dir flip at the same path counts as a change.
        let typedKey: (FileTreeNode) -> String = { "\($0.isDirectory ? "d" : "f"):\($0.url.standardizedFileURL.path)" }
        if existing.map(typedKey) != merged.map(typedKey) {
            node.children = merged
        }

        // Recurse into loaded subdirectories only.
        for child in merged where child.isDirectory && child.children != nil {
            reconcileNode(child)
        }
    }

    // MARK: - Search

    /// When search is active, returns a flat list of matching file nodes.
    /// Recursively walks the tree, loading children as needed.
    var searchResults: [FileTreeNode]? {
        guard !searchQuery.isEmpty, let node = activeNode else { return nil }
        var results: [FileTreeNode] = []
        collectMatching(node: node, query: searchQuery.lowercased(), into: &results)
        return results
    }

    private func collectMatching(node: FileTreeNode, query: String, into results: inout [FileTreeNode]) {
        if node.isDirectory {
            if node.children == nil {
                node.loadChildren()
            }
            for child in node.children ?? [] {
                collectMatching(node: child, query: query, into: &results)
            }
        } else {
            if node.name.lowercased().contains(query) {
                results.append(node)
            }
        }
    }
}

/// Search scope for the sidebar search bar.
enum SearchScope: String, CaseIterable {
    case filename = "Filenames"
    case content = "Content"
    case tags = "Tags"
}
