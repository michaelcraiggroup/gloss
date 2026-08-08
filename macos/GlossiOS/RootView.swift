import SwiftUI

/// Root navigation shell: NavigationSplitView collapses to a stack on
/// iPhone and stays a real split on iPad. Applies the shared vault-session
/// modifiers and owns paywall presentation — the iOS observer of
/// `.glossShowPaywall`, mirroring macOS ContentView.
struct RootView: View {
    let vaultCatalog: any VaultCatalogProviding
    let pairingHandler: PairingHandler

    @EnvironmentObject private var settings: AppSettings
    @Environment(FileTreeModel.self) private var fileTree
    @Environment(StoreManager.self) private var store
    @Environment(LinkIndex.self) private var linkIndex
    @Environment(FavoritesService.self) private var favoritesService
    @Environment(UbiquityVaultStore.self) private var ubiquityStore
    @State private var paywallFeature: PaidFeature?
    @State private var navHistory = NavigationHistory()
    @State private var showingPairing = false
    /// On iPhone (compact) the split view shows one column at a time —
    /// programmatic navigation must also steer the visible column, or a
    /// sidebar tap changes state with no visible transition.
    @State private var preferredColumn: NavigationSplitViewColumn = .sidebar

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $preferredColumn) {
            if fileTree.hasFolder {
                SidebarScreen(onSelect: openFile)
            } else {
                VaultListScreen(catalog: vaultCatalog, onPair: { showingPairing = true })
            }
        } detail: {
            if let url = settings.currentFileURL {
                ReaderScreen(
                    fileURL: url,
                    highlightQuery: fileTree.searchScope == .content ? fileTree.searchQuery : nil,
                    navHistory: navHistory)
            } else {
                detailPlaceholder
            }
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
                openFile(url)
            }
        }
        .onChange(of: settings.currentFileURL) { _, newValue in
            if newValue == nil {
                preferredColumn = .sidebar
            }
        }
        // One pairing surface for both doorways: the in-app scanner opens it
        // by hand; a Camera-app deep link opens it by state change.
        .sheet(isPresented: $showingPairing, onDismiss: {
            if case .done = pairingHandler.state { pairingHandler.reset() }
            if pairingHandler.state == .invalidCode { pairingHandler.reset() }
        }) {
            PairingScanScreen(handler: pairingHandler)
        }
        .onChange(of: pairingHandler.state) { _, newState in
            if newState != .idle {
                showingPairing = true
            }
        }
        .onChange(of: ubiquityStore.state) {
            // Pairing may be parked on needsICloud — retry when it resolves.
            pairingHandler.advance()
        }
        .onChange(of: store.isUnlocked) { _, unlocked in
            // Parked on needsPro — the purchase completes the pairing.
            if unlocked { pairingHandler.advance() }
        }
    }

    /// The single user-initiated open path (sidebar taps + wiki-link clicks):
    /// records history exactly once, then navigates. Back/Forward set
    /// `currentFileURL` directly and bypass recording, matching macOS.
    private func openFile(_ url: URL) {
        navHistory.navigate(to: url, from: settings.currentFileURL)
        settings.currentFileURL = url
        settings.lastOpenedFile = url.standardizedFileURL.path
        preferredColumn = .detail
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
                Text("Select a note to start reading.")
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
