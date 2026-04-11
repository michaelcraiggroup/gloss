import Foundation

/// A group of forward links sharing the same link type, for display in the inspector.
struct ForwardLinkGroup: Identifiable, Sendable {
    let linkType: LinkType
    let links: [IndexedLink]
    var id: String { linkType.rawValue }
}
