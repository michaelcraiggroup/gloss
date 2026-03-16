import Foundation

/// A group of backlinks sharing the same link type, for display in the inspector.
struct BacklinkGroup: Identifiable, Sendable {
    let linkType: LinkType
    let links: [IndexedLink]
    var id: String { linkType.rawValue }
}
