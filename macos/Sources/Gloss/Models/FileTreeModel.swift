import Foundation

/// Manages the file tree sidebar state. Holds the root folder node and selected file.
@Observable
@MainActor
final class FileTreeModel {
    var rootNode: FileTreeNode?
    var selectedFileURL: URL?
    var searchQuery: String = ""

    /// Open a folder and populate the root tree node.
    func openFolder(_ url: URL) {
        let node = FileTreeNode(url: url, isDirectory: true)
        node.loadChildren()
        node.isExpanded = true
        rootNode = node
    }

    /// Close the current folder.
    func closeFolder() {
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

    /// When search is active, returns a flat list of matching file nodes.
    /// Recursively walks the tree, loading children as needed.
    var searchResults: [FileTreeNode]? {
        guard !searchQuery.isEmpty, let root = rootNode else { return nil }
        var results: [FileTreeNode] = []
        collectMatching(node: root, query: searchQuery.lowercased(), into: &results)
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
