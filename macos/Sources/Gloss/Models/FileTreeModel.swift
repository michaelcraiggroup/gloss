import Foundation

/// Manages the file tree sidebar state. Holds the root folder node and selected file.
@Observable
@MainActor
final class FileTreeModel {
    var rootNode: FileTreeNode?
    var selectedFileURL: URL?

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
}
