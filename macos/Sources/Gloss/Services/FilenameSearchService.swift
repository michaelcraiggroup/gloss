import Foundation

/// A filename hit for the sidebar's Filenames search scope.
struct FilenameHit: Identifiable, Sendable, Hashable {
    let path: String
    let title: String
    let filename: String
    var id: String { path }
    var fileURL: URL { URL(fileURLWithPath: path) }
}

/// Debounced filename search over the link index's `files` table.
///
/// Replaces the old synchronous whole-tree walk (`FileTreeModel.searchResults`),
/// which force-loaded every directory of the vault on the main thread during
/// view-body evaluation — and, by loading the tree, permanently unbounded the
/// cost of every subsequent reconcile pass.
@Observable
@MainActor
final class FilenameSearchService {
    /// nil = search inactive (empty query / still debouncing); [] = no matches.
    var results: [FilenameHit]?

    private var searchTask: Task<Void, Never>?
    nonisolated private static let maxResults = 200
    nonisolated private static let debounceNanoseconds: UInt64 = 150_000_000 // 150ms

    /// Run (or re-run) a filename search. Cancels any in-flight task and
    /// debounces briefly so fast typing doesn't thrash the database.
    func search(query: String, database: LinkDatabase?) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard let database, !trimmed.isEmpty else {
            results = nil
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceNanoseconds)
            guard !Task.isCancelled, let self else { return }
            let hits = await Self.runSearch(query: trimmed, database: database)
            guard !Task.isCancelled else { return }
            self.results = hits
        }
    }

    /// Cancel any in-flight search and deactivate results.
    func cancel() {
        searchTask?.cancel()
        results = nil
    }

    /// Pure matching over file rows — matches against the full filename
    /// (including extension), case-insensitively, preserving the row order
    /// (title-sorted from the query).
    nonisolated static func matches(
        rows: [LinkDatabase.FileListRow],
        query: String,
        limit: Int = maxResults
    ) -> [FilenameHit] {
        var hits: [FilenameHit] = []
        for row in rows {
            let filename = URL(fileURLWithPath: row.path).lastPathComponent
            if filename.localizedCaseInsensitiveContains(query) {
                hits.append(FilenameHit(path: row.path, title: row.title, filename: filename))
                if hits.count >= limit { break }
            }
        }
        return hits
    }

    nonisolated private static func runSearch(
        query: String,
        database: LinkDatabase
    ) async -> [FilenameHit] {
        let rows = (try? database.allFiles()) ?? []
        return matches(rows: rows, query: query)
    }
}
