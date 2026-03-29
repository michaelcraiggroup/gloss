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

    private var pollTimer: Timer?

    /// Open a folder and populate the root tree node.
    func openFolder(_ url: URL) {
        let node = FileTreeNode(url: url, isDirectory: true)
        node.loadChildren()
        node.isExpanded = true
        rootNode = node
        startPolling()
    }

    /// Close the current folder.
    func closeFolder() {
        stopPolling()
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

    /// Force refresh the tree after a file system change.
    func refreshAfterFileChange() {
        if let root = rootNode {
            refreshNode(root)
        }
        if let scoped = scopedNode {
            refreshNode(scoped)
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

    // MARK: - Directory Polling

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshIfNeeded()
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func refreshIfNeeded() {
        if let root = rootNode {
            refreshNode(root)
        }
        if let scoped = scopedNode {
            refreshNode(scoped)
        }
    }

    private func refreshNode(_ node: FileTreeNode) {
        guard node.isDirectory, node.children != nil else { return }

        let fm = FileManager.default
        guard let currentURLs = try? fm.contentsOfDirectory(
            at: node.url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let filteredURLs = Set(currentURLs.filter { url in
            let name = url.lastPathComponent
            if FileTreeNode.excludedNames.contains(name) { return false }
            let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            return isDir || FileTreeNode.markdownExtensions.contains(url.pathExtension.lowercased())
        }.map(\.absoluteURL))

        let existingURLs = Set((node.children ?? []).map(\.url.absoluteURL))

        if filteredURLs != existingURLs {
            node.loadChildren()
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
