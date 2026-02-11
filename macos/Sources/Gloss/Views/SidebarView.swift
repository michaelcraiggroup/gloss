import SwiftUI
import SwiftData

/// File browser sidebar with recursive file tree, search, favorites, and recent documents.
struct SidebarView: View {
    @Environment(FileTreeModel.self) private var fileTree
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RecentDocument.lastOpened, order: .reverse)
    private var recentDocuments: [RecentDocument]
    @Query(filter: #Predicate<RecentDocument> { $0.isFavorite },
           sort: \RecentDocument.title)
    private var favoriteDocuments: [RecentDocument]
    @Environment(ContentSearchService.self) private var contentSearch
    @State private var searchText = ""
    @State private var searchScope: SearchScope = .filename

    var body: some View {
        List(selection: Binding(
            get: { fileTree.selectedFileURL },
            set: { selectFile($0) }
        )) {
            if searchScope == .content && !searchText.isEmpty {
                // Content search results
                Section("Content Results") {
                    if contentSearch.isSearching {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text("Searching…")
                                .foregroundStyle(.secondary)
                        }
                    } else if contentSearch.results.isEmpty {
                        Text("No matches")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(contentSearch.results) { result in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(result.documentType.icon)
                                        .font(.caption)
                                    Text(result.fileName)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Text("L\(result.lineNumber)")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                Text(result.lineContent)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .tag(result.fileURL)
                            .contextMenu { favoriteContextMenu(for: result.fileURL) }
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
            } else if searchScope == .filename {
                // Normal browsing mode (no search active)
                if let root = fileTree.rootNode {
                    Section(root.name) {
                        ForEach(root.children ?? []) { node in
                            fileTreeItem(node)
                        }
                    }
                }

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
                contentSearch.search(query: query, rootURL: fileTree.rootNode?.url)
            }
        }
        .onChange(of: searchScope) { _, scope in
            fileTree.searchScope = scope
            if scope == .content && !searchText.isEmpty {
                contentSearch.search(query: searchText, rootURL: fileTree.rootNode?.url)
            } else if scope == .filename {
                contentSearch.cancel()
                contentSearch.results = []
            }
        }
        .toolbar {
            ToolbarItem {
                Button {
                    openFolderFromSidebar()
                } label: {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                }
                .help("Open Folder (⇧⌘O)")
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
                    ForEach(node.children ?? []) { child in
                        fileTreeItem(child)
                    }
                } label: {
                    FileTreeRow(node: node)
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
        settings.lastOpenedFile = url.path
        recordRecent(url: url)
    }

    private func recordRecent(url: URL) {
        let path = url.path
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

    private func openFolderFromSidebar() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.title = "Open Folder"
        if panel.runModal() == .OK, let url = panel.url {
            fileTree.openFolder(url)
            settings.rootFolderPath = url.path
        }
    }
}
