import SwiftUI
import GlossKit

/// The iOS reader: owns a DocumentRenderModel instance (the same pipeline the
/// macOS DocumentView calls statically) and mirrors its trigger surface —
/// re-render on theme/font changes, live reload when the vault observer
/// reports the open file changed, and unresolved-wiki-link re-probes when the
/// index catches up.
struct ReaderScreen: View {
    let fileURL: URL
    var highlightQuery: String?
    let navHistory: NavigationHistory

    @EnvironmentObject private var settings: AppSettings
    @Environment(LinkIndex.self) private var linkIndex
    @Environment(StoreManager.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @State private var model = DocumentRenderModel()
    @State private var loadFailed = false
    @State private var isDownloading = false
    @State private var showingInspector = false
    @State private var headings: [HeadingInfo] = []
    @State private var frontmatter: FrontmatterData?

    var body: some View {
        ZStack {
            if let html = model.renderedHTML, model.renderURL == fileURL {
                ReaderWebView(
                    htmlContent: html,
                    baseURL: fileURL.deletingLastPathComponent(),
                    highlightQuery: highlightQuery
                )
                .ignoresSafeArea(edges: .bottom)
            } else if isDownloading {
                ContentUnavailableView {
                    Label("Downloading from iCloud", systemImage: "icloud.and.arrow.down")
                } description: {
                    Text(fileURL.lastPathComponent)
                }
            } else if loadFailed {
                ContentUnavailableView(
                    "Could not read file",
                    systemImage: "exclamationmark.triangle",
                    description: Text(fileURL.lastPathComponent)
                )
            } else {
                ProgressView()
            }
        }
        .navigationTitle(displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    if let url = navHistory.goBack(from: settings.currentFileURL) {
                        settings.currentFileURL = url
                    }
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .disabled(!navHistory.canGoBack)
                .accessibilityLabel("Back")

                Button {
                    if let url = navHistory.goForward(from: settings.currentFileURL) {
                        settings.currentFileURL = url
                    }
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .disabled(!navHistory.canGoForward)
                .accessibilityLabel("Forward")

                Button {
                    guard store.gate(.inspector) else { return }
                    showingInspector.toggle()
                } label: {
                    Image(systemName: "sidebar.trailing")
                }
                .accessibilityLabel("Inspector")
            }
        }
        // A detented sheet rather than .inspector — the trailing-column
        // modifier swallows the navigation bar inside this split-view detail
        // on iPhone (found by smoke). Read-only in v1 (nil property
        // callbacks); link taps route through the shared wiki-nav pipeline so
        // history/gating behave exactly like in-document links.
        .sheet(isPresented: $showingInspector) {
            NavigationStack {
                inspectorContent
                    .navigationTitle("Inspector")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingInspector = false }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
        .onAppear {
            model.database = { linkIndex.databaseRef }
            loadAndRender()
            linkIndex.refreshBacklinks(for: fileURL)
        }
        .onChange(of: fileURL) {
            loadAndRender()
            linkIndex.refreshBacklinks(for: fileURL)
        }
        .onChange(of: model.fileContent) { _, content in
            headings = content.map { MarkdownRenderer.extractHeadings($0) } ?? []
            frontmatter = content.flatMap { MarkdownRenderer.extractFrontmatter($0) }
        }
        .onChange(of: colorScheme) {
            renderCurrent()
        }
        .onChange(of: settings.fontSize) {
            renderCurrent()
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossVaultFilesChanged)) { note in
            // Live-reload the open document when the vault observer reports it
            // changed on disk (arrives via NullVaultObserver's replacement in
            // the sync arc; wired now so PR 9 needs no reader changes).
            guard let paths = note.object as? [String] else { return }
            let target = fileURL.resolvingSymlinksInPath().path
            if paths.contains(target) {
                loadAndRender()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossIndexUpdated)) { _ in
            // A wiki-link that failed to resolve may resolve now — probe just
            // the failed targets and re-render only when one lights up (same
            // guard as macOS DocumentView).
            guard !model.unresolvedWikiTargets.isEmpty,
                  let content = model.fileContent else { return }
            let resolvable = model.unresolvedWikiTargets.contains {
                DocumentRenderModel.resolveWikiLink(
                    $0, from: fileURL, database: linkIndex.databaseRef) != nil
            }
            if resolvable {
                model.render(content, url: fileURL,
                             isDark: colorScheme == .dark, fontSize: settings.fontSize)
            }
        }
        .onDisappear {
            model.cancel()
        }
    }

    private var inspectorContent: some View {
        InspectorView(
            headings: headings,
            frontmatter: frontmatter,
            tags: linkIndex.currentFileTags,
            forwardLinks: linkIndex.forwardLinks,
            backlinks: linkIndex.backlinks,
            unlinkedMentions: linkIndex.unlinkedMentions,
            hasDocument: true,
            onHeadingTap: { headingID in
                showingInspector = false
                NotificationCenter.default.post(
                    name: .glossScrollToHeading, object: headingID)
            },
            onForwardLinkTap: { link in
                if let path = link.targetPath {
                    showingInspector = false
                    NotificationCenter.default.post(
                        name: .glossNavigateWikiLink,
                        object: URL(fileURLWithPath: path))
                }
            },
            onBacklinkTap: { sourcePath in
                showingInspector = false
                NotificationCenter.default.post(
                    name: .glossNavigateWikiLink,
                    object: URL(fileURLWithPath: sourcePath))
            }
        )
    }

    private var displayTitle: String {
        let name = fileURL.lastPathComponent
        if name.hasSuffix(".md") { return String(name.dropLast(3)) }
        if name.hasSuffix(".markdown") { return String(name.dropLast(9)) }
        return name
    }

    private func loadAndRender() {
        if model.load(url: fileURL) {
            loadFailed = false
            isDownloading = false
            renderCurrent()
            return
        }
        // A container file that hasn't downloaded yet reads as a failure —
        // kick the download and wait; the metadata observer posts
        // .glossVaultFilesChanged when it lands, which re-runs this load.
        if UbiquityVaultStore.isUbiquitousPath(fileURL) {
            isDownloading = true
            loadFailed = false
            try? FileManager.default.startDownloadingUbiquitousItem(at: fileURL)
        } else {
            loadFailed = true
        }
    }

    private func renderCurrent() {
        guard let content = model.fileContent else { return }
        model.render(content, url: fileURL,
                     isDark: colorScheme == .dark, fontSize: settings.fontSize)
    }
}
