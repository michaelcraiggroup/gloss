import Foundation

// MARK: - Graph Data Models

/// One node in the vault graph — a single markdown file.
struct GraphNode: Sendable, Codable, Hashable, Identifiable {
    /// Stable identifier used by D3 force simulation + edge matching.
    /// We use the file path (rather than the SQLite rowID) because the rowID
    /// is not stable across a re-index.
    let id: String
    let title: String
    let path: String
    let inDegree: Int
    let outDegree: Int
    let tags: [String]
}

/// One edge in the vault graph — a resolved wiki-link.
struct GraphEdge: Sendable, Codable, Hashable {
    let source: String   // path
    let target: String   // path
    let type: String     // LinkType rawValue
}

/// The full graph payload pushed to the D3 WKWebView.
struct GraphData: Sendable, Codable {
    let nodes: [GraphNode]
    let edges: [GraphEdge]

    static let empty = GraphData(nodes: [], edges: [])
}

/// Filter configuration for the graph. All nil = "show everything".
struct GraphFilter: Sendable, Equatable {
    var tag: String? = nil
    var linkType: LinkType? = nil
    var centerPath: String? = nil
    var maxDepth: Int? = nil

    static let unfiltered = GraphFilter()
}

// MARK: - GraphService

/// Builds and caches graph data from the link index, off the main thread.
@Observable
@MainActor
final class GraphService {
    var data: GraphData = .empty
    var filter: GraphFilter = .unfiltered
    var isBuilding: Bool = false
    var lastBuiltAt: Date?

    private var buildTask: Task<Void, Never>?

    /// Rebuild the graph from the current database snapshot using the current filter.
    func refresh(database: LinkDatabase?) {
        buildTask?.cancel()
        guard let database else {
            data = .empty
            isBuilding = false
            return
        }
        isBuilding = true
        let snapshotFilter = filter

        buildTask = Task.detached { [weak self] in
            let built = Self.buildGraph(database: database, filter: snapshotFilter)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.data = built
                self.isBuilding = false
                self.lastBuiltAt = Date()
            }
        }
    }

    /// Update the filter and rebuild.
    func applyFilter(_ newFilter: GraphFilter, database: LinkDatabase?) {
        filter = newFilter
        refresh(database: database)
    }

    /// Clear the graph and cancel any in-flight build.
    func clear() {
        buildTask?.cancel()
        data = .empty
        filter = .unfiltered
        isBuilding = false
        lastBuiltAt = nil
    }

    // MARK: - Build (nonisolated, runs on background task)

    /// Build a filtered graph from the database. Pure function — safe on any actor.
    nonisolated static func buildGraph(database: LinkDatabase, filter: GraphFilter) -> GraphData {
        guard let rows = try? database.graphFiles(),
              let edgeRows = try? database.graphResolvedEdges(),
              let tagMap = try? database.graphTagsByFileId() else {
            return .empty
        }

        // Index files by id → (path, title) and by path → id
        var idToPath: [Int64: String] = [:]
        var idToTitle: [Int64: String] = [:]
        for row in rows {
            idToPath[row.id] = row.path
            idToTitle[row.id] = row.title
        }

        // Tally in/out degrees from all edges (before any filtering) so the
        // node size reflects the whole vault, not just the filtered subset.
        var inDegree: [String: Int] = [:]
        var outDegree: [String: Int] = [:]
        for edge in edgeRows {
            guard let sourcePath = idToPath[edge.sourceId],
                  let targetPath = idToPath[edge.targetId] else { continue }
            outDegree[sourcePath, default: 0] += 1
            inDegree[targetPath, default: 0] += 1
        }

        // Build the full node list.
        var allNodes: [String: GraphNode] = [:]
        for row in rows {
            let path = row.path
            let tags = tagMap[row.id] ?? []
            allNodes[path] = GraphNode(
                id: path,
                title: row.title,
                path: path,
                inDegree: inDegree[path] ?? 0,
                outDegree: outDegree[path] ?? 0,
                tags: tags
            )
        }

        // Build the full edge list (filtered by linkType if requested).
        var allEdges: [GraphEdge] = []
        for edge in edgeRows {
            guard let sourcePath = idToPath[edge.sourceId],
                  let targetPath = idToPath[edge.targetId] else { continue }
            if let typeFilter = filter.linkType, edge.linkType != typeFilter.rawValue {
                continue
            }
            allEdges.append(GraphEdge(
                source: sourcePath,
                target: targetPath,
                type: edge.linkType
            ))
        }

        // Apply tag filter — restrict to nodes that have the tag, keep edges
        // that touch at least one remaining node's neighbors (we keep edges
        // between retained nodes only, to avoid dangling endpoints).
        var retainedPaths: Set<String> = Set(allNodes.keys)
        if let tag = filter.tag {
            retainedPaths = Set(allNodes.values.compactMap { $0.tags.contains(tag) ? $0.path : nil })
        }

        // Apply center + depth filter (BFS on undirected adjacency).
        if let center = filter.centerPath, allNodes[center] != nil {
            let depth = filter.maxDepth ?? 2
            // Build undirected adjacency from ALL edges (ignoring tag filter
            // so that depth-limited expansion shows the true neighborhood).
            var adjacency: [String: Set<String>] = [:]
            for edge in allEdges {
                adjacency[edge.source, default: []].insert(edge.target)
                adjacency[edge.target, default: []].insert(edge.source)
            }
            var visited: Set<String> = [center]
            var frontier: Set<String> = [center]
            for _ in 0..<max(depth, 0) {
                var next: Set<String> = []
                for node in frontier {
                    for neighbor in adjacency[node] ?? [] where !visited.contains(neighbor) {
                        next.insert(neighbor)
                    }
                }
                visited.formUnion(next)
                frontier = next
                if frontier.isEmpty { break }
            }
            // Intersect with tag-filtered set (if any).
            retainedPaths = retainedPaths.intersection(visited)
        }

        let filteredNodes = allNodes.values
            .filter { retainedPaths.contains($0.path) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

        let filteredEdges = allEdges.filter {
            retainedPaths.contains($0.source) && retainedPaths.contains($0.target)
        }

        return GraphData(nodes: filteredNodes, edges: filteredEdges)
    }
}
