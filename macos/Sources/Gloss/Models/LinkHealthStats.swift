import Foundation

/// A snapshot of vault-wide link health.
struct LinkHealthStats: Sendable {
    let totalLinks: Int
    let brokenCount: Int

    static let empty = LinkHealthStats(totalLinks: 0, brokenCount: 0)
}
