import SwiftUI
import SwiftData

/// iOS shell entry point. Mirrors GlossApp's service graph minus the
/// AppKit-only members (menu bar, quick-capture hot corner, template fill,
/// graph). Reader + vault-sync surfaces arrive over PRs 8–11; this shell
/// already wires the shared services, the paywall, and the gloss:// route.
@main
struct GlossiOSApp: App {
    @StateObject private var settings = AppSettings()
    @State private var fileTree: FileTreeModel
    @State private var enhancedSearch = EnhancedSearchService()
    @State private var filenameSearch = FilenameSearchService()
    @State private var store = StoreManager()
    @State private var linkIndex = LinkIndex()
    @State private var favoritesService = FavoritesService()
    @State private var vaultOverview = VaultOverviewService()
    @State private var ubiquityStore: UbiquityVaultStore
    @State private var vaultCatalog: ContainerVaultCatalog
    @State private var pairingHandler = LoggingPairingHandler()

    init() {
        let ubiquity = UbiquityVaultStore()
        _ubiquityStore = State(initialValue: ubiquity)
        _vaultCatalog = State(initialValue: ContainerVaultCatalog(ubiquityStore: ubiquity))
        // Container vaults get live updates + eager markdown download via the
        // metadata query; sandbox-local vaults fall back to no observation
        // (the observer refuses non-container roots), matching macOS's
        // failed-watcher semantics.
        _fileTree = State(initialValue: FileTreeModel(vaultObserver: UbiquityVaultObserver()))
    }

    var body: some Scene {
        WindowGroup {
            RootView(vaultCatalog: vaultCatalog, pairingHandler: pairingHandler)
                .tint(.glossAccent)
                .environmentObject(settings)
                .environment(fileTree)
                .environment(enhancedSearch)
                .environment(filenameSearch)
                .environment(store)
                .environment(linkIndex)
                .environment(favoritesService)
                .environment(vaultOverview)
                .environment(ubiquityStore)
                .preferredColorScheme(settings.colorSchemeAppearance.colorScheme)
                .task {
                    ubiquityStore.start()
                    Task.detached(priority: .background) {
                        VaultPaths.sweepStaleIndexDirectories()
                    }
                }
                .onOpenURL { url in
                    pairingHandler.handle(url)
                }
        }
        .modelContainer(for: RecentDocument.self)
    }
}
