import Foundation

/// A resolved link from the index, representing one file linking to another.
struct IndexedLink: Identifiable, Sendable {
    let id: Int64
    let sourcePath: String
    let sourceTitle: String
    let targetName: String
    let linkType: LinkType
    let displayText: String?
    let lineNumber: Int?
}
