import SwiftUI

/// A single row in the file tree sidebar showing an icon and filename.
struct FileTreeRow: View {
    let node: FileTreeNode

    var body: some View {
        Label {
            Text(displayName)
                .lineLimit(1)
        } icon: {
            Text(node.documentType.icon)
        }
    }

    private var displayName: String {
        if node.isDirectory {
            return node.name
        }
        // Strip markdown extension for cleaner display
        let name = node.name
        if name.hasSuffix(".md") {
            return String(name.dropLast(3))
        }
        if name.hasSuffix(".markdown") {
            return String(name.dropLast(9))
        }
        return name
    }
}
