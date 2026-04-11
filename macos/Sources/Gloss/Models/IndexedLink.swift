import Foundation

/// A resolved link from the index, representing one file linking to another.
struct IndexedLink: Identifiable, Sendable, Hashable {
    let id: Int64
    let sourcePath: String
    let sourceTitle: String
    let targetName: String
    let targetPath: String?
    let linkType: LinkType
    let displayText: String?
    let lineNumber: Int?
    let isResolved: Bool

    /// Stable identity derived from content, not the DB row ID (which changes
    /// on every re-index). Safe for SwiftUI ForEach across refreshes.
    var stableKey: String {
        "\(sourcePath)|\(linkType.rawValue)|\(targetName)|\(lineNumber ?? -1)"
    }
}
