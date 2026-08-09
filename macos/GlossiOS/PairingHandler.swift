import Foundation
import Observation

/// The stateful half of QR pairing — both doorways (Camera-app deep link via
/// onOpenURL, and the in-app scanner) converge here. Sequencing decisions
/// come from PairingEngine; this class owns UI state, the locate-watch
/// metadata query, retries on iCloud/unlock changes, and the actual vault
/// open.
///
/// The wrong-Apple-ID failure mode deliberately has no terminal state: it
/// manifests as a vault that never appears, so `.locating` keeps listening
/// forever — the UI softens its copy after a timeout, and the screen
/// self-heals the moment the vault lands.
@Observable
@MainActor
final class PairingHandler: PairingURLHandling {
    enum State: Equatable {
        case idle
        case invalidCode
        case needsICloud
        case needsPro
        case locating(vaultName: String)
        case done(vaultName: String)
    }

    private(set) var state: State = .idle
    /// Kept across needsICloud/needsPro/locating so state changes can retry.
    private(set) var pendingPayload: PairingPayload?
    /// True from handle() until the attempt concludes (open or reset) — a
    /// nil pendingPayload alone can't distinguish "invalid code" from "no
    /// attempt", and advance() must run for both.
    private var hasAttempt = false

    private let settings: AppSettings
    private let fileTree: FileTreeModel
    private let linkIndex: LinkIndex
    private let store: StoreManager
    private let ubiquityStore: UbiquityVaultStore

    private var locateQuery: NSMetadataQuery?
    private var locateObservers: [any NSObjectProtocol] = []

    init(
        settings: AppSettings,
        fileTree: FileTreeModel,
        linkIndex: LinkIndex,
        store: StoreManager,
        ubiquityStore: UbiquityVaultStore
    ) {
        self.settings = settings
        self.fileTree = fileTree
        self.linkIndex = linkIndex
        self.store = store
        self.ubiquityStore = ubiquityStore
    }

    /// Entry point for both doorways.
    func handle(_ url: URL) {
        stopLocating()
        pendingPayload = PairingPayloadCodec.decode(from: url)
        hasAttempt = true
        advance()
    }

    /// Re-runs the decision — called when iCloud resolves, when Pro unlocks,
    /// and by the UI's Try Again. No-ops when nothing was ever scanned.
    func advance() {
        guard hasAttempt else { return }

        let container: URL? = {
            if case .available(let url) = ubiquityStore.state { return url }
            return nil
        }()

        let decision = PairingEngine.decide(
            payload: pendingPayload,
            containerURL: container,
            unlocked: store.isUnlocked,
            vaultExists: { FileManager.default.fileExists(atPath: $0.path) })

        switch decision {
        case .invalidCode:
            state = .invalidCode
        case .needsICloud:
            state = .needsICloud
        case .needsPro:
            state = .needsPro
            // Fires the shared paywall; retry happens on isUnlocked flip.
            _ = store.gate(.folderSidebar)
        case .locate(let vaultURL):
            state = .locating(vaultName: pendingPayload?.name ?? vaultURL.lastPathComponent)
            watchForVault(at: vaultURL)
        case .open(let vaultURL):
            open(vaultURL)
        }
    }

    /// Dismissal/reset from the UI.
    func reset() {
        stopLocating()
        pendingPayload = nil
        hasAttempt = false
        state = .idle
    }

    // MARK: - Open

    private func open(_ vaultURL: URL) {
        stopLocating()
        fileTree.openFolder(vaultURL)
        settings.rootFolderPath = vaultURL.path
        linkIndex.buildIndex(rootURL: vaultURL)
        PairingEngine.apply(pendingPayload?.settings, to: settings)
        state = .done(vaultName: pendingPayload?.name ?? vaultURL.lastPathComponent)
        pendingPayload = nil
        hasAttempt = false
    }

    // MARK: - Locate watch

    /// A scoped metadata query for the expected vault path — fires the moment
    /// sync materializes it. Never times out by itself (see class note).
    private func watchForVault(at vaultURL: URL) {
        stopLocating()
        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        // Path-key predicates match nothing on device (see
        // UbiquityVaultObserver.start) — watch by folder NAME and let
        // advance()'s FileManager check confirm the actual path.
        query.predicate = NSPredicate(
            format: "%K == %@", NSMetadataItemFSNameKey, vaultURL.lastPathComponent)
        for name in [Notification.Name.NSMetadataQueryDidFinishGathering, .NSMetadataQueryDidUpdate] {
            locateObservers.append(NotificationCenter.default.addObserver(
                forName: name, object: query, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, case .locating = self.state else { return }
                    if FileManager.default.fileExists(atPath: vaultURL.path) {
                        self.advance()
                    }
                }
            })
        }
        locateQuery = query
        query.start()
    }

    private func stopLocating() {
        locateQuery?.stop()
        locateQuery = nil
        for observer in locateObservers { NotificationCenter.default.removeObserver(observer) }
        locateObservers = []
    }
}
