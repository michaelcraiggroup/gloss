import Foundation
import Observation

/// Resolves and publishes the app's iCloud container ("iCloud Drive → Gloss"),
/// where synced vaults live. Shared by both shells: macOS uses it for the
/// Move-Vault-to-iCloud flow and container-vault restore; iOS builds its vault
/// discovery on top of it (vault-sync arc).
///
/// `url(forUbiquityContainerIdentifier:)` must be called off the main thread
/// at least once per launch — the first call performs ubiquity bootstrap and
/// extends the sandbox to the container — so `start()` resolves on a detached
/// task and publishes back on the main actor. SPM dev builds are unsigned
/// (no entitlements): resolution returns nil there and every iCloud feature
/// degrades to `.unavailable` — container behavior is only testable in
/// signed Xcode builds.
@Observable
@MainActor
final class UbiquityVaultStore {
    enum UbiquityState: Equatable {
        case unknown
        case unavailable
        case available(containerURL: URL)
    }

    /// One container, both platforms. Registered in the developer portal
    /// 2026-08-08 (docs/ICLOUD_SETUP.md). nonisolated: read from the detached
    /// resolver task and from nonisolated helpers.
    nonisolated static let containerIdentifier = "iCloud.group.michaelcraig.gloss"

    private(set) var state: UbiquityState = .unknown
    private var started = false
    private var identityObserver: (any NSObjectProtocol)?

    /// Cheap synchronous "signed into iCloud?" check (no container needed).
    var isSignedIntoICloud: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// The container's Documents folder — the user-visible "Gloss" folder in
    /// iCloud Drive, and the parent of every synced vault.
    var documentsURL: URL? {
        guard case .available(let container) = state else { return nil }
        return container.appendingPathComponent("Documents", isDirectory: true)
    }

    /// Idempotent kickoff. Also re-resolves when the signed-in iCloud account
    /// changes (sign-out flips vaults to unavailable; sign-in brings them back).
    func start() {
        guard !started else { return }
        started = true
        resolve()
        identityObserver = NotificationCenter.default.addObserver(
            forName: .NSUbiquityIdentityDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.resolve() }
        }
    }

    private func resolve() {
        Task.detached(priority: .utility) {
            let container = FileManager.default.url(
                forUbiquityContainerIdentifier: Self.containerIdentifier)
            if let container {
                // The "Gloss" folder appears in iCloud Drive only once
                // Documents/ exists and has synced once — create it eagerly.
                try? FileManager.default.createDirectory(
                    at: container.appendingPathComponent("Documents", isDirectory: true),
                    withIntermediateDirectories: true)
            }
            await MainActor.run { [weak self] in
                self?.state = container.map { .available(containerURL: $0) } ?? .unavailable
            }
        }
    }

    /// Stateless container-path test usable from anywhere (bookmark no-ops,
    /// restore deferral) without touching main-actor state: the local replica
    /// path contains the tilde-escaped container id segment on both platforms
    /// (macOS `~/Library/Mobile Documents/iCloud~group~michaelcraig~gloss/…`,
    /// iOS `…/Library/Mobile Documents/iCloud~group~michaelcraig~gloss/…`).
    nonisolated static func isUbiquitousPath(_ url: URL) -> Bool {
        url.standardizedFileURL.path
            .contains("Mobile Documents/iCloud~group~michaelcraig~gloss")
    }
}
