import Foundation
import GlossKit

/// Platform-neutral read/render pipeline shared by both app shells.
///
/// The pure statics are the extracted (previously view-private, untested)
/// resolution semantics from DocumentView: wiki-link candidate generation,
/// same-directory-then-index resolution order, and the main-thread snapshot
/// building that makes background rendering Sendable-safe. macOS
/// DocumentView calls the statics and keeps its own view-state machine; the
/// iOS ReaderScreen owns an instance as its view model.
@Observable
@MainActor
final class DocumentRenderModel {
    // MARK: - Published render state (instance use — iOS shell)

    private(set) var fileContent: String?
    private(set) var renderedHTML: String?
    private(set) var renderURL: URL?
    /// True from render() until its HTML is published (or it is cancelled).
    /// Shells own their spinner choreography on top of this.
    private(set) var isRendering = false
    /// Wiki-link targets that failed to resolve in the last render — probe
    /// again on `.glossIndexUpdated` so links to just-indexed notes light up
    /// without re-rendering on every index tick.
    private(set) var unresolvedWikiTargets: [String] = []

    /// Supplies the current link database (main-actor state owned by
    /// LinkIndex) at render time — injected so the model has no LinkIndex
    /// dependency and tests can hand it a fixture database.
    var database: () -> LinkDatabase?

    private var renderTask: Task<Void, Never>?

    init(database: @escaping () -> LinkDatabase? = { nil }) {
        self.database = database
    }

    /// Read the file, publish `fileContent`, and post `.glossDocumentLoaded`
    /// (the inspector's heading/frontmatter feed). Returns false on read
    /// failure, leaving `fileContent` nil.
    @discardableResult
    func load(url: URL) -> Bool {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            fileContent = content
            NotificationCenter.default.post(name: .glossDocumentLoaded, object: content)
            return true
        } catch {
            fileContent = nil
            return false
        }
    }

    /// Render `content` for `url` off the main thread, cancelling any
    /// in-flight render. Mirrors DocumentView.renderAsync: snapshots are
    /// built on the main actor first, and an identical re-render publishes
    /// only `renderURL` — the WebView reloads only when HTML actually
    /// changes, so waiting on a load event for identical HTML would strand
    /// a spinner forever (#40).
    @discardableResult
    func render(_ content: String, url: URL, isDark: Bool, fontSize: Int) -> Task<Void, Never> {
        renderTask?.cancel()
        isRendering = true

        let db = database()
        let (wikiLinkMap, unresolved) = Self.buildWikiLinkSnapshot(
            for: content, from: url, database: db)
        unresolvedWikiTargets = unresolved
        let embedMap = Self.buildEmbedSnapshot(for: content, from: url, database: db)

        let task = Task.detached(priority: .userInitiated) { [weak self] in
            guard !Task.isCancelled else { return }
            let rendered = MarkdownRenderer.render(
                content,
                isDark: isDark,
                fontSize: fontSize,
                resolveWikiLink: wikiLinkMap.isEmpty ? nil : { target in
                    wikiLinkMap[target.lowercased()]
                },
                resolveQuery: db.map { database in
                    { query in (try? database.runQuery(query)) ?? [] }
                },
                resolveEmbed: embedMap.isEmpty ? nil : { target, heading in
                    guard let embedURL = embedMap[target.lowercased()],
                          let raw = try? String(contentsOf: embedURL, encoding: .utf8)
                    else { return nil }
                    if let heading {
                        return MarkdownRenderer.extractSection(raw, heading: heading)
                    }
                    return raw
                }
            )
            guard !Task.isCancelled else { return }
            let html = GuideInjector.injectGuideSDK(into: rendered)
            await MainActor.run { [weak self] in
                guard let self, !Task.isCancelled else { return }
                if html != self.renderedHTML {
                    self.renderedHTML = html
                }
                self.renderURL = url
                self.isRendering = false
            }
        }
        renderTask = task
        return task
    }

    /// Cancel any in-flight render (e.g. the document changed or the reader
    /// left the screen).
    func cancel() {
        renderTask?.cancel()
        renderTask = nil
        isRendering = false
    }

    // MARK: - Pure pipeline statics (macOS DocumentView calls these)

    /// Generate candidate filenames for a wiki-link target.
    nonisolated static func wikiLinkCandidates(for target: String) -> [String] {
        let trimmed = target.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix(".md") || trimmed.hasSuffix(".markdown") {
            return [trimmed]
        }
        return ["\(trimmed).md", "\(trimmed).markdown", trimmed]
    }

    /// Resolve a wiki-link target to a file URL string: same-directory
    /// candidates first, then the link index. (The old fallback BFS-walked
    /// the sidebar tree, force-loading every directory in the vault on the
    /// main thread — and one unresolvable link loaded all of it.)
    nonisolated static func resolveWikiLink(
        _ target: String,
        from currentFile: URL,
        database: LinkDatabase?
    ) -> String? {
        let directory = currentFile.deletingLastPathComponent()

        // Same folder first
        for candidate in wikiLinkCandidates(for: target) {
            let url = directory.appendingPathComponent(candidate)
            if FileManager.default.fileExists(atPath: url.path) {
                return url.absoluteString
            }
        }

        // Then the link index — titles are stored extension-less.
        var bare = target.trimmingCharacters(in: .whitespaces)
        if bare.hasSuffix(".md") {
            bare = String(bare.dropLast(3))
        } else if bare.hasSuffix(".markdown") {
            bare = String(bare.dropLast(9))
        }
        if let database, let path = ((try? database.pathForWikiTarget(bare)) ?? nil) {
            return URL(fileURLWithPath: path).absoluteString
        }

        return nil
    }

    /// Scans the markdown source for [[wiki-link]] patterns and resolves them
    /// up-front (on the caller's thread — main, for @MainActor database
    /// owners), producing a Sendable snapshot for background rendering — plus
    /// the list of targets that could not be resolved.
    nonisolated static func buildWikiLinkSnapshot(
        for content: String,
        from url: URL,
        database: LinkDatabase?
    ) -> (map: [String: String], unresolved: [String]) {
        guard content.contains("[[") else { return ([:], []) }
        var map: [String: String] = [:]
        var unresolved: Set<String> = []
        let pattern = try? NSRegularExpression(pattern: #"\[\[([^\]]+)\]\]"#)
        let range = NSRange(content.startIndex..., in: content)
        pattern?.enumerateMatches(in: content, options: [], range: range) { match, _, _ in
            guard let match, let r = Range(match.range(at: 1), in: content) else { return }
            // Strip type suffix (::type) and display text (|label)
            let raw = String(content[r])
            let withoutType = raw.components(separatedBy: "::").first ?? raw
            let target = (withoutType.components(separatedBy: "|").first ?? withoutType)
                .trimmingCharacters(in: .whitespaces)
            let key = target.lowercased()
            guard map[key] == nil else { return }
            if let resolved = resolveWikiLink(target, from: url, database: database) {
                map[key] = resolved
                unresolved.remove(key)
            } else {
                unresolved.insert(key)
            }
        }
        return (map, Array(unresolved))
    }

    /// Pre-resolve `![[embed]]` targets to file URLs (mirrors
    /// `buildWikiLinkSnapshot`). The off-main render reads each file.
    nonisolated static func buildEmbedSnapshot(
        for content: String,
        from url: URL,
        database: LinkDatabase?
    ) -> [String: URL] {
        guard content.contains("![[") else { return [:] }
        var map: [String: URL] = [:]
        let pattern = try? NSRegularExpression(pattern: #"!\[\[([^\]]+)\]\]"#)
        let range = NSRange(content.startIndex..., in: content)
        pattern?.enumerateMatches(in: content, options: [], range: range) { match, _, _ in
            guard let match, let r = Range(match.range(at: 1), in: content) else { return }
            let inner = String(content[r])
            let target = (inner.components(separatedBy: "#").first ?? inner)
                .trimmingCharacters(in: .whitespaces)
            if map[target.lowercased()] == nil,
               let resolved = resolveWikiLink(target, from: url, database: database),
               let resolvedURL = URL(string: resolved) {
                map[target.lowercased()] = resolvedURL
            }
        }
        return map
    }
}
