import Foundation

/// A node in the file tree sidebar. Lazily loads children one level at a time.
@Observable
@MainActor
final class FileTreeNode: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let isDirectory: Bool
    let documentType: DocumentType

    /// nil = children not yet loaded, empty = loaded but no matching children
    var children: [FileTreeNode]?
    var isExpanded: Bool = false

    /// Folders and markdown extensions to include
    static let markdownExtensions: Set<String> = ["md", "markdown"]
    static let excludedNames: Set<String> = [
        "node_modules", ".git", ".build", ".swiftpm", "__pycache__",
        ".DS_Store", "Thumbs.db"
    ]

    init(url: URL, isDirectory: Bool, parentFolderName: String = "") {
        self.url = url
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
        self.documentType = isDirectory
            ? .folder
            : DocumentType.detect(filename: url.lastPathComponent, folderName: parentFolderName)
    }

    /// Scan one directory level, populating `children` with directories and markdown files.
    func loadChildren() {
        guard isDirectory else { return }

        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            children = []
            return
        }

        let folderName = url.lastPathComponent

        var nodes: [FileTreeNode] = []
        for itemURL in contents {
            let itemName = itemURL.lastPathComponent

            // Skip excluded names
            if Self.excludedNames.contains(itemName) { continue }

            let isDir = (try? itemURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false

            if isDir {
                nodes.append(FileTreeNode(url: itemURL, isDirectory: true))
            } else if Self.markdownExtensions.contains(itemURL.pathExtension.lowercased()) {
                nodes.append(FileTreeNode(url: itemURL, isDirectory: false, parentFolderName: folderName))
            }
        }

        // Sort: directories first, then alphabetical
        nodes.sort { a, b in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }

        children = nodes
    }

    /// Toggle expansion state, loading children on first expand.
    func toggle() {
        if isExpanded {
            isExpanded = false
        } else {
            if children == nil {
                loadChildren()
            }
            isExpanded = true
        }
    }
}
