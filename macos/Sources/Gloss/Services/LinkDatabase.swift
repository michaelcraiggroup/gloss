import Foundation
import GRDB

/// Sendable database layer for the link index. Wraps a GRDB `DatabaseQueue`
/// stored at `.gloss/index.sqlite` in the vault root.
struct LinkDatabase: Sendable {
    let dbQueue: DatabaseQueue

    /// Open (or create) the index database at `.gloss/index.sqlite` under the given root.
    init(rootURL: URL) throws {
        let glossDir = rootURL.appendingPathComponent(".gloss")
        try FileManager.default.createDirectory(at: glossDir, withIntermediateDirectories: true)
        let dbPath = glossDir.appendingPathComponent("index.sqlite").path
        dbQueue = try DatabaseQueue(path: dbPath)
        try migrate()
    }

    /// In-memory database for testing.
    init() throws {
        dbQueue = try DatabaseQueue()
        try migrate()
    }

    // MARK: - Migration

    private func migrate() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "files") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("path", .text).notNull().unique()
                t.column("title", .text).notNull()
                t.column("modifiedAt", .double).notNull()
                t.column("indexedAt", .double).notNull()
            }

            try db.create(table: "links") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("sourceFileId", .integer).notNull()
                    .references("files", onDelete: .cascade)
                t.column("targetName", .text).notNull()
                t.column("targetFileId", .integer)
                    .references("files", onDelete: .setNull)
                t.column("linkType", .text).notNull().defaults(to: "related")
                t.column("displayText", .text)
                t.column("lineNumber", .integer)
                t.column("isResolved", .boolean).notNull().defaults(to: false)
            }

            try db.create(table: "tags") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("fileId", .integer).notNull()
                    .references("files", onDelete: .cascade)
                t.column("tag", .text).notNull()
            }
        }

        // WS5 — Enhanced Search: add FTS5 virtual table for full-text search
        // over file titles and bodies. Uses porter stemming over unicode61
        // tokenization for case-insensitive, punctuation-safe indexing.
        // `rowid` is explicitly set to `files.id` so we can JOIN on it when
        // returning hits, and so `deleteFile` can cascade manually.
        migrator.registerMigration("v2_fts5") { db in
            try db.create(virtualTable: "files_fts", using: FTS5()) { t in
                t.tokenizer = .porter(wrapping: .unicode61())
                t.column("title")
                t.column("body")
            }
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - File CRUD

    /// Insert or update a file record, returning its row ID.
    @discardableResult
    func upsertFile(path: String, title: String, modifiedAt: Date) throws -> Int64 {
        try dbQueue.write { db in
            let now = Date().timeIntervalSince1970
            let modified = modifiedAt.timeIntervalSince1970

            if let row = try Row.fetchOne(db, sql: "SELECT id FROM files WHERE path = ?", arguments: [path]) {
                let fileId: Int64 = row["id"]
                try db.execute(
                    sql: "UPDATE files SET title = ?, modifiedAt = ?, indexedAt = ? WHERE id = ?",
                    arguments: [title, modified, now, fileId]
                )
                return fileId
            } else {
                try db.execute(
                    sql: "INSERT INTO files (path, title, modifiedAt, indexedAt) VALUES (?, ?, ?, ?)",
                    arguments: [path, title, modified, now]
                )
                return db.lastInsertedRowID
            }
        }
    }

    /// Delete a file and its associated links/tags/FTS row (cascading).
    /// FTS5 virtual tables don't participate in foreign-key cascades, so the
    /// `files_fts` row has to be removed explicitly by rowid.
    func deleteFile(path: String) throws {
        try dbQueue.write { db in
            if let fileId: Int64 = try Row.fetchOne(db, sql: "SELECT id FROM files WHERE path = ?", arguments: [path])?["id"] {
                try db.execute(sql: "DELETE FROM files_fts WHERE rowid = ?", arguments: [fileId])
                try db.execute(sql: "DELETE FROM files WHERE id = ?", arguments: [fileId])
            }
        }
    }

    /// Get the indexed-at timestamp for a file, or nil if not indexed.
    func fileIndexedAt(path: String) throws -> Date? {
        try dbQueue.read { db in
            if let row = try Row.fetchOne(db, sql: "SELECT indexedAt FROM files WHERE path = ?", arguments: [path]) {
                let timestamp: Double = row["indexedAt"]
                return Date(timeIntervalSince1970: timestamp)
            }
            return nil
        }
    }

    /// Get the file ID for a given path.
    func fileId(forPath path: String) throws -> Int64? {
        try dbQueue.read { db in
            if let row = try Row.fetchOne(db, sql: "SELECT id FROM files WHERE path = ?", arguments: [path]) {
                return row["id"] as Int64
            }
            return nil
        }
    }

    /// Remove files from the index that no longer exist on disk.
    func removeStaleFiles(existingPaths: Set<String>) throws {
        try dbQueue.write { db in
            let allFiles = try Row.fetchAll(db, sql: "SELECT id, path FROM files")
            for row in allFiles {
                let path: String = row["path"]
                if !existingPaths.contains(path) {
                    let fileId: Int64 = row["id"]
                    try db.execute(sql: "DELETE FROM files_fts WHERE rowid = ?", arguments: [fileId])
                    try db.execute(sql: "DELETE FROM files WHERE id = ?", arguments: [fileId])
                }
            }
        }
    }

    // MARK: - Links CRUD

    /// Replace all links for a file with new ones.
    func replaceLinks(fileId: Int64, links: [(targetName: String, linkType: String, displayText: String?, lineNumber: Int)]) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM links WHERE sourceFileId = ?", arguments: [fileId])

            for link in links {
                // Try to resolve target to an existing file
                let targetFileId: Int64? = try Row.fetchOne(
                    db,
                    sql: "SELECT id FROM files WHERE title = ? OR path LIKE ?",
                    arguments: [link.targetName, "%/\(link.targetName).md"]
                )?["id"]

                try db.execute(
                    sql: """
                        INSERT INTO links (sourceFileId, targetName, targetFileId, linkType, displayText, lineNumber, isResolved)
                        VALUES (?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [fileId, link.targetName, targetFileId, link.linkType, link.displayText, link.lineNumber, targetFileId != nil]
                )
            }
        }
    }

    /// Re-resolve all links in the index (e.g., after a file rename or new file).
    func resolveAllLinks() throws {
        try dbQueue.write { db in
            // Reset all resolutions
            try db.execute(sql: "UPDATE links SET targetFileId = NULL, isResolved = 0")

            // Re-resolve by matching targetName to file titles or paths
            try db.execute(sql: """
                UPDATE links SET
                    targetFileId = (
                        SELECT f.id FROM files f
                        WHERE f.title = links.targetName
                           OR f.path LIKE '%/' || links.targetName || '.md'
                        LIMIT 1
                    ),
                    isResolved = CASE
                        WHEN (SELECT f.id FROM files f
                              WHERE f.title = links.targetName
                                 OR f.path LIKE '%/' || links.targetName || '.md'
                              LIMIT 1) IS NOT NULL THEN 1
                        ELSE 0
                    END
                """)
        }
    }

    // MARK: - Tags CRUD

    /// Replace all tags for a file.
    func replaceTags(fileId: Int64, tags: [String]) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM tags WHERE fileId = ?", arguments: [fileId])
            for tag in tags {
                try db.execute(
                    sql: "INSERT INTO tags (fileId, tag) VALUES (?, ?)",
                    arguments: [fileId, tag]
                )
            }
        }
    }

    // MARK: - Tag Queries

    /// All unique tags in the vault with their file counts, sorted alphabetically.
    func allTagCounts() throws -> [(tag: String, count: Int)] {
        try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT tag, COUNT(*) AS cnt FROM tags GROUP BY tag ORDER BY tag COLLATE NOCASE"
            ).map { row in
                (tag: row["tag"] as String, count: row["cnt"] as Int)
            }
        }
    }

    /// All tags for a specific file.
    func tags(forFileId fileId: Int64) throws -> [String] {
        try dbQueue.read { db in
            try String.fetchAll(
                db,
                sql: "SELECT tag FROM tags WHERE fileId = ? ORDER BY tag COLLATE NOCASE",
                arguments: [fileId]
            )
        }
    }

    /// All files that have a specific tag.
    func files(forTag tag: String) throws -> [(path: String, title: String)] {
        try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT f.path, f.title FROM files f
                    JOIN tags t ON t.fileId = f.id
                    WHERE t.tag = ?
                    ORDER BY f.title COLLATE NOCASE
                    """,
                arguments: [tag]
            ).map { row in
                (path: row["path"] as String, title: row["title"] as String)
            }
        }
    }

    // MARK: - Queries

    /// Fetch backlinks for a file at the given path — other files that link TO this file.
    func backlinks(forPath path: String) throws -> [IndexedLink] {
        try dbQueue.read { db in
            // Get file ID, title, and path for the target file
            guard let targetRow = try Row.fetchOne(db, sql: "SELECT id, title, path FROM files WHERE path = ?", arguments: [path]) else {
                return []
            }
            let targetId: Int64 = targetRow["id"]
            let targetTitle: String = targetRow["title"]
            let targetPath: String = targetRow["path"]

            // Find links that point to this file by ID or by name
            let rows = try Row.fetchAll(db, sql: """
                SELECT l.id, f.path AS sourcePath, f.title AS sourceTitle,
                       l.targetName, l.linkType, l.displayText, l.lineNumber, l.isResolved
                FROM links l
                JOIN files f ON f.id = l.sourceFileId
                WHERE l.targetFileId = ? OR l.targetName = ?
                ORDER BY l.linkType, f.title
                """, arguments: [targetId, targetTitle])

            return rows.map { row in
                IndexedLink(
                    id: row["id"],
                    sourcePath: row["sourcePath"],
                    sourceTitle: row["sourceTitle"],
                    targetName: row["targetName"],
                    targetPath: targetPath,
                    linkType: LinkType(fromRaw: row["linkType"]),
                    displayText: row["displayText"],
                    lineNumber: row["lineNumber"],
                    isResolved: (row["isResolved"] as Bool?) ?? true
                )
            }
        }
    }

    /// Fetch forward links for a file — links FROM this file pointing to other files (resolved or not).
    func forwardLinks(forPath path: String) throws -> [IndexedLink] {
        try dbQueue.read { db in
            guard let sourceRow = try Row.fetchOne(db, sql: "SELECT id, title FROM files WHERE path = ?", arguments: [path]) else {
                return []
            }
            let sourceId: Int64 = sourceRow["id"]
            let sourceTitle: String = sourceRow["title"]

            let rows = try Row.fetchAll(db, sql: """
                SELECT l.id, l.targetName, l.linkType, l.displayText, l.lineNumber, l.isResolved,
                       tf.path AS targetPath
                FROM links l
                LEFT JOIN files tf ON tf.id = l.targetFileId
                WHERE l.sourceFileId = ?
                ORDER BY l.linkType, l.targetName
                """, arguments: [sourceId])

            return rows.map { row in
                IndexedLink(
                    id: row["id"],
                    sourcePath: path,
                    sourceTitle: sourceTitle,
                    targetName: row["targetName"],
                    targetPath: row["targetPath"],
                    linkType: LinkType(fromRaw: row["linkType"]),
                    displayText: row["displayText"],
                    lineNumber: row["lineNumber"],
                    isResolved: (row["isResolved"] as Bool?) ?? false
                )
            }
        }
    }

    /// Count of unresolved (broken) links across the vault.
    func brokenLinkCount() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM links WHERE isResolved = 0") ?? 0
        }
    }

    /// All broken links across the vault, joined with source file info for navigation.
    func brokenLinks() throws -> [IndexedLink] {
        try dbQueue.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT l.id, f.path AS sourcePath, f.title AS sourceTitle,
                       l.targetName, l.linkType, l.displayText, l.lineNumber
                FROM links l
                JOIN files f ON f.id = l.sourceFileId
                WHERE l.isResolved = 0
                ORDER BY f.title, l.lineNumber
                """)
            return rows.map { row in
                IndexedLink(
                    id: row["id"],
                    sourcePath: row["sourcePath"],
                    sourceTitle: row["sourceTitle"],
                    targetName: row["targetName"],
                    targetPath: nil,
                    linkType: LinkType(fromRaw: row["linkType"]),
                    displayText: row["displayText"],
                    lineNumber: row["lineNumber"],
                    isResolved: false
                )
            }
        }
    }

    /// Files with no inbound and no outbound links.
    func orphanFiles() throws -> [(path: String, title: String)] {
        try dbQueue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT f.path, f.title FROM files f
                WHERE NOT EXISTS (SELECT 1 FROM links l WHERE l.sourceFileId = f.id)
                  AND NOT EXISTS (SELECT 1 FROM links l WHERE l.targetFileId = f.id)
                ORDER BY f.title COLLATE NOCASE
                """).map { row in
                    (path: row["path"] as String, title: row["title"] as String)
                }
        }
    }

    /// Files with the most resolved inbound links — the "hubs" of the vault.
    func hubFiles(limit: Int = 10) throws -> [(path: String, title: String, linkCount: Int)] {
        try dbQueue.read { db in
            try Row.fetchAll(db, sql: """
                SELECT f.path, f.title, COUNT(l.id) AS cnt
                FROM files f
                JOIN links l ON l.targetFileId = f.id
                GROUP BY f.id
                ORDER BY cnt DESC, f.title COLLATE NOCASE
                LIMIT ?
                """, arguments: [limit]).map { row in
                    (path: row["path"] as String,
                     title: row["title"] as String,
                     linkCount: row["cnt"] as Int)
                }
        }
    }

    /// Fetch the most recently modified files from the index.
    func recentlyChangedFiles(limit: Int = 15) throws -> [(path: String, title: String, modifiedAt: Date)] {
        try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT path, title, modifiedAt FROM files ORDER BY modifiedAt DESC LIMIT ?",
                arguments: [limit]
            ).map { row in
                let timestamp: Double = row["modifiedAt"]
                return (
                    path: row["path"] as String,
                    title: row["title"] as String,
                    modifiedAt: Date(timeIntervalSince1970: timestamp)
                )
            }
        }
    }

    /// Count total indexed files.
    func fileCount() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM files") ?? 0
        }
    }

    /// Count total indexed links.
    func linkCount() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM links") ?? 0
        }
    }

    // MARK: - Graph Queries

    /// Row type for graph node fetches.
    struct GraphFileRow: Sendable {
        let id: Int64
        let path: String
        let title: String
    }

    /// Row type for resolved edges in the graph.
    struct GraphEdgeRow: Sendable {
        let sourceId: Int64
        let targetId: Int64
        let linkType: String
    }

    /// Fetch every file in the vault as a graph node candidate.
    func graphFiles() throws -> [GraphFileRow] {
        try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: "SELECT id, path, title FROM files ORDER BY title COLLATE NOCASE"
            ).map { row in
                GraphFileRow(
                    id: row["id"],
                    path: row["path"],
                    title: row["title"]
                )
            }
        }
    }

    /// Fetch every resolved link as a graph edge. Drops unresolved (broken)
    /// links — those have no target node to connect to.
    func graphResolvedEdges() throws -> [GraphEdgeRow] {
        try dbQueue.read { db in
            try Row.fetchAll(
                db,
                sql: """
                    SELECT sourceFileId, targetFileId, linkType
                    FROM links
                    WHERE isResolved = 1 AND targetFileId IS NOT NULL
                    """
            ).map { row in
                GraphEdgeRow(
                    sourceId: row["sourceFileId"],
                    targetId: row["targetFileId"],
                    linkType: row["linkType"]
                )
            }
        }
    }

    /// Fetch tags grouped by file id, for enriching graph nodes without
    /// issuing one query per file.
    func graphTagsByFileId() throws -> [Int64: [String]] {
        try dbQueue.read { db in
            var result: [Int64: [String]] = [:]
            let rows = try Row.fetchAll(db, sql: "SELECT fileId, tag FROM tags")
            for row in rows {
                let fid: Int64 = row["fileId"]
                let tag: String = row["tag"]
                result[fid, default: []].append(tag)
            }
            return result
        }
    }

    // MARK: - Full-Text Search (WS5, FTS5)

    /// Raw hit returned by `searchFTS`. Not the public search hit model — the
    /// service layer wraps this in `SearchHit` after decorating with file
    /// metadata.
    struct FTSHitRow: Sendable {
        let fileId: Int64
        let path: String
        let title: String
        let snippet: String   // contains « » delimiters around matched tokens
        let rank: Double      // bm25 — lower is better
        let modifiedAt: Date
    }

    /// Index (or re-index) the full body text of a file for full-text search.
    /// Uses `files.id` as the FTS5 rowid so we can cascade deletions and JOIN
    /// back to file metadata on read.
    func indexFileContent(fileId: Int64, title: String, body: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "INSERT OR REPLACE INTO files_fts(rowid, title, body) VALUES (?, ?, ?)",
                arguments: [fileId, title, body]
            )
        }
    }

    /// Clear the FTS5 table — used when reindexing an entire vault to avoid
    /// orphan rows on rename.
    func clearFTS() throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM files_fts")
        }
    }

    /// Run a full-text search. Returns hits ranked by BM25 (lower = better),
    /// with a highlighted snippet (« » delimit matched tokens). Optional
    /// filters narrow to files tagged with `tag` and/or modified within
    /// `dateRange`. Empty / whitespace queries return an empty result.
    func searchFTS(
        query: String,
        tag: String? = nil,
        dateRange: ClosedRange<Date>? = nil,
        limit: Int = 50
    ) throws -> [FTSHitRow] {
        // FTS5Pattern sanitizes the query — returns nil for queries that are
        // pure punctuation or otherwise can't form a valid pattern.
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty,
              let pattern = FTS5Pattern(matchingAllPrefixesIn: trimmed) else {
            return []
        }

        return try dbQueue.read { db in
            var sql = """
                SELECT f.id AS fileId, f.path, f.title, f.modifiedAt,
                       bm25(files_fts) AS rank,
                       snippet(files_fts, 1, '«', '»', '…', 24) AS snippet
                FROM files_fts
                JOIN files f ON f.id = files_fts.rowid
                WHERE files_fts MATCH ?
                """
            var arguments: [(any DatabaseValueConvertible)?] = [pattern]

            if let tag {
                sql += " AND f.id IN (SELECT fileId FROM tags WHERE tag = ?)"
                arguments.append(tag)
            }

            if let dateRange {
                sql += " AND f.modifiedAt BETWEEN ? AND ?"
                arguments.append(dateRange.lowerBound.timeIntervalSince1970)
                arguments.append(dateRange.upperBound.timeIntervalSince1970)
            }

            sql += " ORDER BY rank LIMIT ?"
            arguments.append(limit)

            let rows = try Row.fetchAll(
                db, sql: sql,
                arguments: StatementArguments(arguments)
            )

            return rows.map { row in
                FTSHitRow(
                    fileId: row["fileId"],
                    path: row["path"],
                    title: row["title"],
                    snippet: row["snippet"],
                    rank: row["rank"],
                    modifiedAt: Date(timeIntervalSince1970: row["modifiedAt"])
                )
            }
        }
    }

    /// Count of rows currently in the FTS5 index — used by tests and
    /// diagnostics.
    func ftsRowCount() throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM files_fts") ?? 0
        }
    }
}
