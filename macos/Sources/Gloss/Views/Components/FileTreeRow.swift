import SwiftUI

/// A single row in the file tree sidebar showing an icon and filename.
struct FileTreeRow: View {
    let node: FileTreeNode

    private static let tooltipFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Label {
            Text(displayName)
                .lineLimit(1)
        } icon: {
            Text(node.documentType.icon)
        }
        .help(tooltip)
    }

    private var tooltip: String {
        guard let date = node.modificationDate else { return node.name }
        return "Modified: \(Self.tooltipFormatter.string(from: date))"
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
