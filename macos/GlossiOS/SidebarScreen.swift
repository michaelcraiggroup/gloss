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

    var body: some View {
        List {
            FavoritesSection(
                showsShelfDivider: fileTree.activeNode != nil,
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
                onSelect: { onSelect($0) },
                onToggleFavorite: { toggleFavorite($0) }
            ) { url in
                favoriteMenu(for: url)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(fileTree.folderName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    closeVault()
                } label: {
                    Label("Vaults", systemImage: "books.vertical")
                }
                .accessibilityLabel("Back to vaults")
            }
        }
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
