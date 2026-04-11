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
    @Environment(\.colorScheme) private var colorScheme
    @State private var fileContent: String?
    @State private var fileWatcher = FileWatcher()

    var body: some View {
        Group {
            if let url = fileURL {
                if isEditing {
                    EditorWebView(
                        fileURL: url,
                        isDark: colorScheme == .dark,
                        fontSize: settings.fontSize
                    )
                } else if let content = fileContent {
                    let rendered = MarkdownRenderer.render(
                        content,
                        isDark: colorScheme == .dark,
                        fontSize: settings.fontSize,
                        resolveWikiLink: { target in
                            resolveWikiLink(target, from: url)
                        }
                    )
                    let html = GuideInjector.injectGuideSDK(into: rendered)
                    WebView(
                        htmlContent: html,
                        baseURL: url.deletingLastPathComponent(),
                        highlightQuery: highlightQuery,
                        rawMarkdown: content
                    )
                } else {
                    errorState(message: "Could not read file:\n\(url.lastPathComponent)")
                }
            } else {
                emptyState
            }
        }
        .onChange(of: fileURL) {
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
        .onAppear {
            loadAndWatch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossNavigateWikiLink)) { notification in
            guard store.gate(.wikiLinks) else { return }
            if let url = notification.object as? URL {
                settings.currentFileURL = url
                settings.lastOpenedFile = url.path
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
                fileContent = try? String(contentsOf: url, encoding: .utf8)
                if let content = fileContent {
                    NotificationCenter.default.post(name: .glossDocumentLoaded, object: content)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossTemplateFilled)) { notification in
            guard let payload = notification.object as? TemplateFillPayload,
                  let url = fileURL else { return }
            templateFill.saveFilled(sourceURL: url, payload: payload)
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
        fileContent = try? String(contentsOf: url, encoding: .utf8)
        if let content = fileContent {
            NotificationCenter.default.post(name: .glossDocumentLoaded, object: content)
        }
        fileWatcher.watch(url: url) {
            Task { @MainActor [url] in
                fileContent = try? String(contentsOf: url, encoding: .utf8)
                if let content = fileContent {
                    NotificationCenter.default.post(name: .glossDocumentLoaded, object: content)
                }
            }
        }
    }

    // MARK: - Wiki-Link Resolution

    /// Resolve a wiki-link target to a file URL, searching from the current file's directory.
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

        // Search within open folder tree
        if let rootNode = fileTree.rootNode {
            if let found = searchTree(rootNode, for: candidates) {
                return found.absoluteString
            }
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

    /// Breadth-first search through file tree for a matching filename.
    private func searchTree(_ node: FileTreeNode, for candidates: [String]) -> URL? {
        var queue: [FileTreeNode] = [node]
        while !queue.isEmpty {
            let current = queue.removeFirst()
            if current.isDirectory {
                if current.children == nil { current.loadChildren() }
                for child in current.children ?? [] {
                    if !child.isDirectory, candidates.contains(child.name) {
                        return child.url
                    }
                    if child.isDirectory {
                        queue.append(child)
                    }
                }
            }
        }
        return nil
    }
}
