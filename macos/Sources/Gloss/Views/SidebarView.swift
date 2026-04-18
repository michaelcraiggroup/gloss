import AppKit
import SwiftUI
import SwiftData

/// File browser sidebar with recursive file tree, search, favorites, and recent documents.
struct SidebarView: View {
    @Environment(FileTreeModel.self) private var fileTree
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var store
    @Query(sort: \RecentDocument.lastOpened, order: .reverse)
    private var recentDocuments: [RecentDocument]
    @Query(filter: #Predicate<RecentDocument> { $0.isFavorite },
           sort: \RecentDocument.title)
    private var favoriteDocuments: [RecentDocument]
    @Environment(EnhancedSearchService.self) private var enhancedSearch
    @Environment(LinkIndex.self) private var linkIndex
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
            } else if let results = fileTree.searchResults,
                      searchScope == .filename {
                Section("Search Results") {
                    if results.isEmpty {
                        Text("No matches")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(results) { node in
                            FileTreeRow(node: node)
                                .tag(node.url)
                                .contextMenu { favoriteContextMenu(for: node.url) }
                        }
                    }
                }
            } else if searchScope == .filename || searchScope == .tags {
                // Normal browsing mode (no search active, or tags scope without query)
                browseSection

                if !favoriteDocuments.isEmpty {
                    Section("Favorites") {
                        ForEach(favoriteDocuments) { doc in
                            Label {
                                Text(doc.title)
                                    .lineLimit(1)
                            } icon: {
                                Text(doc.type.icon)
                            }
                            .tag(doc.url)
                            .contextMenu { favoriteContextMenu(for: doc.url) }
                            .swipeActions(edge: .trailing) {
                                Button {
                                    toggleFavorite(url: doc.url)
                                } label: {
                                    Label("Unfavorite", systemImage: "star.slash")
                                }
                                .tint(.yellow)
                            }
                        }
                    }
                }

                if !linkIndex.recentlyChanged.isEmpty {
                    Section("Recently Changed") {
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
                            .tag(url)
                            .contextMenu { favoriteContextMenu(for: url) }
                        }
                    }
                }

                if !linkIndex.allTags.isEmpty {
                    Section("Tags") {
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
                    }
                    .spotlightTarget(.sidebarTagsSection)
                }

                if !recentDocuments.isEmpty {
                    Section("Recent Documents") {
                        ForEach(recentDocuments.prefix(10)) { doc in
                            HStack {
                                Label {
                                    Text(doc.title)
                                        .lineLimit(1)
                                } icon: {
                                    Text(doc.type.icon)
                                }
                                Spacer()
                                Button {
                                    toggleFavorite(url: doc.url)
                                } label: {
                                    Image(systemName: isFavorited(url: doc.url) ? "star.fill" : "star")
                                        .foregroundStyle(isFavorited(url: doc.url) ? .yellow : .secondary)
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                            .tag(doc.url)
                            .contextMenu { favoriteContextMenu(for: doc.url) }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
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
            } else if scope == .filename || scope == .tags {
                enhancedSearch.cancel()
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

                Button {
                    guard store.gate(.folderSidebar) else { return }
                    openFolderFromSidebar()
                } label: {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
                .help("Open Folder (⇧⌘O)")

                Button {
                    NotificationCenter.default.post(name: .glossShowGraph, object: nil)
                } label: {
                    Label("Vault Graph", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .help("Show Vault Graph (⌥⌘G)")
                .disabled(!fileTree.hasFolder)
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
                .fill(isActive ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
        )
        .foregroundStyle(isActive ? Color.accentColor : .secondary)
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

        if let active = fileTree.activeNode {
            Section {
                ForEach(fileTree.sortedChildren(active.children ?? [])) { node in
                    fileTreeItem(node)
                }
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(active.url.path)
                        .lineLimit(1)
                        .truncationMode(.head)
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
        favoriteDocuments.contains { $0.path == url.path }
    }

    func toggleFavorite(url: URL) {
        let path = url.path
        let descriptor = FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.path == path }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.isFavorite.toggle()
        } else {
            // Create a new RecentDocument marked as favorite
            let filename = url.lastPathComponent
            let parentFolder = url.deletingLastPathComponent().lastPathComponent
            let docType = DocumentType.detect(filename: filename, folderName: parentFolder)
            let title = filename.replacingOccurrences(of: ".md", with: "")
                .replacingOccurrences(of: ".markdown", with: "")
            let doc = RecentDocument(path: path, title: title, documentType: docType.rawValue, isFavorite: true)
            modelContext.insert(doc)
        }
    }

    // MARK: - Selection & Recents

    private func selectFile(_ url: URL?) {
        fileTree.selectedFileURL = url
        guard let url else { return }
        settings.currentFileURL = url
        settings.lastOpenedFile = url.standardizedFileURL.path
        recordRecent(url: url)
    }

    private func recordRecent(url: URL) {
        let path = url.standardizedFileURL.path
        let filename = url.lastPathComponent
        let parentFolder = url.deletingLastPathComponent().lastPathComponent
        let docType = DocumentType.detect(filename: filename, folderName: parentFolder)

        let descriptor = FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.path == path }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.lastOpened = .now
            existing.documentType = docType.rawValue
        } else {
            let title = filename.replacingOccurrences(of: ".md", with: "")
                .replacingOccurrences(of: ".markdown", with: "")
            let doc = RecentDocument(path: path, title: title, documentType: docType.rawValue)
            modelContext.insert(doc)
        }
    }

    private func performRename() {
        guard let url = contextMenuTargetURL else { return }
        if let newURL = fileTree.renameItem(at: url, to: renameFileName) {
            linkIndex.handleRename(oldURL: url, newURL: newURL)
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
            // Clear selection if the deleted file was selected
            if settings.currentFileURL == url {
                settings.currentFileURL = nil
                settings.lastOpenedFile = ""
            }
        }
        contextMenuTargetURL = nil
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private func openFolderFromSidebar() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Open Folder"
        if panel.runModal() == .OK, let url = panel.url {
            fileTree.openFolder(url)
            settings.rootFolderPath = url.path
            linkIndex.buildIndex(rootURL: url)
        }
    }
}
