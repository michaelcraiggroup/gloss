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

    /// Delete a file and its associated links/tags (cascading).
    func deleteFile(path: String) throws {
        try dbQueue.write { db in
            try db.execute(sql: "DELETE FROM files WHERE path = ?", arguments: [path])
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
            // Get file ID and title for the target file
            guard let targetRow = try Row.fetchOne(db, sql: "SELECT id, title FROM files WHERE path = ?", arguments: [path]) else {
                return []
            }
            let targetId: Int64 = targetRow["id"]
            let targetTitle: String = targetRow["title"]

            // Find links that point to this file by ID or by name
            let rows = try Row.fetchAll(db, sql: """
                SELECT l.id, f.path AS sourcePath, f.title AS sourceTitle,
                       l.targetName, l.linkType, l.displayText, l.lineNumber
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
                    linkType: LinkType(fromRaw: row["linkType"]),
                    displayText: row["displayText"],
                    lineNumber: row["lineNumber"]
                )
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
}
