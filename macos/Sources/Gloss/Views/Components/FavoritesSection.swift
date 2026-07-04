import SwiftUI
import SwiftData

/// Sidebar "Favorites" section, scoped to the current vault bucket.
///
/// The vault key is baked into the `@Query` at init (SwiftData predicates
/// can't reference runtime state), so SidebarView re-creates this view with a
/// new key whenever the vault changes. Rows deliberately carry NO `.tag` —
/// a file can appear here AND in the tree, and duplicate tags in the
/// selection-bound List caused the v1.17.2 100%-CPU render loop.
struct FavoritesSection<MenuContent: View>: View {
    @Query private var favorites: [RecentDocument]
    private let onSelect: (URL) -> Void
    private let onToggleFavorite: (URL) -> Void
    private let contextMenu: (URL) -> MenuContent

    init(
        vaultKey: String,
        onSelect: @escaping (URL) -> Void,
        onToggleFavorite: @escaping (URL) -> Void,
        @ViewBuilder contextMenu: @escaping (URL) -> MenuContent
    ) {
        _favorites = Query(
            filter: #Predicate<RecentDocument> { $0.isFavorite && $0.vaultPath == vaultKey },
            sort: \RecentDocument.title
        )
        self.onSelect = onSelect
        self.onToggleFavorite = onToggleFavorite
        self.contextMenu = contextMenu
    }

    var body: some View {
        if !favorites.isEmpty {
            Section("Favorites") {
                ForEach(favorites) { doc in
                    Label {
                        Text(doc.title)
                            .lineLimit(1)
                    } icon: {
                        Text(doc.type.icon)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(doc.url) }
                    .contextMenu { contextMenu(doc.url) }
                    .swipeActions(edge: .trailing) {
                        Button {
                            onToggleFavorite(doc.url)
                        } label: {
                            Label("Unfavorite", systemImage: "star.slash")
                        }
                        .tint(.glossAccent)
                    }
                }
            }
        }
    }
}
