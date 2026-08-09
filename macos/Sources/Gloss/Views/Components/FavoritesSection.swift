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
    /// Favorites is the first shelf under the vault's documents, so it carries
    /// the rule that separates the two tiers (hidden when no vault is open and
    /// there is nothing above it to divide from).
    private let showsShelfDivider: Bool
    private let onSelect: (URL) -> Void
    private let onToggleFavorite: (URL) -> Void
    private let contextMenu: (URL) -> MenuContent

    /// iOS passes true: an empty shelf renders nothing at all — sections are
    /// earned by content (Notes-style). macOS keeps its shipped empty rows.
    private let hideWhenEmpty: Bool

    /// macOS passes a persisted binding: the shelf collapses to its header
    /// (children hidden by default — the sidebar leads with the vault's own
    /// documents). nil (iOS) keeps the always-expanded shelf. Collapsing
    /// hides LEAF rows only — the header row persists, which is the #61
    /// tracking-area rule this section already lives by.
    private let isExpanded: Binding<Bool>?

    init(
        showsShelfDivider: Bool = false,
        hideWhenEmpty: Bool = false,
        isExpanded: Binding<Bool>? = nil,
        onSelect: @escaping (URL) -> Void,
        onToggleFavorite: @escaping (URL) -> Void,
        @ViewBuilder contextMenu: @escaping (URL) -> MenuContent
    ) {
        self.showsShelfDivider = showsShelfDivider
        self.hideWhenEmpty = hideWhenEmpty
        self.isExpanded = isExpanded
        self.onSelect = onSelect
        self.onToggleFavorite = onToggleFavorite
        self.contextMenu = contextMenu
    }

    private var isEmpty: Bool {
        favoritesService.rootURL != nil
            ? favoritesService.favorites.isEmpty
            : legacyFavorites.isEmpty
    }

    var body: some View {
        if hideWhenEmpty && isEmpty {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        Section {
            if isExpanded?.wrappedValue ?? true {
                rows
            }
        } header: {
            headerView
        }
    }

    @ViewBuilder
    private var rows: some View {
        if favoritesService.rootURL != nil {
            if favoritesService.favorites.isEmpty {
                emptyRow
            } else {
                ForEach(favoritesService.favorites) { item in
                    row(
                        title: item.title,
                        type: item.documentType,
                        url: item.url,
                        missing: !item.fileExists
                    )
                }
            }
        } else if legacyFavorites.isEmpty {
            emptyRow
        } else {
            ForEach(legacyFavorites) { doc in
                row(title: doc.title, type: doc.type, url: doc.url, missing: false)
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showsShelfDivider {
                // Air on BOTH sides of the hairline: above it (off the
                // vault's documents) and below it (off the Favorites
                // header) — the header hugging the line read as cramped.
                GlossShelfDivider()
                    .padding(.top, 10)
                    .padding(.bottom, 8)
            }
            if let isExpanded {
                ShelfToggleHeader(title: "Favorites", isExpanded: isExpanded)
            } else {
                Text("Favorites").glossShelfHeader()
            }
        }
    }

    private var emptyRow: some View {
        Text("No favorites yet")
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func row(title: String, type: DocumentType, url: URL, missing: Bool) -> some View {
        HStack {
            Label {
                Text(title)
                    .lineLimit(1)
            } icon: {
                DocumentTypeIcon(type: type)
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
