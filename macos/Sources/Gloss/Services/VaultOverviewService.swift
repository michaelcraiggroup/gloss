import Foundation

// MARK: - Row Models

/// A file that's heavily linked-to — a "hub" of the vault.
struct HubFile: Identifiable, Sendable, Hashable {
    let path: String
    let title: String
    let linkCount: Int
    var id: String { path }
}

/// A file with no inbound or outbound links.
struct OrphanFile: Identifiable, Sendable, Hashable {
    let path: String
    let title: String
    var id: String { path }
}

/// A recently-changed file row for the dashboard.
struct RecentFile: Identifiable, Sendable, Hashable {
    let path: String
    let title: String
    let modifiedAt: Date
    var id: String { path }
}

/// A tag with its file count, for the tag cloud.
struct TagCount: Identifiable, Sendable, Hashable {
    let tag: String
    let count: Int
    var id: String { tag }
}

// MARK: - Service

/// Aggregates vault-wide statistics from the link index and exposes them
/// to the dashboard view. All heavy work runs off-main via `Task.detached`
/// to avoid the `@MainActor`-Task-inheritance trap that bit `LinkIndex`.
@Observable
@MainActor
final class VaultOverviewService {
    var fileCount: Int = 0
    var linkCount: Int = 0
    var tagCount: Int = 0
    var brokenCount: Int = 0
    var hubs: [HubFile] = []
    var orphans: [OrphanFile] = []
    var topTags: [TagCount] = []
    var recentlyChanged: [RecentFile] = []
    var brokenLinks: [IndexedLink] = []
    var isRefreshing: Bool = false
    var lastRefreshedAt: Date?

    private var refreshTask: Task<Void, Never>?

    /// Kick off a full dashboard refresh using the given database. Runs
    /// all queries off-main, then hops back for a single atomic state swap.
    func refresh(database: LinkDatabase?) {
        guard let database else {
            clear()
            return
        }

        refreshTask?.cancel()
        isRefreshing = true

        refreshTask = Task.detached { [weak self] in
            let fileCount = (try? database.fileCount()) ?? 0
            let linkCount = (try? database.linkCount()) ?? 0
            let brokenCount = (try? database.brokenLinkCount()) ?? 0

            let allTags = (try? database.allTagCounts()) ?? []
            let topTags = allTags
                .sorted { ($0.count, $1.tag) > ($1.count, $0.tag) }
                .prefix(30)
                .map { TagCount(tag: $0.tag, count: $0.count) }

            let hubs = ((try? database.hubFiles(limit: 10)) ?? [])
                .map { HubFile(path: $0.path, title: $0.title, linkCount: $0.linkCount) }

            let orphans = ((try? database.orphanFiles()) ?? [])
                .prefix(20)
                .map { OrphanFile(path: $0.path, title: $0.title) }

            let recent = ((try? database.recentlyChangedFiles(limit: 10)) ?? [])
                .map { RecentFile(path: $0.path, title: $0.title, modifiedAt: $0.modifiedAt) }

            let broken = (try? database.brokenLinks()) ?? []

            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.fileCount = fileCount
                self.linkCount = linkCount
                self.brokenCount = brokenCount
                self.tagCount = allTags.count
                self.topTags = topTags
                self.hubs = hubs
                self.orphans = Array(orphans)
                self.recentlyChanged = recent
                self.brokenLinks = broken
                self.isRefreshing = false
                self.lastRefreshedAt = Date()
            }
        }
    }

    /// Reset all state to empty (called when the vault is closed).
    func clear() {
        refreshTask?.cancel()
        fileCount = 0
        linkCount = 0
        tagCount = 0
        brokenCount = 0
        hubs = []
        orphans = []
        topTags = []
        recentlyChanged = []
        brokenLinks = []
        isRefreshing = false
        lastRefreshedAt = nil
    }
}
