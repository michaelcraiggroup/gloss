import SwiftUI
import CoreSpotlight
import os

private let wikiNavLog = Logger(subsystem: "group.michaelcraig.gloss", category: "wikinav")

/// Root navigation shell: NavigationSplitView collapses to a stack on
/// iPhone and stays a real split on iPad. Documents are REAL navigation
/// pushes — the detail column hosts a NavigationStack whose path IS the
/// document history, so swipe-back is doc-back, pushes animate, and
/// long-pressing the system back button shows the trail. All platform
/// behavior; no parallel history stacks to keep honest.
///
/// Also owns paywall + pairing presentation (the iOS observers of
/// `.glossShowPaywall` / pairing state, mirroring macOS ContentView) and
/// cold-launch session restore — "opens to read", literally.
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
    @State private var showingPairing = false
    /// The document trail — the single source of navigation truth.
    @State private var docPath: [URL] = []
    @State private var didRestoreSession = false
    @Environment(\.colorScheme) private var colorScheme
    /// On iPhone (compact) the split view shows one column at a time —
    /// programmatic navigation must also steer the visible column, or a
    /// sidebar tap changes state with no visible transition.
    @State private var preferredColumn: NavigationSplitViewColumn = .sidebar

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $preferredColumn) {
            if fileTree.hasFolder {
                SidebarScreen(onSelect: { openFile($0) })
            } else {
                VaultListScreen(catalog: vaultCatalog, onPair: { showingPairing = true })
            }
        } detail: {
            NavigationStack(path: $docPath) {
                detailPlaceholder
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.glossChromeBg(colorScheme).ignoresSafeArea())
                    .navigationDestination(for: URL.self) { url in
                        ReaderScreen(
                            fileURL: url,
                            highlightQuery: fileTree.searchScope == .content
                                ? fileTree.searchQuery : nil)
                    }
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
            wikiNavLog.info(
                "wiki notification object=\(String(describing: note.object), privacy: .public)")
            guard store.gate(.wikiLinks) else {
                wikiNavLog.info("wiki nav blocked by gate")
                return
            }
            if let url = note.object as? URL {
                openFile(url, push: true)
            }
        }
        .onChange(of: docPath) { _, newPath in
            wikiNavLog.info("docPath changed count=\(newPath.count)")
            // The stack top is "the current document" — recents recording,
            // backlink refresh, and macOS-parity state all key off it.
            settings.currentFileURL = newPath.last
            if let top = newPath.last {
                settings.lastOpenedFile = top.standardizedFileURL.path
            } else {
                // Popping the last document (back chevron / edge swipe on the
                // top-level note) must reveal the SIDEBAR on iPhone, not the
                // empty-detail placeholder (#98). Deferred one tick: a
                // compact-column write DURING the pop transition is swallowed
                // by NavigationSplitView (device-verified).
                Task { @MainActor in
                    preferredColumn = .sidebar
                }
            }
        }
        .onChange(of: settings.currentFileURL) { _, newValue in
            // Close Vault nils this out — clear the trail and show the sidebar.
            if newValue == nil {
                if !docPath.isEmpty { docPath = [] }
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
            // Pairing may be parked on needsICloud, and a container-vault
            // restore defers until the container resolves — retry both.
            pairingHandler.advance()
            restoreSession()
        }
        .onChange(of: store.isUnlocked) { _, unlocked in
            // Parked on needsPro — the purchase completes pairing/restore.
            if unlocked {
                pairingHandler.advance()
                restoreSession()
            }
        }
        .task {
            restoreSession()
        }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            if let path = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String {
                openSpotlightResult(path: path)
            }
        }
    }

    /// A system-search result was tapped. Same vault → straight open;
    /// another container vault → switch to it first; unknown/missing → ignore
    /// (the stale item ages out of Spotlight on the next index pass).
    private func openSpotlightResult(path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        let url = URL(fileURLWithPath: path)
        if let root = fileTree.rootNode?.url, RecentsStore.isPath(path, underRoot: root) {
            openFile(url)
            return
        }
        guard let root = SpotlightIndexer.vaultRoot(forNotePath: path),
              store.gate(.folderSidebar) else { return }
        settings.currentFileURL = nil
        linkIndex.close()
        fileTree.closeFolder()
        fileTree.openFolder(root)
        settings.rootFolderPath = root.path
        linkIndex.buildIndex(rootURL: root)
        openFile(url)
    }

    /// The single user-initiated open path. Sidebar taps RESET the trail to
    /// the tapped note (Notes-style — selection, not accumulation);
    /// wiki-link taps PUSH so swipe-back returns to the source note.
    private func openFile(_ url: URL, push: Bool = false) {
        wikiNavLog.info(
            "openFile push=\(push) file=\(url.lastPathComponent, privacy: .public) trail=\(docPath.count)")
        if push {
            guard docPath.last != url else { return }
            docPath.append(url)
        } else {
            docPath = [url]
        }
        preferredColumn = .detail
    }

    /// Cold launch reopens the last vault and the note that was on screen —
    /// mirroring macOS restoreFolder, including the unlock and
    /// container-availability retries (wired in onChange above).
    private func restoreSession() {
        guard !didRestoreSession else { return }
        if fileTree.hasFolder {
            // Something else (pairing, user) opened a vault first — done.
            didRestoreSession = true
            return
        }
        guard store.isUnlocked else { return }
        let rootPath = settings.rootFolderPath
        guard !rootPath.isEmpty else { return }
        let root = URL(fileURLWithPath: rootPath)
        if UbiquityVaultStore.isUbiquitousPath(root) {
            // Container not readable until this launch's ubiquity bootstrap
            // resolves — the ubiquityStore.state onChange retries.
            guard case .available = ubiquityStore.state else { return }
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            didRestoreSession = true
            return
        }

        didRestoreSession = true
        fileTree.openFolder(root)
        linkIndex.buildIndex(rootURL: root)

        let lastFile = settings.lastOpenedFile
        if !lastFile.isEmpty,
           RecentsStore.isPath(lastFile, underRoot: root),
           FileManager.default.fileExists(atPath: lastFile) {
            docPath = [URL(fileURLWithPath: lastFile)]
            preferredColumn = .detail
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
                Text("Select a note to start reading.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            // Belt-and-braces for #98: on iPhone this placeholder should
            // never be the visible page — whatever path lands here, hand
            // focus back to the sidebar. Inert on iPad regular width
            // (preferredCompactColumn only applies when compact).
            .onAppear {
                wikiNavLog.info("detail placeholder appeared — steering to sidebar")
                preferredColumn = .sidebar
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
