import SwiftUI

/// The open-vault sidebar: shared favorites + recents shelves around a lazy
/// file tree (same FileTreeNode/FileTreeModel machinery as macOS, rendered
/// with DisclosureGroups). Selection funnels through `onSelect` so RootView
/// records navigation history exactly once per user-initiated open.
struct SidebarScreen: View {
    let onSelect: (URL) -> Void

    @EnvironmentObject private var settings: AppSettings
    @Environment(FileTreeModel.self) private var fileTree
    @Environment(FavoritesService.self) private var favoritesService
    @Environment(StoreManager.self) private var store
    @Environment(LinkIndex.self) private var linkIndex
    @Environment(EnhancedSearchService.self) private var enhancedSearch
    @Environment(FilenameSearchService.self) private var filenameSearch
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var searchScope: SearchScope = .filename
    @State private var showingSettings = false

    var body: some View {
        List {
            if !searchText.isEmpty {
                searchResults
            } else {
                browseSections
            }
        }
        .listStyle(.sidebar)
        // Reading Desk / Night Owl carry onto the native shelf — same tokens
        // as the Mac chrome, so navy meets navy with no black band.
        .scrollContentBackground(.hidden)
        .background(Color.glossChromeSidebar(colorScheme))
        .toolbarBackground(Color.glossChromeSidebar(colorScheme), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationTitle(fileTree.folderName)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search this vault")
        .searchScopes($searchScope) {
            Text(SearchScope.filename.rawValue).tag(SearchScope.filename)
            Text(SearchScope.content.rawValue).tag(SearchScope.content)
        }
        .onChange(of: searchText) { _, query in
            fileTree.searchQuery = query
            if searchScope == .content {
                enhancedSearch.search(query: query, database: linkIndex.databaseRef)
            } else {
                filenameSearch.search(query: query, database: linkIndex.databaseRef)
            }
        }
        .onChange(of: searchScope) { _, scope in
            // Same gate shape as macOS: content search is Pro; bounce back
            // to filenames and fire the paywall.
            if scope == .content && !store.isUnlocked {
                searchScope = .filename
                _ = store.gate(.fullTextSearch)
                return
            }
            fileTree.searchScope = scope
            if scope == .content {
                filenameSearch.cancel()
                if !searchText.isEmpty {
                    enhancedSearch.search(query: searchText, database: linkIndex.databaseRef)
                }
            } else {
                enhancedSearch.cancel()
                if !searchText.isEmpty {
                    filenameSearch.search(query: searchText, database: linkIndex.databaseRef)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    closeVault()
                } label: {
                    Label("Vaults", systemImage: "books.vertical")
                }
                .accessibilityLabel("Back to vaults")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsScreen()
        }
    }

    // MARK: - Browse (no query)

    @ViewBuilder
    private var browseSections: some View {
            FavoritesSection(
                showsShelfDivider: fileTree.activeNode != nil,
                hideWhenEmpty: true,
                onSelect: { onSelect($0) },
                onToggleFavorite: { toggleFavorite($0) }
            ) { url in
                favoriteMenu(for: url)
            }

            if let root = fileTree.activeNode {
                Section(fileTree.folderName) {
                    FileTreeOutline(
                        nodes: fileTree.sortedChildren(root.children ?? []),
                        onSelect: { onSelect($0) }
                    )
                }
            }

            RecentsSection(
                vaultKey: settings.vaultKey,
                hideWhenEmpty: true,
                onSelect: { onSelect($0) },
                onToggleFavorite: { toggleFavorite($0) }
            ) { url in
                favoriteMenu(for: url)
            }
    }

    // MARK: - Search results

    @ViewBuilder
    private var searchResults: some View {
        if searchScope == .content {
            Section("Content Results") {
                if enhancedSearch.isSearching {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Searching…").foregroundStyle(.secondary)
                    }
                } else if enhancedSearch.results.isEmpty {
                    Text("No matches").foregroundStyle(.secondary)
                } else {
                    ForEach(enhancedSearch.results) { hit in
                        resultButton(url: hit.fileURL) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(hit.title)
                                Text(hit.snippet
                                    .replacingOccurrences(of: "«", with: "")
                                    .replacingOccurrences(of: "»", with: ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
        } else {
            Section("Search Results") {
                if let results = filenameSearch.results, !results.isEmpty {
                    ForEach(results) { hit in
                        resultButton(url: hit.fileURL) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hit.title)
                                Text(hit.fileURL.deletingLastPathComponent().lastPathComponent)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                } else {
                    Text("No matches").foregroundStyle(.secondary)
                }
            }
        }
    }

    private func resultButton(url: URL, @ViewBuilder label: () -> some View) -> some View {
        Button {
            onSelect(url)
        } label: {
            HStack {
                label()
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func favoriteMenu(for url: URL) -> some View {
        Button {
            toggleFavorite(url)
        } label: {
            if favoritesService.isFavorite(url) {
                Label("Remove Favorite", systemImage: "star.slash")
            } else {
                Label("Add to Favorites", systemImage: "star")
            }
        }
    }

    private func toggleFavorite(_ url: URL) {
        guard store.gate(.favorites) else { return }
        favoritesService.toggle(url)
    }

    private func closeVault() {
        settings.currentFileURL = nil
        linkIndex.close()
        fileTree.closeFolder()
        settings.rootFolderPath = ""
    }
}

/// Recursive lazy tree: expanding a directory loads its children on demand
/// (FileTreeNode.children == nil means not-yet-listed), mirroring the macOS
/// sidebar's one-level-at-a-time enumeration.
private struct FileTreeOutline: View {
    let nodes: [FileTreeNode]
    let onSelect: (URL) -> Void

    @Environment(FileTreeModel.self) private var fileTree

    var body: some View {
        ForEach(nodes) { node in
            if node.isDirectory {
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { node.isExpanded },
                        set: { expanded in
                            node.isExpanded = expanded
                            if expanded && node.children == nil {
                                node.loadChildren()
                            }
                        }
                    )
                ) {
                    FileTreeOutline(
                        nodes: fileTree.sortedChildren(node.children ?? []),
                        onSelect: onSelect
                    )
                } label: {
                    FileTreeRow(node: node)
                }
            } else {
                Button {
                    onSelect(node.url)
                } label: {
                    HStack {
                        FileTreeRow(node: node)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
