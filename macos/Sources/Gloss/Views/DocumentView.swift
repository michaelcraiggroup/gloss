import SwiftUI
import GlossKit

/// Loads and renders a markdown file, responding to theme changes and file modifications.
/// Supports read mode (rendered HTML) and edit mode (CodeMirror 6 editor).
struct DocumentView: View {
    let fileURL: URL?
    var highlightQuery: String?
    @Binding var isEditing: Bool
    @Binding var isEditorDirty: Bool
    @EnvironmentObject private var settings: AppSettings
    @Environment(FileTreeModel.self) private var fileTree
    @Environment(StoreManager.self) private var store
    @Environment(TemplateFillService.self) private var templateFill
    @Environment(LinkIndex.self) private var linkIndex
    @Environment(\.colorScheme) private var colorScheme
    @State private var fileContent: String?
    @State private var renderedHTML: String?
    @State private var renderURL: URL?
    @State private var fileWatcher = FileWatcher()
    @State private var isLoading = false
    @State private var renderTask: Task<Void, Never>?
    @State private var loadingForURL: URL?
    /// Wiki-link targets that failed to resolve in the last render — checked
    /// again when the index updates so links to just-indexed notes light up.
    @State private var unresolvedWikiTargets: [String] = []

    var body: some View {
        ZStack {
            Group {
                if let url = fileURL {
                    if isEditing {
                        EditorWebView(
                            fileURL: url,
                            isDark: colorScheme == .dark,
                            fontSize: settings.fontSize,
                            wikiTargets: linkIndex.allTitles
                        )
                    } else if let html = renderedHTML, let content = fileContent, renderURL == url {
                        WebView(
                            htmlContent: html,
                            baseURL: url.deletingLastPathComponent(),
                            highlightQuery: highlightQuery,
                            rawMarkdown: content
                        )
                    } else if !isLoading && loadingForURL == fileURL {
                        errorState(message: "Could not read file:\n\(url.lastPathComponent)")
                    }
                } else {
                    emptyState
                }
            }

            if isLoading && !isEditing {
                ProgressView()
                    .controlSize(.small)
                    .padding(10)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 12)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isLoading)
        .onChange(of: fileURL) {
            if fileURL != nil {
                isLoading = true
                loadingForURL = fileURL
            }
            renderedHTML = nil
            renderURL = nil
            if isEditing && isEditorDirty {
                GlossEditorWebView.current?.saveCurrentContent { _ in
                    isEditing = false
                    isEditorDirty = false
                    loadAndWatch()
                }
            } else {
                isEditing = false
                isEditorDirty = false
                loadAndWatch()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossWebViewDidStartLoad)) { _ in
            isLoading = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossWebViewDidFinishLoad)) { _ in
            // Only clear loading if this notification is for the currently loading file.
            // This prevents stale notifications from previous documents from clearing
            // the loading state prematurely during rapid file navigation.
            if loadingForURL == fileURL {
                isLoading = false
            }
        }
        .onAppear {
            loadAndWatch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossNavigateWikiLink)) { notification in
            guard store.gate(.wikiLinks) else { return }
            if let url = notification.object as? URL {
                settings.currentFileURL = url
                settings.lastOpenedFile = url.standardizedFileURL.path
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossEditorDirtyChanged)) { notification in
            if let dirty = notification.object as? NSNumber {
                isEditorDirty = dirty.boolValue
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossEditorSaved)) { _ in
            // Reload content after editor save so read mode reflects changes
            if let url = fileURL {
                reloadContent(url: url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossVaultFilesChanged)) { notification in
            // Live-reload the open document when the folder watcher reports it
            // changed on disk. Path-based, so it catches atomic save-via-rename
            // that the per-file watcher misses. Skipped while editing to avoid
            // clobbering the editor buffer.
            guard !isEditing, let url = fileURL,
                  let paths = notification.object as? [String] else { return }
            // FSEvents reports symlink-resolved paths (/private/...), so resolve
            // the open file's path before comparing — otherwise a vault under a
            // symlinked root (e.g. /tmp) never matches and never live-reloads.
            let target = url.resolvingSymlinksInPath().path
            if paths.contains(target) {
                reloadContent(url: url)
            }
        }
        .onChange(of: isEditing) { _, nowEditing in
            if nowEditing {
                // Entering edit mode unmounts the read-mode WebView, so it can no
                // longer post .glossWebViewDidFinishLoad to clear isLoading. Cancel
                // any in-flight read render and drop the spinner now so it can't
                // strand over the editor — this is what hangs when a freshly created
                // file auto-opens in edit mode (the read render kicked off on open
                // never gets a WebView to finish it).
                renderTask?.cancel()
                isLoading = false
                return
            }
            // When the user exits edit mode, re-read from disk so any external
            // change that arrived while .glossVaultFilesChanged was suppressed
            // (the `!isEditing` guard) is picked up immediately in read mode.
            guard let url = fileURL else { return }
            reloadContent(url: url)
        }
        .onChange(of: fileTree.isWatching) { _, _ in
            // Re-evaluate whether this file is covered by the folder watcher.
            // `loadAndWatch` arms or disarms the per-file FileWatcher accordingly.
            loadAndWatch()
        }
        .onChange(of: colorScheme) {
            if let content = fileContent, let url = fileURL {
                renderAsync(content, url: url)
            }
        }
        .onChange(of: settings.fontSize) {
            if let content = fileContent, let url = fileURL {
                renderAsync(content, url: url)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossTemplateFilled)) { notification in
            guard let payload = notification.object as? TemplateFillPayload,
                  let url = fileURL else { return }
            templateFill.saveFilled(sourceURL: url, payload: payload)
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossIndexUpdated)) { _ in
            // A wiki-link that failed to resolve (index still building, or the
            // target note just created) may resolve now. Probe just the failed
            // targets — cheap lookups — and re-render only when one resolves,
            // so docs with permanently unresolvable [[examples]] don't re-render
            // on every index tick.
            guard !unresolvedWikiTargets.isEmpty, !isEditing,
                  let content = fileContent, let url = fileURL else { return }
            if unresolvedWikiTargets.contains(where: { resolveWikiLink($0, from: url) != nil }) {
                renderAsync(content, url: url)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if fileTree.hasFolder {
            VaultOverviewView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .dropDestination(for: URL.self) { urls, _ in
                    guard let url = urls.first,
                          ["md", "markdown"].contains(url.pathExtension.lowercased()) else {
                        return false
                    }
                    NotificationCenter.default.post(name: .glossFileDrop, object: url)
                    return true
                }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundStyle(.tertiary)
                Text("Open a markdown file to start reading")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("File → Open or drag a .md file here")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first,
                      ["md", "markdown"].contains(url.pathExtension.lowercased()) else {
                    return false
                }
                NotificationCenter.default.post(name: .glossFileDrop, object: url)
                return true
            }
        }
    }

    private func errorState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadAndWatch() {
        guard let url = fileURL else {
            fileContent = nil
            fileWatcher.stop()
            return
        }
        loadingForURL = url
        let previousContent = fileContent
        fileContent = try? String(contentsOf: url, encoding: .utf8)
        if let content = fileContent {
            NotificationCenter.default.post(name: .glossDocumentLoaded, object: content)
            // Re-triggers with unchanged content (e.g. the folder watcher
            // arming after launch restores the vault, which re-runs
            // loadAndWatch for watcher coverage) don't need a re-render —
            // and rendering identical HTML would strand the spinner (#40).
            if content != previousContent || renderURL != url {
                renderAsync(content, url: url)
            } else {
                isLoading = false
            }
        } else {
            isLoading = false
        }
        // Files inside the open vault are already covered by the folder-wide
        // watcher (via .glossVaultFilesChanged), which is path-based and so
        // survives editors' atomic save-via-rename. Only arm the per-file
        // DispatchSource watcher for standalone files (no folder open, or a
        // file outside the root — e.g. wiki-link navigation).
        if isCoveredByFolderWatcher {
            fileWatcher.stop()
        } else {
            fileWatcher.watch(url: url) {
                Task { @MainActor [url] in
                    reloadContent(url: url)
                }
            }
        }
    }

    /// Re-read the file from disk and re-render read mode.
    private func reloadContent(url: URL) {
        fileContent = try? String(contentsOf: url, encoding: .utf8)
        if let content = fileContent {
            NotificationCenter.default.post(name: .glossDocumentLoaded, object: content)
            // While editing, the read-mode WebView isn't mounted — so renderAsync's
            // spinner would never be cleared (it waits on .glossWebViewDidFinishLoad,
            // which only the read WebView posts), stranding the ProgressView over the
            // editor on Cmd+S. Skip the unseen render; exiting edit mode re-reads and
            // renders via .onChange(of: isEditing). The inspector still refreshes above.
            guard !isEditing else { return }
            renderAsync(content, url: url)
        } else {
            // Read failed (e.g. mid atomic save-via-rename) — clear the spinner so
            // we don't strand a ProgressView over stale content with no recovery.
            isLoading = false
        }
    }

    /// Whether the open file lives under the actively watched vault root.
    /// Requires `isWatching` so that if FSEvents failed to start, we fall back to
    /// the per-file watcher rather than leaving the open doc with no change detection.
    private var isCoveredByFolderWatcher: Bool {
        guard fileTree.isWatching, let fileURL, let root = fileTree.rootNode?.url else { return false }
        let filePath = fileURL.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        return filePath == rootPath || filePath.hasPrefix(rootPath + "/")
    }

    /// Renders markdown to HTML on a background thread to avoid blocking the main thread
    /// for large files. Cancels any in-flight render for a previous file.
    private func renderAsync(_ content: String, url: URL) {
        renderTask?.cancel()
        isLoading = true

        // Pre-resolve wiki-links on the main thread (accesses @MainActor state),
        // then pass the resolved map to the background task.
        let (wikiLinkMap, unresolved) = buildWikiLinkSnapshot(for: content, from: url)
        unresolvedWikiTargets = unresolved
        let embedMap = buildEmbedSnapshot(for: content, from: url)
        let isDark = colorScheme == .dark
        let fontSize = settings.fontSize
        let db = linkIndex.databaseRef

        renderTask = Task.detached(priority: .userInitiated) {
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
                          let raw = try? String(contentsOf: embedURL, encoding: .utf8) else { return nil }
                    if let heading { return MarkdownRenderer.extractSection(raw, heading: heading) }
                    return raw
                }
            )
            guard !Task.isCancelled else { return }
            let html = GuideInjector.injectGuideSDK(into: rendered)
            await MainActor.run {
                if html == renderedHTML {
                    // The WebView reloads only when the HTML actually changes,
                    // so the didFinishLoad that normally clears the spinner
                    // will never come for an identical render — clear it here
                    // (the cold-launch stranded spinner, #40).
                    renderURL = url
                    isLoading = false
                } else {
                    renderedHTML = html
                    renderURL = url
                    // isLoading cleared by glossWebViewDidFinishLoad notification
                }
            }
        }
    }

    /// Scans the markdown source for [[wiki-link]] patterns and resolves them to URLs
    /// up-front on the main thread, producing a Sendable snapshot for background
    /// rendering — plus the list of targets that could not be resolved.
    private func buildWikiLinkSnapshot(
        for content: String,
        from url: URL
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
            if let resolved = resolveWikiLink(target, from: url) {
                map[key] = resolved
                unresolved.remove(key)
            } else {
                unresolved.insert(key)
            }
        }
        return (map, Array(unresolved))
    }

    /// Pre-resolve `![[embed]]` targets to file URLs on the main thread
    /// (mirrors `buildWikiLinkSnapshot`). The off-main render reads each file.
    private func buildEmbedSnapshot(for content: String, from url: URL) -> [String: URL] {
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
               let resolved = resolveWikiLink(target, from: url),
               let resolvedURL = URL(string: resolved) {
                map[target.lowercased()] = resolvedURL
            }
        }
        return map
    }

    // MARK: - Wiki-Link Resolution

    /// Resolve a wiki-link target to a file URL: same-directory candidates
    /// first, then the link index. (The old fallback BFS-walked the sidebar
    /// tree, force-loading every directory in the vault on the main thread —
    /// and one unresolvable link loaded all of it.)
    private func resolveWikiLink(_ target: String, from currentFile: URL) -> String? {
        let directory = currentFile.deletingLastPathComponent()
        let candidates = wikiLinkCandidates(for: target)

        // Same folder first
        for candidate in candidates {
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
        if let db = linkIndex.databaseRef,
           let path = ((try? db.pathForWikiTarget(bare)) ?? nil) {
            return URL(fileURLWithPath: path).absoluteString
        }

        return nil
    }

    /// Generate candidate filenames for a wiki-link target.
    private func wikiLinkCandidates(for target: String) -> [String] {
        let trimmed = target.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix(".md") || trimmed.hasSuffix(".markdown") {
            return [trimmed]
        }
        return ["\(trimmed).md", "\(trimmed).markdown", trimmed]
    }
}
