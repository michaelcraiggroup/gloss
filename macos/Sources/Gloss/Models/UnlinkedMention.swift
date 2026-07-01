import Foundation

/// A note that mentions the current note's title in plain text but does not
/// link to it — a suggestion surfaced in the inspector's "Unlinked Mentions"
/// section.
struct UnlinkedMention: Identifiable, Sendable, Hashable {
    let path: String
    let title: String
    let snippet: String
    var id: String { path }
}
