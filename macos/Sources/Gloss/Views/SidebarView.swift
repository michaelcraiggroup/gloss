import AppKit
import SwiftUI
import SwiftData

/// File browser sidebar with recursive file tree, search, favorites, and recent documents.
/// Favorites and recents render via vault-scoped section subviews
/// (FavoritesSection / RecentsSection) keyed on `settings.vaultKey`.
struct SidebarView: View {
    @Environment(FileTreeModel.self) private var fileTree
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var store
    @Environment(FavoritesService.self) private var favoritesService
    @Environment(EnhancedSearchService.self) private var enhancedSearch
    @Environment(FilenameSearchService.self) private var filenameSearch
    @Environment(LinkIndex.self) private var linkIndex
    @Environment(ContainerVaultCatalog.self) private var vaultCatalog
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("largeVaultNoticeDismissed") private var largeVaultNoticeDismissed = false
    @State private var searchText = ""
    @State private var searchScope: SearchScope = .filename
    @State private var showingRenameAlert = false
    @State private var showingDeleteConfirmation = false
    @State private var renameFileName = ""
    @State private var contextMenuTargetURL: URL?

    var body: some View {
        List(selection: Binding(
            get: { fileTree.selectedFileURL },
            set: { selectFile($0) }
        )) {
            // One-time hint when the vault looks like a development workspace.
            if linkIndex.largeVaultDetected && !largeVaultNoticeDismissed {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Large workspace", systemImage: "shippingbox")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Build folders (target, dist, node_modules, …) are excluded automatically. Adjust via .gloss/config.json in the vault root.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Button("Got it") {
                            largeVaultNoticeDismissed = true
                        }
                        .font(.caption2)
                        .buttonStyle(.link)
                    }
                    .padding(.vertical, 2)
                }
            }

            // Tag filter banner (shown when filtering by tag from inspector or sidebar)
            if let activeTag = fileTree.activeTagFilter,
               let tagFiles = fileTree.tagFilteredFiles {
                Section {
                    HStack {
                        Label(activeTag, systemImage: "tag.fill")
                            .font(.caption)
                            .foregroundStyle(.teal)
                        Spacer()
                        Button {
                            fileTree.clearTagFilter()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Filtered by Tag")
                }

                Section("Results (\(tagFiles.count))") {
                    if tagFiles.isEmpty {
                        Text("No files with this tag")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(tagFiles, id: \.path) { file in
                            let url = URL(fileURLWithPath: file.path)
                            let parentFolder = url.deletingLastPathComponent().lastPathComponent
                            let docType = DocumentType.detect(
                                filename: url.lastPathComponent, folderName: parentFolder
                            )
                            Label {
                                Text(file.title)
                                    .lineLimit(1)
                            } icon: {
                                Text(docType.icon)
                            }
                            .tag(url)
                            .contextMenu { favoriteContextMenu(for: url) }
                        }
                    }
                }
            } else if searchScope == .tags && !searchText.isEmpty {
                // Tag search results
                Section("Matching Tags") {
                    let matchingTags = linkIndex.allTags.filter {
                        $0.tag.localizedCaseInsensitiveContains(searchText)
                    }
                    if matchingTags.isEmpty {
                        Text("No matching tags")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(matchingTags, id: \.tag) { item in
                            Button {
                                fileTree.filterByTag(item.tag, files: linkIndex.files(forTag: item.tag))
                                searchText = ""
                            } label: {
                                HStack {
                                    Label(item.tag, systemImage: "tag")
                                    Spacer()
                                    Text("\(item.count)")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else if searchScope == .content && !searchText.isEmpty {
                // Full-text search results (WS5 — backed by FTS5)
                Section {
                    searchFilterChips
                } header: {
                    Text("Filters")
                }

                Section("Content Results") {
                    if enhancedSearch.isSearching {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Searching…")
                                .foregroundStyle(.secondary)
                        }
                    } else if enhancedSearch.results.isEmpty {
                        Text("No matches")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(enhancedSearch.results) { hit in
                            searchHitRow(hit)
                                .tag(hit.fileURL)
                                .contextMenu { favoriteContextMenu(for: hit.fileURL) }
                        }
                    }
                }
            } else if searchScope == .filename && !searchText.isEmpty {
                Section("Search Results") {
                    if let results = filenameSearch.results {
                        if results.isEmpty {
                            Text("No matches")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(results) { hit in
                                filenameHitRow(hit)
                                    .tag(hit.fileURL)
                                    .contextMenu { favoriteContextMenu(for: hit.fileURL) }
                            }
                        }
                    } else {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Searching…")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else if searchScope == .filename || searchScope == .tags {
                // Normal browsing mode (no search active, or tags scope without query)
                browseSection

                // Favorites opens the "shelves" — the quick-access sections
                // that sit below the vault's own documents.
                FavoritesSection(
                    showsShelfDivider: fileTree.activeNode != nil,
                    onSelect: { selectFile($0) },
                    onToggleFavorite: { toggleFavorite(url: $0) }
                ) { url in
                    favoriteContextMenu(for: url)
                }

                if !linkIndex.recentlyChanged.isEmpty {
                    Section {
                        ForEach(linkIndex.recentlyChanged.prefix(10), id: \.path) { item in
                            let url = URL(fileURLWithPath: item.path)
                            let parentFolder = url.deletingLastPathComponent().lastPathComponent
                            let docType = DocumentType.detect(
                                filename: url.lastPathComponent, folderName: parentFolder
                            )
                            HStack {
                                Label {
                                    Text(item.title)
                                        .lineLimit(1)
                                } icon: {
                                    Text(docType.icon)
                                }
                                Spacer()
                                Text(relativeDate(item.modifiedAt))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { selectFile(url) }
                            .contextMenu { favoriteContextMenu(for: url) }
                        }
                    } header: {
                        Text("Recently Changed").glossShelfHeader()
                    }
                }

                if !linkIndex.allTags.isEmpty {
                    Section {
                        ForEach(linkIndex.allTags.prefix(20), id: \.tag) { item in
                            Button {
                                fileTree.filterByTag(item.tag, files: linkIndex.files(forTag: item.tag))
                            } label: {
                                HStack {
                                    Label(item.tag, systemImage: "tag")
                                        .lineLimit(1)
                                    Spacer()
                                    Text("\(item.count)")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Tags").glossShelfHeader()
                    }
                    .spotlightTarget(.sidebarTagsSection)
                }

                RecentsSection(
                    vaultKey: settings.vaultKey,
                    onSelect: { selectFile($0) },
                    onToggleFavorite: { toggleFavorite(url: $0) }
                ) { url in
                    favoriteContextMenu(for: url)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color.glossChromeSidebar(colorScheme))
        .safeAreaInset(edge: .top, spacing: 0) { GlossSidebarHeader() }
        .searchable(text: $searchText, prompt: "Search files")
        .searchScopes($searchScope) {
            ForEach(SearchScope.allCases, id: \.self) { scope in
                Text(scope.rawValue).tag(scope)
            }
        }
        .onChange(of: searchText) { _, query in
            fileTree.searchQuery = query
            if searchScope == .content {
                enhancedSearch.search(query: query, database: linkIndex.databaseRef)
            } else if searchScope == .filename {
                filenameSearch.search(query: query, database: linkIndex.databaseRef)
            }
        }
        .onChange(of: searchScope) { _, scope in
            if (scope == .content || scope == .tags) && !store.isUnlocked {
                searchScope = .filename
                _ = store.gate(.fullTextSearch)
                return
            }
            fileTree.searchScope = scope
            if scope == .content && !searchText.isEmpty {
                enhancedSearch.search(query: searchText, database: linkIndex.databaseRef)
                filenameSearch.cancel()
            } else if scope == .filename {
                enhancedSearch.cancel()
                if !searchText.isEmpty {
                    filenameSearch.search(query: searchText, database: linkIndex.databaseRef)
                }
            } else {
                enhancedSearch.cancel()
                filenameSearch.cancel()
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    fileTree.refreshAfterFileChange()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Refresh file tree")
                .disabled(!fileTree.hasFolder)

                // The iPhone's library icon, and its behavior: one place
                // that lists every vault and opens any of them. The panel
                // route stays for local folders.
                Menu {
                    ForEach(vaultCatalog.vaults) { vault in
                        Button {
                            guard store.gate(.folderSidebar) else { return }
                            NotificationCenter.default.post(
                                name: .glossOpenPath, object: vault.rootURL)
                        } label: {
                            Label(vault.name, systemImage: vault.isInICloud ? "icloud" : "folder")
                        }
                    }
                    if !vaultCatalog.vaults.isEmpty {
                        Divider()
                    }
                    Button("Open Vault…") {
                        guard store.gate(.folderSidebar) else { return }
                        openVaultFromSidebar()
                    }
                } label: {
                    Label("Vault Library", systemImage: "books.vertical")
                }
                .help("Vault Library (⇧⌘O opens a folder)")
                .task {
                    await vaultCatalog.refresh()
                }

                if GlossFeatures.vaultGraph {
                    Button {
                        NotificationCenter.default.post(name: .glossShowGraph, object: nil)
                    } label: {
                        Label("Vault Graph", systemImage: "point.3.connected.trianglepath.dotted")
                    }
                    .help("Show Vault Graph (⌥⌘G)")
                    .disabled(!fileTree.hasFolder)
                }
            }
        }
        .alert("Rename", isPresented: $showingRenameAlert) {
            TextField("Name", text: $renameFileName)
            Button("Rename") {
                performRename()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter a new name.")
        }
        .confirmationDialog(
            "Move to Trash?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                performDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if let url = contextMenuTargetURL {
                Text("\"\(url.lastPathComponent)\" will be moved to the Trash.")
            }
        }
    }

    // MARK: - Filename Hit Row

    private func filenameHitRow(_ hit: FilenameHit) -> some View {
        let parentFolder = hit.fileURL.deletingLastPathComponent().lastPathComponent
        let docType = DocumentType.detect(filename: hit.filename, folderName: parentFolder)
        return Label {
            Text(hit.filename)
                .lineLimit(1)
        } icon: {
            Text(docType.icon)
        }
    }

    // MARK: - Search Hit Row (WS5)

    private func searchHitRow(_ hit: SearchHit) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(hit.documentType.icon)
                    .font(.caption)
                Text(hit.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                Text(relativeDate(hit.modifiedAt))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(attributedSnippet(hit.segments))
                .font(.caption)
                .lineLimit(2)
        }
    }

    /// Build an `AttributedString` from parsed FTS5 snippet segments, bolding
    /// matched tokens.
    private func attributedSnippet(_ segments: [SearchHit.Segment]) -> AttributedString {
        var result = AttributedString()
        for segment in segments {
            var piece = AttributedString(segment.text)
            if segment.isMatch {
                piece.foregroundColor = .primary
                piece.font = .caption.bold()
            } else {
                piece.foregroundColor = .secondary
            }
            result.append(piece)
        }
        return result
    }

    // MARK: - Filter Chips (WS5)

    @ViewBuilder
    private var searchFilterChips: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                // Tag filter chip
                Menu {
                    Button("All tags") {
                        enhancedSearch.tagFilter = nil
                        enhancedSearch.rerun(database: linkIndex.databaseRef)
                    }
                    if !linkIndex.allTags.isEmpty {
                        Divider()
                        ForEach(linkIndex.allTags.prefix(30), id: \.tag) { item in
                            Button("#\(item.tag) (\(item.count))") {
                                enhancedSearch.tagFilter = item.tag
                                enhancedSearch.rerun(database: linkIndex.databaseRef)
                            }
                        }
                    }
                } label: {
                    chipLabel(
                        icon: "tag",
                        text: enhancedSearch.tagFilter.map { "#\($0)" } ?? "Tag",
                        isActive: enhancedSearch.tagFilter != nil
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Document type filter chip
                Menu {
                    Button("All types") {
                        enhancedSearch.documentTypeFilter = nil
                        enhancedSearch.rerun(database: linkIndex.databaseRef)
                    }
                    Divider()
                    ForEach(DocumentType.allCases, id: \.self) { type in
                        Button("\(type.icon) \(type.displayName)") {
                            enhancedSearch.documentTypeFilter = type
                            enhancedSearch.rerun(database: linkIndex.databaseRef)
                        }
                    }
                } label: {
                    chipLabel(
                        icon: "doc",
                        text: enhancedSearch.documentTypeFilter?.displayName ?? "Type",
                        isActive: enhancedSearch.documentTypeFilter != nil
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                if enhancedSearch.hasActiveFilters {
                    Button {
                        enhancedSearch.clearFilters()
                        enhancedSearch.rerun(database: linkIndex.databaseRef)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func chipLabel(icon: String, text: String, isActive: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 8))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? Color.glossAccent.opacity(0.2) : Color.secondary.opacity(0.1))
        )
        .foregroundStyle(isActive ? Color.glossAccent : .secondary)
    }

    // MARK: - Browse Section

    @ViewBuilder
    private var browseSection: some View {
        if fileTree.isScoped {
            Section {
                Button {
                    fileTree.unscopeFolder()
                } label: {
                    Label("Back to \(fileTree.rootNode?.name ?? "root")", systemImage: "chevron.left")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
            }
        }

        if fileTree.activeNode == nil {
            // iPhone-parity library: with no vault open, the sidebar IS the
            // vault list (amber shelf rows, container vaults) — not a dead
            // pane with the affordance hidden in a menu.
            Section("Vaults") {
                ForEach(vaultCatalog.vaults) { vault in
                    Button {
                        guard store.gate(.folderSidebar) else { return }
                        NotificationCenter.default.post(
                            name: .glossOpenPath, object: vault.rootURL)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "books.vertical")
                                .foregroundStyle(Color.glossAccent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vault.name)
                                if let line = vault.shelfLine {
                                    Text(line)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                            if vault.isInICloud {
                                Image(systemName: "icloud")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    guard store.gate(.folderSidebar) else { return }
                    openVaultFromSidebar()
                } label: {
                    Label("Open Vault…", systemImage: "folder.badge.plus")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .task {
                await vaultCatalog.refresh()
            }
        }

        if let active = fileTree.activeNode {
            Section {
                ForEach(fileTree.sortedChildren(active.children ?? [])) { node in
                    fileTreeItem(node)
                }
            } header: {
                VStack(alignment: .leading, spacing: 6) {
                    GlossVaultHeader(
                        name: active.name,
                        path: active.url.path,
                        isScoped: fileTree.isScoped
                    )
                    HStack(spacing: 8) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Button {
                                fileTree.toggleSort(order)
                            } label: {
                                HStack(spacing: 2) {
                                    Text(order.rawValue)
                                    if fileTree.sortOrder == order {
                                        Image(systemName: fileTree.sortDirection.symbol)
                                    }
                                }
                                .font(.caption2)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(fileTree.sortOrder == order ? .primary : .secondary)
                        }
                        Spacer()
                    }
                    .textCase(nil)
                    .padding(.leading, 10)   // aligns with the vault card's title
                }
            }
        }
    }

    // MARK: - File Tree

    private func fileTreeItem(_ node: FileTreeNode) -> AnyView {
        if node.isDirectory {
            AnyView(
                DisclosureGroup(isExpanded: Binding(
                    get: { node.isExpanded },
                    set: { expanded in
                        if expanded && node.children == nil {
                            node.loadChildren()
                        }
                        node.isExpanded = expanded
                    }
                )) {
                    ForEach(fileTree.sortedChildren(node.children ?? [])) { child in
                        fileTreeItem(child)
                    }
                } label: {
                    FileTreeRow(node: node)
                        .onTapGesture(count: 2) {
                            fileTree.scopeToFolder(node)
                        }
                        .contextMenu {
                            Button {
                                fileTree.scopeToFolder(node)
                            } label: {
                                Label("Open in Sidebar", systemImage: "folder")
                            }
                            Divider()
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(node.name, forType: .string)
                            } label: {
                                Label("Copy Filename", systemImage: "doc.on.doc")
                            }
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(node.url.path, forType: .string)
                            } label: {
                                Label("Copy Path", systemImage: "link")
                            }
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([node.url])
                            } label: {
                                Label("Reveal in Finder", systemImage: "arrow.right.circle")
                            }
                            Divider()
                            Button {
                                contextMenuTargetURL = node.url
                                renameFileName = node.name
                                showingRenameAlert = true
                            } label: {
                                Label("Rename…", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                contextMenuTargetURL = node.url
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Move to Trash", systemImage: "trash")
                            }
                        }
                }
            )
        } else {
            AnyView(
                FileTreeRow(node: node)
                    .tag(node.url)
                    .contextMenu { favoriteContextMenu(for: node.url) }
            )
        }
    }

    // MARK: - Favorites

    @ViewBuilder
    private func favoriteContextMenu(for url: URL) -> some View {
        let favorited = isFavorited(url: url)
        Button {
            toggleFavorite(url: url)
        } label: {
            Label(
                favorited ? "Remove from Favorites" : "Add to Favorites",
                systemImage: favorited ? "star.slash" : "star"
            )
        }
        Divider()
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.lastPathComponent, forType: .string)
        } label: {
            Label("Copy Filename", systemImage: "doc.on.doc")
        }
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(url.path, forType: .string)
        } label: {
            Label("Copy Path", systemImage: "link")
        }
        Button {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } label: {
            Label("Reveal in Finder", systemImage: "arrow.right.circle")
        }
        Divider()
        Button {
            contextMenuTargetURL = url
            renameFileName = url.lastPathComponent
            showingRenameAlert = true
        } label: {
            Label("Rename…", systemImage: "pencil")
        }
        Button(role: .destructive) {
            contextMenuTargetURL = url
            showingDeleteConfirmation = true
        } label: {
            Label("Move to Trash", systemImage: "trash")
        }
    }

    func isFavorited(url: URL) -> Bool {
        if favoritesService.handles(url) {
            return favoritesService.isFavorite(url)
        }
        // Out-of-vault (or no-vault) files use the SwiftData "" bucket.
        return RecentsStore.legacyIsFavorite(url: url, vaultKey: "", in: modelContext)
    }

    func toggleFavorite(url: URL) {
        if favoritesService.handles(url) {
            favoritesService.toggle(url)
        } else {
            RecentsStore.legacyToggleFavorite(url: url, vaultKey: "", in: modelContext)
        }
    }

    // MARK: - Selection

    private func selectFile(_ url: URL?) {
        // No-op on redundant re-selection (the List can fire `set` with the
        // already-selected value during reconciliation — the open file is tagged
        // in the tree AND in Recent/Favorites, i.e. duplicate tags).
        guard url != fileTree.selectedFileURL else { return }
        fileTree.selectedFileURL = url
        guard let url else { return }
        settings.currentFileURL = url
        settings.lastOpenedFile = url.standardizedFileURL.path
        // Recents recording happens centrally in ContentView's RecentsRecorder,
        // driven by the currentFileURL change — sidebar clicks, wiki-links,
        // backlinks, graph taps and CLI opens all funnel through it.
    }

    private func performRename() {
        guard let url = contextMenuTargetURL else { return }
        if let newURL = fileTree.renameItem(at: url, to: renameFileName) {
            linkIndex.handleRename(oldURL: url, newURL: newURL)
            // Recents/favorites follow the file (handles folder renames too).
            RecentsStore.handleRename(
                oldURL: url, newURL: newURL,
                vaultKey: settings.vaultKey, in: modelContext
            )
            favoritesService.handleRename(oldURL: url, newURL: newURL)
            // Update selection if the renamed file was selected
            if settings.currentFileURL == url {
                settings.currentFileURL = newURL
                settings.lastOpenedFile = newURL.standardizedFileURL.path
            }
        }
        contextMenuTargetURL = nil
    }

    private func performDelete() {
        guard let url = contextMenuTargetURL else { return }
        if fileTree.deleteItem(at: url) {
            linkIndex.removeFromIndex(url: url)
            RecentsStore.handleDelete(url: url, vaultKey: settings.vaultKey, in: modelContext)
            favoritesService.handleDelete(url: url)
            // Clear selection if the deleted file was selected
            if settings.currentFileURL == url {
                settings.currentFileURL = nil
                settings.lastOpenedFile = ""
            }
        }
        contextMenuTargetURL = nil
    }

    /// Shared formatter — allocating a RelativeDateTimeFormatter per row per
    /// render is one of the more expensive things a List body can do.
    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private func relativeDate(_ date: Date) -> String {
        Self.relativeDateFormatter.localizedString(for: date, relativeTo: .now)
    }

    /// Routes through .glossOpenPath (GlossApp.openPath) rather than opening
    /// directly: that single route also captures the security-scoped bookmark,
    /// which this path used to skip — leaving sidebar-opened vaults
    /// unrestorable after relaunch under the sandbox (#64).
    private func openVaultFromSidebar() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Open Vault"
        if panel.runModal() == .OK, let url = panel.url {
            NotificationCenter.default.post(name: .glossOpenPath, object: url)
        }
    }
}
