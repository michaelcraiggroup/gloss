import Foundation
import Observation

/// Moves a local vault into the iCloud container ("Move Vault to iCloud…").
///
/// The migrator owns filesystem truth only: validation, the crash journal,
/// deleting in-vault derived index files, and the off-main `setUbiquitous`
/// move. The presenting UI owns app-state choreography around it — quiesce
/// (close index/tree/bookmarks) before `move`, reopen from the destination
/// after — because those touch main-actor services the migrator must not
/// depend on.
///
/// Crash safety: a journal in UserDefaults brackets the move. If the app
/// dies mid-move, `healPendingMigration` runs at next launch and repairs
/// `rootFolderPath` from what actually happened on disk. (Recents-bucket
/// migration is skipped on the heal path — old-bucket rows are orphaned, not
/// lost; favorites live in the vault file and travel with it.)
@Observable
@MainActor
final class VaultMigrator {
    enum Phase: Equatable {
        case idle
        case moving
        case failed(String)
        case done
    }

    enum MigrationError: LocalizedError, Equatable {
        case iCloudUnavailable
        case alreadyInICloud
        case nameCollision(String)

        var errorDescription: String? {
            switch self {
            case .iCloudUnavailable:
                "iCloud isn't available. Sign in to iCloud and make sure iCloud Drive is on."
            case .alreadyInICloud:
                "This vault already lives in iCloud."
            case .nameCollision(let name):
                "A vault named “\(name)” already exists in iCloud Drive → Gloss."
            }
        }
    }

    private(set) var phase: Phase = .idle

    // MARK: - Pure decisions (unit-tested)

    nonisolated static func destinationURL(for source: URL, containerDocuments: URL) -> URL {
        containerDocuments.appendingPathComponent(source.lastPathComponent, isDirectory: true)
    }

    /// nil when the move may proceed.
    nonisolated static func validationError(
        source: URL,
        containerDocuments: URL?
    ) -> MigrationError? {
        guard let containerDocuments else { return .iCloudUnavailable }
        if UbiquityVaultStore.isUbiquitousPath(source) { return .alreadyInICloud }
        let destination = destinationURL(for: source, containerDocuments: containerDocuments)
        if FileManager.default.fileExists(atPath: destination.path) {
            return .nameCollision(source.lastPathComponent)
        }
        return nil
    }

    // MARK: - Journal

    nonisolated static let journalKey = "vaultMigrationJournal_v1"

    struct Journal: Codable, Equatable {
        var sourcePath: String
        var destinationPath: String
    }

    nonisolated static func writeJournal(_ journal: Journal, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(journal) {
            defaults.set(data, forKey: journalKey)
        }
    }

    nonisolated static func readJournal(defaults: UserDefaults = .standard) -> Journal? {
        guard let data = defaults.data(forKey: journalKey) else { return nil }
        return try? JSONDecoder().decode(Journal.self, from: data)
    }

    nonisolated static func clearJournal(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: journalKey)
    }

    enum HealAction: Equatable {
        /// Move completed before the crash — point the app at the destination.
        case adoptDestination
        /// Move never happened — the source is intact; nothing to repair.
        case keepSource
        /// Ambiguous (both or neither exist) — prefer the untouched source,
        /// let the user retry; never delete anything.
        case abandon
    }

    nonisolated static func healAction(sourceExists: Bool, destinationExists: Bool) -> HealAction {
        switch (sourceExists, destinationExists) {
        case (false, true): .adoptDestination
        case (true, false): .keepSource
        default: .abandon
        }
    }

    /// Launch-time repair. Cheap (two existence checks) — call before the
    /// vault restore so a healed `rootFolderPath` restores correctly.
    @MainActor
    static func healPendingMigration(settings: AppSettings, defaults: UserDefaults = .standard) {
        guard let journal = readJournal(defaults: defaults) else { return }
        let fm = FileManager.default
        let action = healAction(
            sourceExists: fm.fileExists(atPath: journal.sourcePath),
            destinationExists: fm.fileExists(atPath: journal.destinationPath))
        if action == .adoptDestination, settings.rootFolderPath == journal.sourcePath {
            settings.rootFolderPath = journal.destinationPath
            settings.recordRecentVault(journal.destinationPath)
            settings.removeRecentVault(journal.sourcePath)
        }
        clearJournal(defaults: defaults)
    }

    // MARK: - The move

    /// Validate, journal, strip in-vault derived index files, and move the
    /// vault into the container. Runs `setUbiquitous` off-main (it blocks on
    /// I/O and ubiquity bootstrap). The caller quiesces app state BEFORE
    /// calling (LinkIndex.close, closeFolder, bookmarks) — nothing may hold
    /// the vault or its SQLite open mid-move — and reopens from the returned
    /// destination after.
    func move(vaultRoot source: URL, containerDocuments: URL) async throws -> URL {
        if let error = Self.validationError(source: source, containerDocuments: containerDocuments) {
            phase = .failed(error.localizedDescription)
            throw error
        }
        phase = .moving

        let destination = Self.destinationURL(for: source, containerDocuments: containerDocuments)
        Self.writeJournal(Journal(sourcePath: source.path, destinationPath: destination.path))

        do {
            try await Task.detached(priority: .userInitiated) {
                // The SQLite index (and its sidecars) must never enter the
                // container — sync corrupts databases. favorites.json and
                // config.json stay: they are the vault's syncable state.
                let glossDir = source.appendingPathComponent(".gloss")
                for sidecar in ["index.sqlite", "index.sqlite-wal", "index.sqlite-shm"] {
                    try? FileManager.default.removeItem(
                        at: glossDir.appendingPathComponent(sidecar))
                }
                try FileManager.default.setUbiquitous(
                    true, itemAt: source, destinationURL: destination)
            }.value
        } catch {
            phase = .failed(error.localizedDescription)
            Self.clearJournal()
            throw error
        }

        Self.clearJournal()
        phase = .done
        return destination
    }
}
