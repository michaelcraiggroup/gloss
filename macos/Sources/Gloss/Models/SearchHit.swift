import Foundation

/// A single full-text search hit returned by `EnhancedSearchService`.
///
/// Wraps a `LinkDatabase.FTSHitRow` with document-type detection and the
/// parsed snippet segments (so the sidebar can render highlighted matches
/// without re-scanning the body).
struct SearchHit: Identifiable, Hashable, Sendable {
    let id: Int64               // files.id — stable across a single session
    let fileURL: URL
    let fileName: String
    let title: String
    let documentType: DocumentType
    let snippet: String         // original snippet with « » delimiters
    let segments: [Segment]     // parsed snippet for styled rendering
    let rank: Double            // bm25 — lower is better
    let modifiedAt: Date

    /// A run of text in the snippet, either plain or highlighted. The sidebar
    /// renders segments via `AttributedString` so FTS5 match highlighting
    /// works without any HTML.
    struct Segment: Hashable, Sendable {
        let text: String
        let isMatch: Bool
    }

    /// Parse an FTS5 snippet string (delimited by the « and » markers we
    /// passed to the `snippet()` SQL function) into alternating plain /
    /// match segments.
    static func parseSnippet(_ raw: String) -> [Segment] {
        var segments: [Segment] = []
        var current = ""
        var inMatch = false
        for ch in raw {
            if ch == "«" {
                if !current.isEmpty {
                    segments.append(Segment(text: current, isMatch: false))
                    current = ""
                }
                inMatch = true
            } else if ch == "»" {
                if !current.isEmpty {
                    segments.append(Segment(text: current, isMatch: true))
                    current = ""
                }
                inMatch = false
            } else {
                current.append(ch)
            }
        }
        if !current.isEmpty {
            segments.append(Segment(text: current, isMatch: inMatch))
        }
        return segments
    }
}
