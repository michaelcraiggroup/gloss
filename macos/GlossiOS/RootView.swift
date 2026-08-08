import SwiftUI

/// Root navigation shell: NavigationSplitView collapses to a stack on
/// iPhone and stays a real split on iPad. Applies the shared vault-session
/// modifiers and owns paywall presentation — the iOS observer of
/// `.glossShowPaywall`, mirroring macOS ContentView.
struct RootView: View {
    let vaultCatalog: any VaultCatalogProviding
    let pairingHandler: LoggingPairingHandler

    @EnvironmentObject private var settings: AppSettings
    @Environment(FileTreeModel.self) private var fileTree
    @Environment(StoreManager.self) private var store
    @Environment(LinkIndex.self) private var linkIndex
    @Environment(FavoritesService.self) private var favoritesService
    @State private var paywallFeature: PaidFeature?

    var body: some View {
        NavigationSplitView {
            VaultListScreen(catalog: vaultCatalog, pairingHandler: pairingHandler)
        } detail: {
            detailPlaceholder
        }
        .modifier(FolderWatchHandler(
            fileTree: fileTree, linkIndex: linkIndex, favoritesService: favoritesService))
        .modifier(RecentsRecorder(
            currentFileURL: settings.currentFileURL, vaultKey: settings.vaultKey))
        .modifier(VaultLifecycleHandler(
            rootURL: fileTree.rootNode?.url, favoritesService: favoritesService))
        .onReceive(NotificationCenter.default.publisher(for: .glossShowPaywall)) { note in
            paywallFeature = note.object as? PaidFeature
        }
        .sheet(item: $paywallFeature) { feature in
            PaywallView(feature: feature)
                .environment(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .glossNavigateWikiLink)) { note in
            guard store.gate(.wikiLinks) else { return }
            if let url = note.object as? URL {
                settings.currentFileURL = url
                settings.lastOpenedFile = url.standardizedFileURL.path
            }
        }
    }

    @ViewBuilder
    private var detailPlaceholder: some View {
        if let root = fileTree.rootNode?.url {
            VStack(spacing: 12) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 44))
                    .foregroundStyle(.tertiary)
                Text(root.lastPathComponent)
                    .font(.title3)
                Text("Vault open — the reader arrives in the next milestone PR.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 44))
                    .foregroundStyle(.tertiary)
                Text("It opens to read.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Choose a vault to get started.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
