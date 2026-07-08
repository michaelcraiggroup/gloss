import SwiftUI
import SwiftData

/// Sidebar "Favorites" section.
///
/// Source of truth is dual: with a vault open, favorites come from
/// `FavoritesService` (`.gloss/favorites.json` in the vault); with no vault,
/// they fall back to the SwiftData `""` bucket (loose files opened
/// Preview.app-style). Rows deliberately carry NO `.tag` — a file can appear
/// here AND in the tree, and duplicate tags in the selection-bound List
/// caused the v1.17.2 100%-CPU render loop.
///
/// The Section renders even when empty (placeholder row): removing a sidebar
/// section deallocates its header row's outline-view item, and if the cursor
/// is on that header AppKit's next tracking-area update probes the stale item
/// and segfaults (#61 — hit via Recents' Clear; same shape here when the last
/// favorite is un-starred). Leaf rows may come and go; the header must not.
struct FavoritesSection<MenuContent: View>: View {
    @Environment(FavoritesService.self) private var favoritesService
    /// No-vault fallback: favorites recorded without an open vault.
    @Query(
        filter: #Predicate<RecentDocument> { $0.isFavorite && $0.vaultPath == "" },
        sort: \RecentDocument.title
    )
    private var legacyFavorites: [RecentDocument]
    private let onSelect: (URL) -> Void
    private let onToggleFavorite: (URL) -> Void
    private let contextMenu: (URL) -> MenuContent

    init(
        onSelect: @escaping (URL) -> Void,
        onToggleFavorite: @escaping (URL) -> Void,
        @ViewBuilder contextMenu: @escaping (URL) -> MenuContent
    ) {
        self.onSelect = onSelect
        self.onToggleFavorite = onToggleFavorite
        self.contextMenu = contextMenu
    }

    var body: some View {
        Section("Favorites") {
            if favoritesService.rootURL != nil {
                if favoritesService.favorites.isEmpty {
                    emptyRow
                } else {
                    ForEach(favoritesService.favorites) { item in
                        row(
                            title: item.title,
                            icon: item.documentType.icon,
                            url: item.url,
                            missing: !item.fileExists
                        )
                    }
                }
            } else if legacyFavorites.isEmpty {
                emptyRow
            } else {
                ForEach(legacyFavorites) { doc in
                    row(title: doc.title, icon: doc.type.icon, url: doc.url, missing: false)
                }
            }
        }
    }

    private var emptyRow: some View {
        Text("No favorites yet")
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func row(title: String, icon: String, url: URL, missing: Bool) -> some View {
        HStack {
            Label {
                Text(title)
                    .lineLimit(1)
            } icon: {
                Text(icon)
            }
            .opacity(missing ? 0.5 : 1)
            if missing {
                Spacer()
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                    .help("File not found — it may exist on another device")
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect(url) }
        .contextMenu { contextMenu(url) }
        .swipeActions(edge: .trailing) {
            Button {
                onToggleFavorite(url)
            } label: {
                Label("Unfavorite", systemImage: "star.slash")
            }
            .tint(.glossAccent)
        }
    }
}
