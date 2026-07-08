import SwiftUI
import SwiftData

/// Sidebar "Recent Documents" section, scoped to the current vault bucket.
///
/// The recents query is bounded to what the sidebar actually shows — the old
/// unbounded sort-everything fetch re-ran inside List body evaluation (the
/// render-loop stack in the 2026-07-01 CPU diagnostics). Rows carry NO `.tag`
/// (see FavoritesSection — duplicate tags looped the selection List).
///
/// The Section renders even when empty (placeholder row): Clear lives in the
/// header, so the cursor is on that row when the recents empty — removing the
/// whole section deallocated the hovered header's outline-view item and
/// crashed AppKit's tracking-area update (#61). Leaf rows may come and go;
/// the header must not.
struct RecentsSection<MenuContent: View>: View {
    @Query private var recents: [RecentDocument]
    /// No-vault fallback for star state; with a vault open the stars read
    /// FavoritesService (observable — a fetchCount closure would freeze them).
    @Query(filter: #Predicate<RecentDocument> { $0.isFavorite && $0.vaultPath == "" })
    private var legacyFavorites: [RecentDocument]
    @Environment(FavoritesService.self) private var favoritesService
    @Environment(\.modelContext) private var modelContext
    private let vaultKey: String
    private let onSelect: (URL) -> Void
    private let onToggleFavorite: (URL) -> Void
    private let contextMenu: (URL) -> MenuContent

    init(
        vaultKey: String,
        onSelect: @escaping (URL) -> Void,
        onToggleFavorite: @escaping (URL) -> Void,
        @ViewBuilder contextMenu: @escaping (URL) -> MenuContent
    ) {
        var descriptor = FetchDescriptor<RecentDocument>(
            predicate: #Predicate { $0.vaultPath == vaultKey },
            sortBy: [SortDescriptor(\.lastOpened, order: .reverse)]
        )
        descriptor.fetchLimit = 10
        _recents = Query(descriptor)
        self.vaultKey = vaultKey
        self.onSelect = onSelect
        self.onToggleFavorite = onToggleFavorite
        self.contextMenu = contextMenu
    }

    var body: some View {
        // One Set per body pass instead of an O(favorites) scan
        // per row per render.
        let favoritePaths: Set<String> = favoritesService.rootURL != nil
            ? Set(favoritesService.favorites.map { RecentsStore.canonicalPath($0.url) })
            : Set(legacyFavorites.map(\.path))
        Section {
            if recents.isEmpty {
                Text("No recent documents")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recents) { doc in
                    let favorited = favoritePaths.contains(doc.path)
                    HStack {
                        Label {
                            Text(doc.title)
                                .lineLimit(1)
                        } icon: {
                            Text(doc.type.icon)
                        }
                        Spacer()
                        Button {
                            onToggleFavorite(doc.url)
                        } label: {
                            Image(systemName: favorited ? "star.fill" : "star")
                                .foregroundStyle(favorited ? .yellow : .secondary)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(doc.url) }
                    .contextMenu { contextMenu(doc.url) }
                }
            }
        } header: {
            HStack {
                Text("Recent Documents")
                Spacer()
                if !recents.isEmpty {
                    Button("Clear") {
                        RecentsStore.clearRecents(vaultKey: vaultKey, in: modelContext)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .help("Remove all recent documents for this vault")
                }
            }
        }
    }
}
