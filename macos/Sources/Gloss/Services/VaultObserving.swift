import Foundation

/// Platform-neutral vault change observation.
///
/// macOS conformer: `FolderWatcher` (FSEvents; the conformance is declared in
/// FolderWatcher.swift so this file stays free of platform branches). iOS
/// conformer: the NSMetadataQuery-based ubiquity observer from the vault-sync
/// arc. Contract — mirrors `FolderWatcher` exactly:
/// - `onChange` receives absolute changed paths, delivered on the MAIN queue,
///   symlink-resolved where the platform reports them so
///   `FileTreeModel.reconcile`'s root-prefix matching works.
/// - `start` replaces any existing observation and returns `false` when
///   observation could not begin — `FileTreeModel` then leaves `isWatching`
///   false so DocumentView keeps the per-file watcher fallback for the open
///   document instead of silently relying on a dead watch.
protocol VaultObserving: AnyObject, Sendable {
    @discardableResult
    func start(
        root: URL,
        rules: ExclusionRules,
        onChange: @escaping @Sendable ([String]) -> Void
    ) -> Bool

    func stop()
}

/// Observer that never observes: `start` returns `false`, so callers keep
/// their fallbacks engaged. The iOS default until the ubiquity observer is
/// injected, and a test convenience.
final class NullVaultObserver: VaultObserving {
    @discardableResult
    func start(
        root: URL,
        rules: ExclusionRules,
        onChange: @escaping @Sendable ([String]) -> Void
    ) -> Bool {
        false
    }

    func stop() {}
}
