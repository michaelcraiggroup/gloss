import SwiftUI

// Vault-session glue, shared by both app shells (macOS ContentView today,
// iOS RootView next). Extracted verbatim from ContentView — same module, so
// call sites are unchanged. These three modifiers are the entire reaction
// surface for "the vault changed on disk / a file was opened / a vault was
// opened or closed"; re-deriving them per-platform would re-fight old bugs
// (the 100%-CPU recents loop, the importFavorites-before-prune ordering).

// MARK: - FolderWatchHandler ViewModifier

/// Reacts to folder-watcher events off the main body (type-checker relief).
/// Reconciles the sidebar tree and brings the link index up to date when the
/// FSEvents watcher reports on-disk changes under the open vault.
struct FolderWatchHandler: ViewModifier {
    let fileTree: FileTreeModel
    let linkIndex: LinkIndex
    let favoritesService: FavoritesService

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .glossVaultFilesChanged)) { notification in
                if let paths = notification.object as? [String] {
                    fileTree.reconcile(changedPaths: paths)
                    linkIndex.handleExternalChanges(paths: paths)
                } else {
                    fileTree.refreshAfterFileChange()
                }
                // Missing-favorite dimming heals when sync delivers a file
                // (and engages when one disappears on disk).
                favoritesService.refreshExistence()
            }
            .onReceive(NotificationCenter.default.publisher(for: .glossFavoritesFileChanged)) { _ in
                // Another device's favorites arrived (or our own write echoed
                // back — reload writes nothing, so no ping-pong).
                favoritesService.reloadFromDisk()
            }
    }
}

// MARK: - RecentsRecorder ViewModifier

/// The single site that records recents (type-checker relief pattern, like
/// FolderWatchHandler). Every open funnels through `settings.currentFileURL`
/// — sidebar clicks, wiki-links, backlinks, breadcrumbs, graph taps, ⌘[/⌘],
/// CLI/panel opens — so recording here covers them all. Guide sample docs
/// live in the temp directory and are skipped.
struct RecentsRecorder: ViewModifier {
    let currentFileURL: URL?
    let vaultKey: String
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content
            .onChange(of: currentFileURL) { _, newValue in
                guard let url = newValue, !RecentsStore.isTemporary(url) else { return }
                let key = vaultKey
                let context = modelContext
                // Defer the SwiftData write one tick: recording bumps
                // `lastOpened`, reordering the lastOpened-sorted Recents
                // @Query. Writing while the selection-driven update is still
                // settling re-fired selection in the past (100%-CPU render
                // loop) — next-tick keeps that class of bug buried.
                DispatchQueue.main.async {
                    RecentsStore.record(url: url, vaultKey: key, in: context)
                }
            }
    }
}

// MARK: - VaultLifecycleHandler ViewModifier

/// One reaction point for "a vault was opened or closed" (rootNode is only
/// assigned in FileTreeModel.openFolder/closeFolder). Points FavoritesService
/// at the new root, claims pre-1.20 unscoped rows into the vault's bucket,
/// and prunes dead recents. All operations are idempotent — a second window
/// (⌘N) re-running them is harmless.
struct VaultLifecycleHandler: ViewModifier {
    let rootURL: URL?
    let favoritesService: FavoritesService
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content
            .onChange(of: rootURL, initial: true) { _, newValue in
                favoritesService.configure(rootURL: newValue)
                guard let root = newValue else { return }
                // Covers every open path (panel, sidebar, CLI, restore).
                settings.recordRecentVault(root.path)
                let key = RecentsStore.vaultKey(forRoot: root)
                RecentsStore.claimLegacyRows(root: root, vaultKey: key, in: modelContext)
                // Pre-1.20 SwiftData favorites migrate into the vault file.
                // Must run BEFORE prune: cleared flags drop the rows'
                // favorite protection.
                favoritesService.importFavorites(
                    urls: RecentsStore.claimFavoriteFlags(vaultKey: key, in: modelContext)
                )
                RecentsStore.prune(vaultKey: key, in: modelContext)
            }
    }
}

/// macOS reading immersion + navigation session (iPhone-parity, 2026-08-09):
/// entering a document hides the sidebar; returning to the overview brings it
/// back. Keyed on the has-document BOOLEAN so document→document navigation
/// never refires — a sidebar the user reopened mid-read is respected. Zen
/// mode owns the column exclusively while active; exiting zen restores the
/// document-appropriate state instead of blanket `.automatic`. Vault identity
/// changes reset back/forward history (cross-vault entries would navigate
/// into a closed vault).
struct ReadingSessionHandler: ViewModifier {
    let hasDocument: Bool
    let isZenMode: Bool
    let vaultRootPath: String?
    @Binding var columnVisibility: NavigationSplitViewVisibility
    let navHistory: NavigationHistory

    func body(content: Content) -> some View {
        content
            .onChange(of: hasDocument) { _, hasDoc in
                guard !isZenMode else { return }
                withAnimation {
                    columnVisibility = hasDoc ? .detailOnly : .all
                }
            }
            .onChange(of: isZenMode) {
                columnVisibility = isZenMode
                    ? .detailOnly
                    : (hasDocument ? .detailOnly : .all)
            }
            .onChange(of: vaultRootPath) {
                navHistory.reset()
            }
    }
}
