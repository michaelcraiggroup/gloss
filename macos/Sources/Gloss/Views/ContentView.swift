import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import GlossKit

/// Main window layout with sidebar file browser, document detail, and inspector.
struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(FileTreeModel.self) private var fileTree
    @Environment(ContentSearchService.self) private var contentSearch
    @Environment(StoreManager.self) private var store
    @Environment(\.modelContext) private var modelContext
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var inspectorIsShown = false
    @State private var headings: [HeadingInfo] = []
    @State private var frontmatter: FrontmatterData?
    @State private var paywallFeature: PaidFeature?

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDropProviders(providers)
                }
        } detail: {
            DocumentView(
                fileURL: settings.currentFileURL,
                highlightQuery: fileTree.searchScope == .content ? fileTree.searchQuery : nil
            )
                .toolbar(settings.isZenMode ? .hidden : .automatic)
                .toolbar {
                    if !settings.isZenMode {
                        if settings.currentFileURL != nil {
                            ToolbarItem(placement: .primaryAction) {
                                Button {
                                    guard store.gate(.favorites) else { return }
                                    toggleFavoriteForCurrentFile()
                                } label: {
                                    Label(
                                        "Toggle Favorite",
                                        systemImage: isCurrentFileFavorited ? "star.fill" : "star"
                                    )
                                }
                                .foregroundStyle(isCurrentFileFavorited ? .yellow : .secondary)
                                .help("Toggle Favorite (⌘D)")
                            }
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                openInEditor()
                            } label: {
                                Label("Open in Editor", systemImage: "pencil.and.outline")
                            }
                            .help("Open in \(settings.editor.displayName) (⇧⌘E)")
                            .disabled(settings.currentFileURL == nil)
                        }
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                guard store.gate(.inspector) else { return }
                                withAnimation { inspectorIsShown.toggle() }
                            } label: {
                                Label("Toggle Inspector", systemImage: "sidebar.trailing")
                            }
                            .help("Toggle Inspector (⌥⌘I)")
                            .disabled(settings.currentFileURL == nil)
                        }
                        if settings.currentFileURL != nil {
                            ToolbarItem(placement: .status) {
                                Text("j/k to scroll")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .inspector(isPresented: $inspectorIsShown) {
                    InspectorView(
                        headings: headings,
                        frontmatter: frontmatter,
                        onHeadingTap: { headingID in
                            NotificationCenter.default.post(
                                name: .glossScrollToHeading,
                                object: headingID
                            )
                        }
                    )
                    .inspectorColumnWidth(min: 200, ideal: 250, max: 350)
                }
                .navigationTitle(settings.currentFileURL?.lastPathComponent ?? "Gloss")
                .navigationSubtitle(settings.isZenMode ? "" : (settings.currentFileURL != nil ? "Reading Mode" : ""))
        }
        .focusedSceneValue(\.toggleFavorite, {
            guard store.gate(.favorites) else { return }
            toggleFavoriteForCurrentFile()
        })
        .focusedSceneValue(\.toggleInspector, {
            guard store.gate(.inspector) else { return }
            withAnimation { inspectorIsShown.toggle() }
        })
        .sheet(item: $paywallFeature) { feature in
            PaywallView(feature: feature)
                .environment(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossShowPaywall)) { notification in
            if let feature = notification.object as? PaidFeature {
                paywallFeature = feature
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossFileDrop)) { notification in
            if let url = notification.object as? URL {
                settings.currentFileURL = url
                settings.lastOpenedFile = url.path
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossDocumentLoaded)) { notification in
            if let content = notification.object as? String {
                headings = MarkdownRenderer.extractHeadings(content)
                frontmatter = MarkdownRenderer.extractFrontmatter(content)
            }
        }
        .onChange(of: settings.currentFileURL) {
            if settings.currentFileURL == nil {
                headings = []
                frontmatter = nil
            }
        }
        .onChange(of: settings.isZenMode) {
            columnVisibility = settings.isZenMode ? .detailOnly : .automatic
        }
    }

    // MARK: - Favorites

    private var isCurrentFileFavorited: Bool {
        guard let url = settings.currentFileURL else { return false }
        let path = url.path
        let descriptor = FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.path == path && $0.isFavorite }
        )
        return (try? modelContext.fetchCount(descriptor)) ?? 0 > 0
    }

    private func toggleFavoriteForCurrentFile() {
        guard let url = settings.currentFileURL else { return }
        let path = url.path
        let descriptor = FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.path == path }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.isFavorite.toggle()
        } else {
            let filename = url.lastPathComponent
            let parentFolder = url.deletingLastPathComponent().lastPathComponent
            let docType = DocumentType.detect(filename: filename, folderName: parentFolder)
            let title = filename.replacingOccurrences(of: ".md", with: "")
                .replacingOccurrences(of: ".markdown", with: "")
            let doc = RecentDocument(path: path, title: title, documentType: docType.rawValue, isFavorite: true)
            modelContext.insert(doc)
        }
    }

    // MARK: - Editor

    private func openInEditor() {
        guard let url = settings.currentFileURL else { return }
        EditorLauncher.open(fileAt: url.path, with: settings.editor)
    }

    // MARK: - Drop

    private func handleDropProviders(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url, ["md", "markdown"].contains(url.pathExtension.lowercased()) else { return }
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .glossFileDrop, object: url)
            }
        }
        return true
    }
}

// MARK: - FocusedValues

struct FavoriteToggleKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct InspectorToggleKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var toggleFavorite: (() -> Void)? {
        get { self[FavoriteToggleKey.self] }
        set { self[FavoriteToggleKey.self] = newValue }
    }

    var toggleInspector: (() -> Void)? {
        get { self[InspectorToggleKey.self] }
        set { self[InspectorToggleKey.self] = newValue }
    }
}
