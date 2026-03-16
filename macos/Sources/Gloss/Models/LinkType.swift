import SwiftUI

/// Typed relationship between two documents via wiki-links.
enum LinkType: String, CaseIterable, Sendable, Codable {
    case related
    case supports
    case contradicts
    case extends
    case implements
    case depends
    case supersedes
    case references

    var displayName: String {
        switch self {
        case .related: "Related"
        case .supports: "Supports"
        case .contradicts: "Contradicts"
        case .extends: "Extends"
        case .implements: "Implements"
        case .depends: "Depends On"
        case .supersedes: "Supersedes"
        case .references: "References"
        }
    }

    var icon: String {
        switch self {
        case .related: "link"
        case .supports: "checkmark.seal"
        case .contradicts: "xmark.seal"
        case .extends: "arrow.up.right"
        case .implements: "hammer"
        case .depends: "arrow.triangle.branch"
        case .supersedes: "arrow.uturn.up"
        case .references: "quote.opening"
        }
    }

    /// Initialize from a raw string, defaulting to `.related` for unknown values.
    init(fromRaw raw: String) {
        self = LinkType(rawValue: raw.lowercased()) ?? .related
    }
}
