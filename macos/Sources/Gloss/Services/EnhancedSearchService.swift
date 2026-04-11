import Foundation

/// Full-text search service backed by the SQLite FTS5 virtual table living
/// inside the link index. Replaces the earlier line-scanning
/// `ContentSearchService` — rather than re-reading every file on every
/// keystroke, `LinkIndex` has already indexed each file's raw body into
/// `files_fts` at build time, so this service is a thin debounced wrapper
/// over `LinkDatabase.searchFTS(...)`.
///
/// Filters:
/// - `tagFilter` narrows to files tagged with the given tag (server-side)
/// - `documentTypeFilter` narrows to a single `DocumentType` (client-side,
///   since doc type is derived from path conventions rather than stored)
/// - `dateRange` narrows by modifiedAt
@Observable
@MainActor
final class EnhancedSearchService {
    var results: [SearchHit] = []
    var isSearching: Bool = false

    /// Currently active filters — the sidebar binds chips to these and calls
    /// `rerun()` after mutating them.
    var tagFilter: String? = nil
    var documentTypeFilter: DocumentType? = nil
    var dateRange: ClosedRange<Date>? = nil

    private var searchTask: Task<Void, Never>?
    private var lastQuery: String = ""
    nonisolated private static let maxResults = 60
    nonisolated private static let debounceNanoseconds: UInt64 = 250_000_000 // 250ms

    /// Run (or re-run) a search. Cancels any in-flight task and debounces by
    /// 250ms so fast typing doesn't thrash the database.
    func search(query: String, database: LinkDatabase?) {
        lastQuery = query
        searchTask?.cancel()

        guard let database, !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            isSearching = false
            return
        }

        isSearching = true

        let tag = tagFilter
        let range = dateRange
        let docType = documentTypeFilter

        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceNanoseconds)
            guard !Task.isCancelled, let self else { return }

            let hits = await Self.runSearch(
                query: query,
                database: database,
                tag: tag,
                dateRange: range,
                documentType: docType
            )
            guard !Task.isCancelled else { return }

            self.results = hits
            self.isSearching = false
        }
    }

    /// Re-run the last query against the current filter state. Used by the
    /// filter chip UI so flipping a chip refreshes the results.
    func rerun(database: LinkDatabase?) {
        search(query: lastQuery, database: database)
    }

    /// Cancel any in-flight search and clear results.
    func cancel() {
        searchTask?.cancel()
        results = []
        isSearching = false
    }

    /// Clear all filters without dropping the current query.
    func clearFilters() {
        tagFilter = nil
        documentTypeFilter = nil
        dateRange = nil
    }

    var hasActiveFilters: Bool {
        tagFilter != nil || documentTypeFilter != nil || dateRange != nil
    }

    // MARK: - Private

    /// Execute the FTS query off-main. The function is `nonisolated static`
    /// so it can run inside a detached task without inheriting main-actor
    /// isolation.
    private nonisolated static func runSearch(
        query: String,
        database: LinkDatabase,
        tag: String?,
        dateRange: ClosedRange<Date>?,
        documentType: DocumentType?
    ) async -> [SearchHit] {
        let rows: [LinkDatabase.FTSHitRow]
        do {
            rows = try database.searchFTS(
                query: query,
                tag: tag,
                dateRange: dateRange,
                limit: Self.maxResults
            )
        } catch {
            return []
        }

        return rows.compactMap { row in
            let url = URL(fileURLWithPath: row.path)
            let fileName = url.lastPathComponent
            let parentFolder = url.deletingLastPathComponent().lastPathComponent
            let docType = DocumentType.detect(filename: fileName, folderName: parentFolder)

            // Client-side doc type filter: FTS5 doesn't know about our
            // DocumentType taxonomy, which is derived from filename + parent
            // folder heuristics. Skip rows that don't match when a filter is
            // active.
            if let documentType, docType != documentType {
                return nil
            }

            return SearchHit(
                id: row.fileId,
                fileURL: url,
                fileName: fileName,
                title: row.title,
                documentType: docType,
                snippet: row.snippet,
                segments: SearchHit.parseSnippet(row.snippet),
                rank: row.rank,
                modifiedAt: row.modifiedAt
            )
        }
    }
}
