import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import GlossKit

/// Main window layout with sidebar file browser, document detail, and inspector.
struct ContentView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(FileTreeModel.self) private var fileTree
    @Environment(EnhancedSearchService.self) private var enhancedSearch
    @Environment(StoreManager.self) private var store
    @Environment(LinkIndex.self) private var linkIndex
    @Environment(VaultOverviewService.self) private var vaultOverview
    @Environment(GraphService.self) private var graphService
    @Environment(GlossGuideService.self) private var guideService
    @Environment(\.modelContext) private var modelContext
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
@State private var inspectorIsShown = false
    @State private var headings: [HeadingInfo] = []
    @State private var frontmatter: FrontmatterData?
    @State private var paywallFeature: PaidFeature?
    @State private var navHistory = NavigationHistory()
    @State private var isEditing = false
    @State private var isEditorDirty = false
    @State private var showingNewFileAlert = false
    @State private var newFileName = ""
    @State private var isShowingGraph = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDropProviders(providers)
                }
        } detail: {
            detailView
        }
        .modifier(FocusedEditValues(
            toggleEditMode: { toggleEditMode() },
            saveDocument: { GlossEditorWebView.current?.saveCurrentContent() },
            createNewFile: { newFileName = ""; showingNewFileAlert = true },
            todaysNote: { openTodaysNote() },
            isEditing: isEditing
        ))
        .focusedSceneValue(\.toggleFavorite, {
            guard store.gate(.favorites) else { return }
            toggleFavoriteForCurrentFile()
        })
        .focusedSceneValue(\.toggleInspector, {
            guard store.gate(.inspector) else { return }
            withAnimation { inspectorIsShown.toggle() }
        })
        .focusedSceneValue(\.goBack, {
            if let url = navHistory.goBack(from: settings.currentFileURL) {
                settings.currentFileURL = url
            }
        })
        .focusedSceneValue(\.goForward, {
            if let url = navHistory.goForward(from: settings.currentFileURL) {
                settings.currentFileURL = url
            }
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
                settings.lastOpenedFile = url.standardizedFileURL.path
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossDocumentLoaded)) { notification in
            if let content = notification.object as? String {
                headings = MarkdownRenderer.extractHeadings(content)
                frontmatter = MarkdownRenderer.extractFrontmatter(content)
            }
        }
        .onChange(of: settings.currentFileURL) { oldValue, newValue in
            if let newValue {
                navHistory.navigate(to: newValue, from: oldValue)
                linkIndex.refreshBacklinks(for: newValue)
                // Selecting a file exits graph mode so the user sees the doc.
                if isShowingGraph {
                    withAnimation { isShowingGraph = false }
                }
            } else {
                headings = []
                frontmatter = nil
                linkIndex.refreshBacklinks(for: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossEditorSaved)) { notification in
            if let url = notification.object as? URL {
                linkIndex.updateIndex(for: url)
            } else if let currentURL = settings.currentFileURL {
                linkIndex.updateIndex(for: currentURL)
            }
        }
        .modifier(FolderWatchHandler(fileTree: fileTree, linkIndex: linkIndex))
        .modifier(VaultOverviewRefresh(
            linkIndex: linkIndex,
            vaultOverview: vaultOverview,
            graphService: graphService,
            store: store,
            currentFileURL: settings.currentFileURL,
            hasFolder: fileTree.hasFolder,
            isShowingGraph: $isShowingGraph
        ))
        .onChange(of: settings.isZenMode) {
            columnVisibility = settings.isZenMode ? .detailOnly : .automatic
        }
        .alert("New File", isPresented: $showingNewFileAlert) {
            TextField("Filename", text: $newFileName)
            Button("Create") { createNewFile() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter a name for the new markdown file.")
        }
        .overlay {
            NativeSpotlightOverlay()
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossGuideReady)) { _ in
            guideService.handleWebSDKReady()
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossGuideStepComplete)) { _ in
            guideService.handleWebStepComplete()
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossGuideStopped)) { _ in
            guideService.handleWebStopped()
        }
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        if isShowingGraph {
            GraphView()
                .toolbar(settings.isZenMode ? .hidden : .automatic)
                .toolbar { graphToolbarContent }
                .navigationTitle("Vault Graph")
        } else {
            documentDetailView
        }
    }

    @ViewBuilder
    private var documentDetailView: some View {
        DocumentView(
            fileURL: settings.currentFileURL,
            highlightQuery: fileTree.searchScope == .content ? fileTree.searchQuery : nil,
            isEditing: $isEditing,
            isEditorDirty: $isEditorDirty
        )
        .toolbar(settings.isZenMode ? .hidden : .automatic)
        .toolbar { toolbarContent }
        .inspector(isPresented: $inspectorIsShown) {
            InspectorView(
                headings: headings,
                frontmatter: frontmatter,
                tags: linkIndex.currentFileTags,
                forwardLinks: linkIndex.forwardLinks,
                backlinks: linkIndex.backlinks,
                unlinkedMentions: linkIndex.unlinkedMentions,
                hasDocument: settings.currentFileURL != nil,
                onHeadingTap: { headingID in
                    NotificationCenter.default.post(
                        name: .glossScrollToHeading,
                        object: headingID
                    )
                },
                onTagTap: { tag in
                    fileTree.filterByTag(tag, files: linkIndex.files(forTag: tag))
                },
                onForwardLinkTap: { link in
                    guard let targetPath = link.targetPath else { return }
                    let url = URL(fileURLWithPath: targetPath)
                    settings.currentFileURL = url
                    settings.lastOpenedFile = url.standardizedFileURL.path
                },
                onBacklinkTap: { sourcePath in
                    let url = URL(fileURLWithPath: sourcePath)
                    settings.currentFileURL = url
                    settings.lastOpenedFile = url.standardizedFileURL.path
                },
                onUnlinkedMentionTap: { path in
                    let url = URL(fileURLWithPath: path)
                    settings.currentFileURL = url
                    settings.lastOpenedFile = url.standardizedFileURL.path
                },
                onPropertyChange: { key, value in updateProperty(key: key, value: value) },
                onPropertyRemove: { key in removeProperty(key: key) }
            )
            .inspectorColumnWidth(min: 250, ideal: 280, max: 400)
        }
        .navigationTitle(settings.currentFileURL?.lastPathComponent ?? "Gloss")
        .navigationSubtitle(navigationSubtitle)
    }

    private var navigationSubtitle: String {
        if settings.isZenMode { return "" }
        guard settings.currentFileURL != nil else { return "" }
        if isEditing {
            return isEditorDirty ? "Edit Mode • Modified" : "Edit Mode"
        }
        return "Reading Mode"
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !settings.isZenMode {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    if let url = navHistory.goBack(from: settings.currentFileURL) {
                        settings.currentFileURL = url
                    }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .disabled(!navHistory.canGoBack)
                .help("Back (⌘[)")

                Button {
                    if let url = navHistory.goForward(from: settings.currentFileURL) {
                        settings.currentFileURL = url
                    }
                } label: {
                    Label("Forward", systemImage: "chevron.right")
                }
                .disabled(!navHistory.canGoForward)
                .help("Forward (⌘])")
            }

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
                    .spotlightTarget(.toolbarFavorite)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    toggleEditMode()
                } label: {
                    Label(
                        isEditing ? "Reading Mode" : "Edit Mode",
                        systemImage: isEditing ? "book" : "pencil"
                    )
                }
                .help(isEditing ? "Switch to Reading Mode (⇧⌘E)" : "Switch to Edit Mode (⇧⌘E)")
                .disabled(settings.currentFileURL == nil)
                .spotlightTarget(.toolbarEditMode)
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
                .spotlightTarget(.toolbarInspectorToggle)
            }
        }
    }

    // MARK: - Graph Toolbar

    @ToolbarContentBuilder
    private var graphToolbarContent: some ToolbarContent {
        if !settings.isZenMode {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation { isShowingGraph = false }
                } label: {
                    Label("Close Graph", systemImage: "xmark")
                }
                .help("Close Graph (Esc)")
                .keyboardShortcut(.escape, modifiers: [])
            }
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

    // MARK: - Edit Mode

    private func toggleEditMode() {
        guard settings.currentFileURL != nil else { return }
        if isEditing && isEditorDirty {
            GlossEditorWebView.current?.saveCurrentContent { _ in
                isEditing = false
                isEditorDirty = false
            }
        } else {
            isEditing.toggle()
            isEditorDirty = false
        }
    }

    private func openInExternalEditor() {
        guard let url = settings.currentFileURL else { return }
        EditorLauncher.open(fileAt: url.path, with: settings.editor, customAppPath: settings.customEditorPath)
    }

    // MARK: - New File

    /// Open today's daily note, creating it (from a minimal template) if absent.
    private func openTodaysNote() {
        guard !settings.rootFolderPath.isEmpty else { return }
        let root = URL(fileURLWithPath: settings.rootFolderPath)
        let subfolder = settings.dailyNotesFolder.trimmingCharacters(in: .whitespaces)
        let dir = subfolder.isEmpty ? root : root.appendingPathComponent(subfolder)

        let formatter = DateFormatter()
        let fmt = settings.dailyNotesDateFormat.trimmingCharacters(in: .whitespaces)
        formatter.dateFormat = fmt.isEmpty ? "yyyy-MM-dd" : fmt
        let dateString = formatter.string(from: Date())
        guard !dateString.isEmpty else { return }
        let fileURL = dir.appendingPathComponent("\(dateString).md")

        let existed = FileManager.default.fileExists(atPath: fileURL.path)
        if !existed {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let template = "---\ntitle: \(dateString)\ntags: [daily]\n---\n\n"
                try template.write(to: fileURL, atomically: true, encoding: .utf8)
                fileTree.refreshAfterFileChange()
                linkIndex.updateIndex(for: fileURL)
            } catch {
                return
            }
        }
        settings.currentFileURL = fileURL
        settings.lastOpenedFile = fileURL.path
        if !existed {
            isEditorDirty = false
            Task { @MainActor in isEditing = true }   // brand-new note opens ready to write
        }
    }

    /// Write a changed/added frontmatter property back to the current file and re-index.
    private func updateProperty(key: String, value: String) {
        guard !isEditing, let url = settings.currentFileURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let updated = MarkdownRenderer.setFrontmatterValue(content, key: key, value: value)
        guard updated != content else { return }
        do {
            try updated.write(to: url, atomically: true, encoding: .utf8)
            frontmatter = MarkdownRenderer.extractFrontmatter(updated)
            linkIndex.updateIndex(for: url)
        } catch {
            // write failed — leave state unchanged
        }
    }

    /// Remove a frontmatter property from the current file and re-index.
    private func removeProperty(key: String) {
        guard !isEditing, let url = settings.currentFileURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else { return }
        let updated = MarkdownRenderer.removeFrontmatterKey(content, key: key)
        guard updated != content else { return }
        do {
            try updated.write(to: url, atomically: true, encoding: .utf8)
            frontmatter = MarkdownRenderer.extractFrontmatter(updated)
            linkIndex.updateIndex(for: url)
        } catch {
            // write failed — leave state unchanged
        }
    }

    private func createNewFile() {
        var name = newFileName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        if !name.hasSuffix(".md") && !name.hasSuffix(".markdown") {
            name += ".md"
        }

        let folderURL: URL
        if let activeNode = fileTree.activeNode {
            folderURL = activeNode.url
        } else if let currentFile = settings.currentFileURL {
            folderURL = currentFile.deletingLastPathComponent()
        } else {
            return
        }

        let fileURL = folderURL.appendingPathComponent(name)
        guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
            fileTree.refreshAfterFileChange()
            linkIndex.updateIndex(for: fileURL)
            settings.currentFileURL = fileURL
            settings.lastOpenedFile = fileURL.path
            isEditorDirty = false
            // Defer edit mode to next run loop — onChange(of: fileURL)
            // resets isEditing = false, so we must set it after that fires.
            Task { @MainActor in
                isEditing = true
            }
        } catch {
            // File creation failed silently
        }
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

// MARK: - VaultOverviewRefresh ViewModifier

/// Drives `VaultOverviewService` refreshes off the main body to keep
/// ContentView's type checker happy. Listens for index rebuilds and
/// folder-open/close changes, then triggers refresh or clear.
struct VaultOverviewRefresh: ViewModifier {
    let linkIndex: LinkIndex
    let vaultOverview: VaultOverviewService
    let graphService: GraphService
    let store: StoreManager
    let currentFileURL: URL?
    let hasFolder: Bool
    @Binding var isShowingGraph: Bool

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .glossIndexUpdated)) { _ in
                linkIndex.refreshBacklinks(for: currentFileURL)
                vaultOverview.refresh(database: linkIndex.databaseRef)
                graphService.refresh(database: linkIndex.databaseRef)
            }
            .onChange(of: hasFolder) { _, nowHasFolder in
                if nowHasFolder {
                    vaultOverview.refresh(database: linkIndex.databaseRef)
                    graphService.refresh(database: linkIndex.databaseRef)
                } else {
                    vaultOverview.clear()
                    graphService.clear()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .glossShowGraph)) { _ in
                guard store.gate(.graphView) else { return }
                if let current = currentFileURL {
                    var f = graphService.filter
                    f.centerPath = current.standardizedFileURL.path
                    if f.maxDepth == nil { f.maxDepth = 2 }
                    graphService.applyFilter(f, database: linkIndex.databaseRef)
                }
                withAnimation { isShowingGraph = true }
            }
    }
}

// MARK: - FolderWatchHandler ViewModifier

/// Reacts to folder-watcher events off the main body (type-checker relief).
/// Reconciles the sidebar tree and brings the link index up to date when the
/// FSEvents watcher reports on-disk changes under the open vault.
struct FolderWatchHandler: ViewModifier {
    let fileTree: FileTreeModel
    let linkIndex: LinkIndex

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .glossVaultFilesChanged)) { notification in
                fileTree.refreshAfterFileChange()
                if let paths = notification.object as? [String] {
                    linkIndex.handleExternalChanges(paths: paths)
                }
            }
    }
}

// MARK: - FocusedEditValues ViewModifier

/// Groups editor-related FocusedSceneValues to reduce body complexity.
struct FocusedEditValues: ViewModifier {
    var toggleEditMode: () -> Void
    var saveDocument: () -> Void
    var createNewFile: () -> Void
    var todaysNote: () -> Void
    var isEditing: Bool

    func body(content: Content) -> some View {
        content
            .focusedSceneValue(\.toggleEditMode, toggleEditMode)
            .focusedSceneValue(\.saveDocument, saveDocument)
            .focusedSceneValue(\.createNewFile, createNewFile)
            .focusedSceneValue(\.todaysNote, todaysNote)
            .focusedSceneValue(\.isEditingDocument, isEditing)
    }
}

// MARK: - FocusedValues

struct FavoriteToggleKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct InspectorToggleKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct GoBackKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct GoForwardKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct EditModeToggleKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct SaveDocumentKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct CreateNewFileKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct TodaysNoteKey: FocusedValueKey {
    typealias Value = () -> Void
}

struct IsEditingDocumentKey: FocusedValueKey {
    typealias Value = Bool
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

    var goBack: (() -> Void)? {
        get { self[GoBackKey.self] }
        set { self[GoBackKey.self] = newValue }
    }

    var goForward: (() -> Void)? {
        get { self[GoForwardKey.self] }
        set { self[GoForwardKey.self] = newValue }
    }

    var toggleEditMode: (() -> Void)? {
        get { self[EditModeToggleKey.self] }
        set { self[EditModeToggleKey.self] = newValue }
    }

    var saveDocument: (() -> Void)? {
        get { self[SaveDocumentKey.self] }
        set { self[SaveDocumentKey.self] = newValue }
    }

    var createNewFile: (() -> Void)? {
        get { self[CreateNewFileKey.self] }
        set { self[CreateNewFileKey.self] = newValue }
    }

    var todaysNote: (() -> Void)? {
        get { self[TodaysNoteKey.self] }
        set { self[TodaysNoteKey.self] = newValue }
    }

    var isEditingDocument: Bool? {
        get { self[IsEditingDocumentKey.self] }
        set { self[IsEditingDocumentKey.self] = newValue }
    }
}
